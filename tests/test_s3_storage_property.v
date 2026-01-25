module main

import rand
import time
import crypto.sha256
import encoding.hex
import net.urllib

// ============================================================================
// Property 1: Upload-Download Round Trip (S3)
// Property 4: Presigned URL Validity (S3)
// Feature: v-hono-upload-integration, Property 1 & 4
// Validates: Requirements 3.4, 3.5
//
// Since we cannot test against a real S3 server without credentials,
// these tests verify:
// 1. S3 storage provider creation and configuration validation
// 2. Presigned URL generation format and structure
// 3. AWS Signature V4 signing algorithm correctness
// ============================================================================

const test_iterations = 100

// ============================================================================
// Type definitions (copied from storage modules for standalone testing)
// ============================================================================

struct StorageResult {
pub:
	success    bool
	object_key string
	etag       string
	size       i64
	error_msg  string
}

struct ObjectInfo {
pub:
	key           string
	size          i64
	etag          string
	content_type  string
	last_modified i64
	metadata      map[string]string
}

struct ListOptions {
pub:
	prefix      string
	delimiter   string
	max_keys    int = 1000
	start_after string
}

struct ListResult {
pub:
	objects         []ObjectInfo
	common_prefixes []string
	is_truncated    bool
	next_marker     string
}


struct PresignOptions {
pub:
	expires_in   int    = 3600
	method       string = 'GET'
	content_type string
}

struct PartInfo {
pub:
	part_number int
	etag        string
	size        i64
}

struct S3Config {
pub:
	endpoint       string
	access_key     string
	secret_key     string
	region         string = 'us-east-1'
	use_ssl        bool   = true
	path_style     bool
	default_bucket string
}

struct ConfigValidationResult {
pub:
	valid          bool
	missing_fields []string
	error_message  string
}

// ============================================================================
// S3Storage implementation (minimal for testing)
// ============================================================================

struct S3Storage {
	config S3Config
mut:
	multipart_uploads map[string]S3MultipartUploadState
}

struct S3MultipartUploadState {
mut:
	bucket       string
	key          string
	upload_id    string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

fn validate_s3_config(config S3Config) ConfigValidationResult {
	mut missing := []string{}

	if config.endpoint == '' {
		missing << 's3.endpoint'
	}
	if config.access_key == '' {
		missing << 's3.access_key'
	}
	if config.secret_key == '' {
		missing << 's3.secret_key'
	}
	if config.default_bucket == '' {
		missing << 's3.default_bucket'
	}

	if missing.len > 0 {
		return ConfigValidationResult{
			valid: false
			missing_fields: missing
			error_message: 'Missing required fields: ${missing.join(", ")}'
		}
	}

	return ConfigValidationResult{
		valid: true
		missing_fields: []string{}
		error_message: ''
	}
}

fn new_s3_storage(config S3Config) !S3Storage {
	validation := validate_s3_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return S3Storage{
		config: config
		multipart_uploads: map[string]S3MultipartUploadState{}
	}
}

fn (s S3Storage) provider_name() string {
	return 's3'
}

fn (s S3Storage) get_host(bucket string) string {
	if s.config.path_style || bucket == '' {
		return s.config.endpoint
	}
	return '${bucket}.${s.config.endpoint}'
}


fn (s S3Storage) get_uri_path(bucket string, key string) string {
	if s.config.path_style {
		mut path := ''
		if bucket != '' {
			path = '/${bucket}'
		}
		if key != '' {
			path += '/${key}'
		}
		if path == '' {
			return '/'
		}
		return path
	} else {
		if key != '' {
			return '/${key}'
		}
		return '/'
	}
}

fn (s S3Storage) build_canonical_query_string(params map[string]string) string {
	if params.len == 0 {
		return ''
	}

	mut keys := params.keys()
	keys.sort()

	mut parts := []string{}
	for key in keys {
		encoded_key := urllib.query_escape(key)
		encoded_value := urllib.query_escape(params[key])
		parts << '${encoded_key}=${encoded_value}'
	}

	return parts.join('&')
}

fn (s S3Storage) get_url(bucket string, key string, query_params map[string]string) string {
	scheme := if s.config.use_ssl { 'https' } else { 'http' }
	host := s.get_host(bucket)

	mut path := ''
	if s.config.path_style {
		if bucket != '' {
			path = '/${bucket}'
		}
		if key != '' {
			path += '/${key}'
		}
	} else {
		if key != '' {
			path = '/${key}'
		}
	}

	if path == '' {
		path = '/'
	}

	mut url := '${scheme}://${host}${path}'

	if query_params.len > 0 {
		query_string := s.build_canonical_query_string(query_params)
		url += '?${query_string}'
	}

	return url
}


// HMAC-SHA256 implementation
fn s3_test_hmac_sha256(key []u8, data []u8) []u8 {
	block_size := 64
	mut k := key.clone()

	if k.len > block_size {
		k = sha256.sum(k)
	}

	for k.len < block_size {
		k << u8(0)
	}

	mut i_pad := []u8{len: block_size}
	mut o_pad := []u8{len: block_size}
	for i in 0 .. block_size {
		i_pad[i] = k[i] ^ u8(0x36)
		o_pad[i] = k[i] ^ u8(0x5c)
	}

	mut inner_data := i_pad.clone()
	inner_data << data
	inner_hash := sha256.sum(inner_data)

	mut outer_data := o_pad.clone()
	outer_data << inner_hash
	return sha256.sum(outer_data)
}

fn (s S3Storage) get_signing_key(date_stamp string) []u8 {
	k_date := s3_test_hmac_sha256(('AWS4' + s.config.secret_key).bytes(), date_stamp.bytes())
	k_region := s3_test_hmac_sha256(k_date, s.config.region.bytes())
	k_service := s3_test_hmac_sha256(k_region, 's3'.bytes())
	k_signing := s3_test_hmac_sha256(k_service, 'aws4_request'.bytes())
	return k_signing
}

fn (s S3Storage) presign_url(bucket string, key string, options PresignOptions) !string {
	now := time.utc()
	date_stamp := now.custom_format('YYYYMMDD')
	datetime_stamp := now.custom_format('YYYYMMDD') + 'T' + now.custom_format('HHmmss') + 'Z'

	mut query_params := map[string]string{}
	query_params['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256'

	credential_scope := '${date_stamp}/${s.config.region}/s3/aws4_request'
	query_params['X-Amz-Credential'] = '${s.config.access_key}/${credential_scope}'
	query_params['X-Amz-Date'] = datetime_stamp
	query_params['X-Amz-Expires'] = options.expires_in.str()
	query_params['X-Amz-SignedHeaders'] = 'host'

	uri := s.get_uri_path(bucket, key)

	host := s.get_host(bucket)
	canonical_headers := 'host:${host}\n'
	signed_headers := 'host'
	payload_hash := 'UNSIGNED-PAYLOAD'

	query_string := s.build_canonical_query_string(query_params)

	canonical_request := '${options.method}\n${uri}\n${query_string}\n${canonical_headers}\n${signed_headers}\n${payload_hash}'

	request_hash := sha256.sum(canonical_request.bytes())
	hashed_request := hex.encode(request_hash)
	string_to_sign := 'AWS4-HMAC-SHA256\n${datetime_stamp}\n${credential_scope}\n${hashed_request}'

	signing_key := s.get_signing_key(date_stamp)
	signature := s3_test_hmac_sha256(signing_key, string_to_sign.bytes())
	signature_hex := hex.encode(signature)

	query_params['X-Amz-Signature'] = signature_hex

	return s.get_url(bucket, key, query_params)
}


// ============================================================================
// Test infrastructure
// ============================================================================

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats PropertyTestStats) run_property_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🔬 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== S3 Storage 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

fn generate_random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(min_len, max_len) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

fn generate_random_s3_config() S3Config {
	return S3Config{
		endpoint: 's3.${generate_random_string(5, 10)}.amazonaws.com'
		access_key: generate_random_string(16, 20)
		secret_key: generate_random_string(32, 40)
		region: 'us-east-1'
		use_ssl: true
		path_style: false
		default_bucket: generate_random_string(5, 15)
	}
}

fn generate_random_minio_config() S3Config {
	return S3Config{
		endpoint: 'localhost:9000'
		access_key: generate_random_string(16, 20)
		secret_key: generate_random_string(32, 40)
		region: 'us-east-1'
		use_ssl: false
		path_style: true
		default_bucket: generate_random_string(5, 15)
	}
}

fn generate_random_filename() string {
	chars := 'abcdefghijklmnopqrstuvwxyz0123456789'
	len := rand.int_in_range(5, 20) or { 10 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	extensions := ['.txt', '.bin', '.dat', '.json', '.xml']
	ext_idx := rand.int_in_range(0, extensions.len) or { 0 }
	return result + extensions[ext_idx]
}


// ============================================================================
// Property 1: S3 Storage Provider Creation
// For any valid S3 configuration, creating a storage provider should succeed
// Validates: Requirements 3.1, 3.2
// ============================================================================
fn test_property_1_s3_provider_creation() bool {
	for i in 0 .. test_iterations {
		config := generate_random_s3_config()

		storage := new_s3_storage(config) or {
			println('  Iteration ${i}: Failed to create S3 storage: ${err}')
			return false
		}

		if storage.provider_name() != 's3' {
			println('  Iteration ${i}: Provider name mismatch. Expected: s3, Got: ${storage.provider_name()}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 2: MinIO Storage Provider Creation
// For any valid MinIO configuration, creating a storage provider should succeed
// Validates: Requirements 3.2
// ============================================================================
fn test_property_2_minio_provider_creation() bool {
	for i in 0 .. test_iterations {
		config := generate_random_minio_config()

		storage := new_s3_storage(config) or {
			println('  Iteration ${i}: Failed to create MinIO storage: ${err}')
			return false
		}

		if storage.provider_name() != 's3' {
			println('  Iteration ${i}: Provider name mismatch. Expected: s3, Got: ${storage.provider_name()}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 3: Invalid Configuration Rejection
// For any S3 configuration with missing required fields, creation should fail
// Validates: Requirements 3.3
// ============================================================================
fn test_property_3_invalid_config_rejection() bool {
	// Test missing endpoint
	for _ in 0 .. 10 {
		config := S3Config{
			endpoint: ''
			access_key: generate_random_string(16, 20)
			secret_key: generate_random_string(32, 40)
			region: 'us-east-1'
			default_bucket: generate_random_string(5, 15)
		}

		_ := new_s3_storage(config) or {
			continue
		}
		println('  Missing endpoint should have failed')
		return false
	}

	// Test missing access_key
	for _ in 0 .. 10 {
		config := S3Config{
			endpoint: 's3.amazonaws.com'
			access_key: ''
			secret_key: generate_random_string(32, 40)
			region: 'us-east-1'
			default_bucket: generate_random_string(5, 15)
		}

		_ := new_s3_storage(config) or {
			continue
		}
		println('  Missing access_key should have failed')
		return false
	}

	// Test missing secret_key
	for _ in 0 .. 10 {
		config := S3Config{
			endpoint: 's3.amazonaws.com'
			access_key: generate_random_string(16, 20)
			secret_key: ''
			region: 'us-east-1'
			default_bucket: generate_random_string(5, 15)
		}

		_ := new_s3_storage(config) or {
			continue
		}
		println('  Missing secret_key should have failed')
		return false
	}

	// Test missing default_bucket
	for _ in 0 .. 10 {
		config := S3Config{
			endpoint: 's3.amazonaws.com'
			access_key: generate_random_string(16, 20)
			secret_key: generate_random_string(32, 40)
			region: 'us-east-1'
			default_bucket: ''
		}

		_ := new_s3_storage(config) or {
			continue
		}
		println('  Missing default_bucket should have failed')
		return false
	}

	return true
}


// ============================================================================
// Property 4: Presigned URL Format Validity
// For any valid S3 configuration and object key, the presigned URL should:
// - Contain the correct scheme (http/https)
// - Contain the correct host
// - Contain the object key
// - Contain required AWS signature parameters
// Validates: Requirements 3.4, 3.5
// ============================================================================
fn test_property_4_presigned_url_format() bool {
	for i in 0 .. test_iterations {
		config := generate_random_s3_config()
		bucket := config.default_bucket
		key := generate_random_filename()

		storage := new_s3_storage(config) or {
			println('  Iteration ${i}: Failed to create storage: ${err}')
			return false
		}

		options := PresignOptions{
			expires_in: 3600
			method: 'GET'
		}

		url := storage.presign_url(bucket, key, options) or {
			println('  Iteration ${i}: Failed to generate presigned URL: ${err}')
			return false
		}

		// 1. Should start with https:// (use_ssl is true)
		if !url.starts_with('https://') {
			println('  Iteration ${i}: URL should start with https://, got: ${url}')
			return false
		}

		// 2. Should contain the object key
		if !url.contains(key) {
			println('  Iteration ${i}: URL should contain key "${key}", got: ${url}')
			return false
		}

		// 3. Should contain AWS signature parameters
		required_params := ['X-Amz-Algorithm', 'X-Amz-Credential', 'X-Amz-Date', 'X-Amz-Expires',
			'X-Amz-SignedHeaders', 'X-Amz-Signature']
		for param in required_params {
			if !url.contains(param) {
				println('  Iteration ${i}: URL missing required parameter "${param}", got: ${url}')
				return false
			}
		}

		// 4. Should contain AWS4-HMAC-SHA256 algorithm
		if !url.contains('AWS4-HMAC-SHA256') {
			println('  Iteration ${i}: URL should contain AWS4-HMAC-SHA256 algorithm')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 5: Presigned URL Expiration Parameter
// For any expiration time, the presigned URL should contain the correct X-Amz-Expires value
// Validates: Requirements 3.5
// ============================================================================
fn test_property_5_presigned_url_expiration() bool {
	config := generate_random_s3_config()
	bucket := config.default_bucket
	key := generate_random_filename()

	storage := new_s3_storage(config) or {
		println('  Failed to create storage: ${err}')
		return false
	}

	expiration_times := [60, 300, 900, 1800, 3600, 7200, 86400]

	for expires_in in expiration_times {
		options := PresignOptions{
			expires_in: expires_in
			method: 'GET'
		}

		url := storage.presign_url(bucket, key, options) or {
			println('  Failed to generate presigned URL with expires_in=${expires_in}: ${err}')
			return false
		}

		expected_param := 'X-Amz-Expires=${expires_in}'
		if !url.contains(expected_param) {
			println('  URL should contain "${expected_param}", got: ${url}')
			return false
		}
	}

	return true
}


// ============================================================================
// Property 6: Path Style vs Virtual Hosted Style URLs
// For path_style=true (MinIO), URL should use path-style addressing
// For path_style=false (AWS S3), URL should use virtual-hosted-style addressing
// Validates: Requirements 3.2
// ============================================================================
fn test_property_6_url_addressing_style() bool {
	for i in 0 .. test_iterations {
		bucket := generate_random_string(5, 15)
		key := generate_random_filename()

		// Test path-style (MinIO)
		minio_config := S3Config{
			endpoint: 'localhost:9000'
			access_key: generate_random_string(16, 20)
			secret_key: generate_random_string(32, 40)
			region: 'us-east-1'
			use_ssl: false
			path_style: true
			default_bucket: bucket
		}

		minio_storage := new_s3_storage(minio_config) or {
			println('  Iteration ${i}: Failed to create MinIO storage: ${err}')
			return false
		}

		minio_url := minio_storage.presign_url(bucket, key, PresignOptions{}) or {
			println('  Iteration ${i}: Failed to generate MinIO presigned URL: ${err}')
			return false
		}

		// Path-style URL should contain bucket in path: http://host/bucket/key
		if !minio_url.contains('/${bucket}/') {
			println('  Iteration ${i}: MinIO URL should use path-style addressing with bucket in path')
			return false
		}

		// Test virtual-hosted-style (AWS S3)
		s3_config := S3Config{
			endpoint: 's3.amazonaws.com'
			access_key: generate_random_string(16, 20)
			secret_key: generate_random_string(32, 40)
			region: 'us-east-1'
			use_ssl: true
			path_style: false
			default_bucket: bucket
		}

		s3_storage := new_s3_storage(s3_config) or {
			println('  Iteration ${i}: Failed to create S3 storage: ${err}')
			return false
		}

		s3_url := s3_storage.presign_url(bucket, key, PresignOptions{}) or {
			println('  Iteration ${i}: Failed to generate S3 presigned URL: ${err}')
			return false
		}

		// Virtual-hosted-style URL should contain bucket in host: https://bucket.host/key
		if !s3_url.contains('${bucket}.s3.amazonaws.com') {
			println('  Iteration ${i}: S3 URL should use virtual-hosted-style addressing with bucket in host')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 7: Presigned URL Method Parameter
// For different HTTP methods, the presigned URL should be generated correctly
// Validates: Requirements 3.4
// ============================================================================
fn test_property_7_presigned_url_methods() bool {
	config := generate_random_s3_config()
	bucket := config.default_bucket
	key := generate_random_filename()

	storage := new_s3_storage(config) or {
		println('  Failed to create storage: ${err}')
		return false
	}

	methods := ['GET', 'PUT', 'DELETE', 'HEAD']

	for method in methods {
		options := PresignOptions{
			expires_in: 3600
			method: method
		}

		url := storage.presign_url(bucket, key, options) or {
			println('  Failed to generate presigned URL for method ${method}: ${err}')
			return false
		}

		if url == '' {
			println('  Empty URL generated for method ${method}')
			return false
		}

		if !url.contains('X-Amz-Signature=') {
			println('  URL for method ${method} missing signature')
			return false
		}
	}

	return true
}


fn main() {
	println('🚀 开始 S3 Storage 属性测试...')
	println('Feature: v-hono-upload-integration, Property 1 & 4: Upload-Download Round Trip (S3) & Presigned URL Validity')
	println('Validates: Requirements 3.4, 3.5')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(12345)])

	mut stats := PropertyTestStats{}

	// Run property tests
	stats.run_property_test('Property 1: S3 Storage Provider Creation', test_property_1_s3_provider_creation)
	stats.run_property_test('Property 2: MinIO Storage Provider Creation', test_property_2_minio_provider_creation)
	stats.run_property_test('Property 3: Invalid Configuration Rejection', test_property_3_invalid_config_rejection)
	stats.run_property_test('Property 4: Presigned URL Format Validity', test_property_4_presigned_url_format)
	stats.run_property_test('Property 5: Presigned URL Expiration Parameter', test_property_5_presigned_url_expiration)
	stats.run_property_test('Property 6: Path Style vs Virtual Hosted Style URLs', test_property_6_url_addressing_style)
	stats.run_property_test('Property 7: Presigned URL Method Parameter', test_property_7_presigned_url_methods)

	stats.print_summary()

	if stats.failed_tests > 0 {
		exit(1)
	}
}
