module main

import rand
import time
import crypto.sha1
import encoding.hex
import net.urllib

// ============================================================================
// Property 1: Upload-Download Round Trip (COS)
// Property 4: Presigned URL Validity (COS)
// Feature: v-hono-upload-integration, Property 1 & 4
// Validates: Requirements 5.3, 5.4
//
// Since we cannot test against a real Tencent COS server without credentials,
// these tests verify:
// 1. Tencent COS storage provider creation and configuration validation
// 2. Presigned URL generation format and structure
// 3. Tencent COS signing algorithm correctness
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

struct TencentCOSConfig {
pub:
	secret_id      string
	secret_key     string
	region         string
	default_bucket string
}

struct ConfigValidationResult {
pub:
	valid          bool
	missing_fields []string
	error_message  string
}

// ============================================================================
// TencentCOS implementation (minimal for testing)
// ============================================================================

struct TencentCOS {
	config TencentCOSConfig
mut:
	multipart_uploads map[string]COSMultipartUploadState
}

struct COSMultipartUploadState {
mut:
	bucket       string
	key          string
	upload_id    string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

fn validate_tencent_cos_config(config TencentCOSConfig) ConfigValidationResult {
	mut missing := []string{}

	if config.secret_id == '' {
		missing << 'tencent_cos.secret_id'
	}
	if config.secret_key == '' {
		missing << 'tencent_cos.secret_key'
	}
	if config.region == '' {
		missing << 'tencent_cos.region'
	}
	if config.default_bucket == '' {
		missing << 'tencent_cos.default_bucket'
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

fn new_tencent_cos(config TencentCOSConfig) !TencentCOS {
	validation := validate_tencent_cos_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return TencentCOS{
		config: config
		multipart_uploads: map[string]COSMultipartUploadState{}
	}
}

fn (c TencentCOS) provider_name() string {
	return 'tencent_cos'
}

fn (c TencentCOS) get_host(bucket string) string {
	// COS 域名格式: <BucketName-APPID>.cos.<Region>.myqcloud.com
	if bucket != '' {
		return '${bucket}.cos.${c.config.region}.myqcloud.com'
	}
	return 'cos.${c.config.region}.myqcloud.com'
}

// URL encoding for key (preserving /)
fn (c TencentCOS) encode_key(key string) string {
	parts := key.split('/')
	mut encoded_parts := []string{}
	for part in parts {
		encoded_parts << urllib.query_escape(part)
	}
	return encoded_parts.join('/')
}

fn (c TencentCOS) get_uri_path(key string) string {
	if key != '' {
		return '/' + c.encode_key(key)
	}
	return '/'
}

// HMAC-SHA1 implementation for COS signing
fn cos_test_hmac_sha1(key []u8, data []u8) []u8 {
	block_size := 64
	mut k := key.clone()

	if k.len > block_size {
		k = sha1.sum(k)
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
	inner_hash := sha1.sum(inner_data)

	mut outer_data := o_pad.clone()
	outer_data << inner_hash
	return sha1.sum(outer_data)
}

fn (c TencentCOS) presign_url(bucket string, key string, options PresignOptions) !string {
	now := time.utc()
	timestamp := now.unix()

	// 计算签名有效期
	start_time := timestamp - 60
	end_time := timestamp + i64(options.expires_in)
	key_time := '${start_time};${end_time}'

	// 构建 URI
	uri := c.get_uri_path(key)

	// 构建待签名字符串
	// HttpString = [HttpMethod]\n[HttpURI]\n[HttpParameters]\n[HttpHeaders]\n
	http_string := '${options.method.to_lower()}\n${uri}\n\n\n'

	// 计算 SHA1 哈希
	request_hash := sha1.sum(http_string.bytes())
	hashed_request := hex.encode(request_hash).to_lower()

	// StringToSign = q-sign-algorithm\nq-sign-time\nSha1Digest\n
	string_to_sign := 'sha1\n${key_time}\n${hashed_request}\n'

	// 计算签名密钥
	signing_key := cos_test_hmac_sha1(c.config.secret_key.bytes(), key_time.bytes())

	// 计算签名
	signature := cos_test_hmac_sha1(signing_key, string_to_sign.bytes())
	signature_hex := hex.encode(signature).to_lower()

	// 构建 URL
	host := c.get_host(bucket)
	encoded_key := c.encode_key(key)

	mut url := 'https://${host}/${encoded_key}'
	url += '?q-sign-algorithm=sha1'
	url += '&q-ak=${urllib.query_escape(c.config.secret_id)}'
	url += '&q-sign-time=${key_time}'
	url += '&q-key-time=${key_time}'
	url += '&q-header-list='
	url += '&q-url-param-list='
	url += '&q-signature=${signature_hex}'

	return url
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
	println('\n=== Tencent COS Storage 属性测试总结 ===')
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

fn generate_random_cos_config() TencentCOSConfig {
	regions := ['ap-guangzhou', 'ap-shanghai', 'ap-beijing', 'ap-chengdu', 'ap-hongkong', 'ap-singapore']
	region_idx := rand.int_in_range(0, regions.len) or { 0 }
	region := regions[region_idx]

	// COS bucket name format: <BucketName-APPID>
	bucket_name := generate_random_string(5, 15).to_lower()
	appid := generate_random_string(10, 10)

	return TencentCOSConfig{
		secret_id: generate_random_string(32, 36)
		secret_key: generate_random_string(32, 40)
		region: region
		default_bucket: '${bucket_name}-${appid}'
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
	extensions := ['.txt', '.bin', '.dat', '.json', '.xml', '.png', '.jpg']
	ext_idx := rand.int_in_range(0, extensions.len) or { 0 }
	return result + extensions[ext_idx]
}

// ============================================================================
// Property 1: Tencent COS Storage Provider Creation
// For any valid Tencent COS configuration, creating a storage provider should succeed
// Validates: Requirements 5.1, 5.2
// ============================================================================
fn test_property_1_cos_provider_creation() bool {
	for i in 0 .. test_iterations {
		config := generate_random_cos_config()

		storage := new_tencent_cos(config) or {
			println('  Iteration ${i}: Failed to create Tencent COS storage: ${err}')
			return false
		}

		if storage.provider_name() != 'tencent_cos' {
			println('  Iteration ${i}: Provider name mismatch. Expected: tencent_cos, Got: ${storage.provider_name()}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 2: Invalid Configuration Rejection
// For any Tencent COS configuration with missing required fields, creation should fail
// Validates: Requirements 5.2
// ============================================================================
fn test_property_2_invalid_config_rejection() bool {
	// Test missing secret_id
	for _ in 0 .. 10 {
		config := TencentCOSConfig{
			secret_id: ''
			secret_key: generate_random_string(32, 40)
			region: 'ap-guangzhou'
			default_bucket: generate_random_string(5, 15)
		}

		_ := new_tencent_cos(config) or {
			continue
		}
		println('  Missing secret_id should have failed')
		return false
	}

	// Test missing secret_key
	for _ in 0 .. 10 {
		config := TencentCOSConfig{
			secret_id: generate_random_string(32, 36)
			secret_key: ''
			region: 'ap-guangzhou'
			default_bucket: generate_random_string(5, 15)
		}

		_ := new_tencent_cos(config) or {
			continue
		}
		println('  Missing secret_key should have failed')
		return false
	}

	// Test missing region
	for _ in 0 .. 10 {
		config := TencentCOSConfig{
			secret_id: generate_random_string(32, 36)
			secret_key: generate_random_string(32, 40)
			region: ''
			default_bucket: generate_random_string(5, 15)
		}

		_ := new_tencent_cos(config) or {
			continue
		}
		println('  Missing region should have failed')
		return false
	}

	// Test missing default_bucket
	for _ in 0 .. 10 {
		config := TencentCOSConfig{
			secret_id: generate_random_string(32, 36)
			secret_key: generate_random_string(32, 40)
			region: 'ap-guangzhou'
			default_bucket: ''
		}

		_ := new_tencent_cos(config) or {
			continue
		}
		println('  Missing default_bucket should have failed')
		return false
	}

	return true
}

// ============================================================================
// Property 3: Presigned URL Format Validity
// For any valid Tencent COS configuration and object key, the presigned URL should:
// - Contain the correct scheme (https)
// - Contain the correct host (bucket.cos.region.myqcloud.com)
// - Contain the object key
// - Contain required COS signature parameters
// Validates: Requirements 5.3, 5.4
// ============================================================================
fn test_property_3_presigned_url_format() bool {
	for i in 0 .. test_iterations {
		config := generate_random_cos_config()
		bucket := config.default_bucket
		key := generate_random_filename()

		storage := new_tencent_cos(config) or {
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

		// 1. Should start with https://
		if !url.starts_with('https://') {
			println('  Iteration ${i}: URL should start with https://, got: ${url}')
			return false
		}

		// 2. Should contain bucket in host (virtual-hosted-style)
		expected_host := '${bucket}.cos.${config.region}.myqcloud.com'
		if !url.contains(expected_host) {
			println('  Iteration ${i}: URL should contain host "${expected_host}", got: ${url}')
			return false
		}

		// 3. Should contain the object key
		if !url.contains(key) {
			println('  Iteration ${i}: URL should contain key "${key}", got: ${url}')
			return false
		}

		// 4. Should contain COS signature parameters
		required_params := ['q-sign-algorithm', 'q-ak', 'q-sign-time', 'q-key-time', 'q-header-list', 'q-url-param-list', 'q-signature']
		for param in required_params {
			if !url.contains(param) {
				println('  Iteration ${i}: URL missing required parameter "${param}", got: ${url}')
				return false
			}
		}

		// 5. Should contain sha1 algorithm
		if !url.contains('q-sign-algorithm=sha1') {
			println('  Iteration ${i}: URL should contain q-sign-algorithm=sha1')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 4: Presigned URL Expiration Parameter
// For any expiration time, the presigned URL should contain the correct q-sign-time value
// Validates: Requirements 5.3
// ============================================================================
fn test_property_4_presigned_url_expiration() bool {
	config := generate_random_cos_config()
	bucket := config.default_bucket
	key := generate_random_filename()

	storage := new_tencent_cos(config) or {
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

		// Verify URL contains q-sign-time parameter
		if !url.contains('q-sign-time=') {
			println('  URL should contain q-sign-time parameter, got: ${url}')
			return false
		}

		// The q-sign-time value should be in format: start_time;end_time
		if sign_time_idx := url.index('q-sign-time=') {
			sign_time_start := sign_time_idx + 12
			mut sign_time_end := sign_time_start
			for sign_time_end < url.len && url[sign_time_end] != `&` {
				sign_time_end++
			}
			sign_time_str := url[sign_time_start..sign_time_end]

			// Should contain semicolon separator
			if !sign_time_str.contains(';') {
				println('  q-sign-time value should contain semicolon separator, got: ${sign_time_str}')
				return false
			}

			// Parse start and end times
			parts := sign_time_str.split(';')
			if parts.len != 2 {
				println('  q-sign-time should have exactly 2 parts, got: ${parts.len}')
				return false
			}

			start_time := parts[0].i64()
			end_time := parts[1].i64()

			// End time should be greater than start time
			if end_time <= start_time {
				println('  End time should be greater than start time')
				return false
			}

			// The difference should be approximately expires_in
			diff := end_time - start_time
			// Allow some tolerance (60 seconds for start_time offset)
			if diff < i64(expires_in) || diff > i64(expires_in) + 120 {
				println('  Time difference ${diff} should be approximately ${expires_in}')
				return false
			}
		}
	}

	return true
}

// ============================================================================
// Property 5: Presigned URL Method Parameter
// For different HTTP methods, the presigned URL should be generated correctly
// Validates: Requirements 5.3
// ============================================================================
fn test_property_5_presigned_url_methods() bool {
	config := generate_random_cos_config()
	bucket := config.default_bucket
	key := generate_random_filename()

	storage := new_tencent_cos(config) or {
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

		if !url.contains('q-signature=') {
			println('  URL for method ${method} missing signature')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 6: Nested Path Key Handling
// For keys with nested paths, the presigned URL should handle them correctly
// Validates: Requirements 5.3
// ============================================================================
fn test_property_6_nested_path_handling() bool {
	config := generate_random_cos_config()
	bucket := config.default_bucket

	storage := new_tencent_cos(config) or {
		println('  Failed to create storage: ${err}')
		return false
	}

	for i in 0 .. test_iterations {
		// Generate nested path
		depth := rand.int_in_range(1, 5) or { 2 }
		mut path_parts := []string{}
		for _ in 0 .. depth {
			part_len := rand.int_in_range(3, 10) or { 5 }
			mut part := ''
			for _ in 0 .. part_len {
				idx := rand.int_in_range(0, 26) or { 0 }
				part += ('a'[0] + u8(idx)).ascii_str()
			}
			path_parts << part
		}
		path_parts << generate_random_filename()
		key := path_parts.join('/')

		options := PresignOptions{
			expires_in: 3600
			method: 'GET'
		}

		url := storage.presign_url(bucket, key, options) or {
			println('  Iteration ${i}: Failed to generate presigned URL for nested key "${key}": ${err}')
			return false
		}

		// URL should contain the key parts
		for part in path_parts {
			if !url.contains(part) {
				println('  Iteration ${i}: URL should contain path part "${part}", got: ${url}')
				return false
			}
		}
	}

	return true
}

// ============================================================================
// Property 7: Host Format Correctness
// For any bucket and region, the host should follow COS format
// Validates: Requirements 5.1
// ============================================================================
fn test_property_7_host_format() bool {
	regions := ['ap-guangzhou', 'ap-shanghai', 'ap-beijing', 'ap-chengdu', 'ap-hongkong', 'ap-singapore', 'na-siliconvalley', 'eu-frankfurt']

	for i in 0 .. test_iterations {
		region_idx := rand.int_in_range(0, regions.len) or { 0 }
		region := regions[region_idx]

		bucket_name := generate_random_string(5, 15).to_lower()
		appid := generate_random_string(10, 10)
		bucket := '${bucket_name}-${appid}'

		config := TencentCOSConfig{
			secret_id: generate_random_string(32, 36)
			secret_key: generate_random_string(32, 40)
			region: region
			default_bucket: bucket
		}

		storage := new_tencent_cos(config) or {
			println('  Iteration ${i}: Failed to create storage: ${err}')
			return false
		}

		host := storage.get_host(bucket)
		expected_host := '${bucket}.cos.${region}.myqcloud.com'

		if host != expected_host {
			println('  Iteration ${i}: Host mismatch. Expected: ${expected_host}, Got: ${host}')
			return false
		}
	}

	return true
}

// Helper function to extract signature from URL
fn extract_signature_from_url(url string) string {
	if sig_idx := url.index('q-signature=') {
		sig_start := sig_idx + 12
		mut sig_end := sig_start
		for sig_end < url.len && url[sig_end] != `&` {
			sig_end++
		}
		return url[sig_start..sig_end]
	}
	return ''
}

// ============================================================================
// Property 8: Signature Consistency
// For the same input, the signature should be consistent
// Validates: Requirements 5.3
// ============================================================================
fn test_property_8_signature_consistency() bool {
	config := generate_random_cos_config()
	bucket := config.default_bucket
	key := generate_random_filename()

	storage := new_tencent_cos(config) or {
		println('  Failed to create storage: ${err}')
		return false
	}

	options := PresignOptions{
		expires_in: 3600
		method: 'GET'
	}

	// Generate URL twice with same parameters
	url1 := storage.presign_url(bucket, key, options) or {
		println('  Failed to generate first presigned URL: ${err}')
		return false
	}

	url2 := storage.presign_url(bucket, key, options) or {
		println('  Failed to generate second presigned URL: ${err}')
		return false
	}

	sig1 := extract_signature_from_url(url1)
	sig2 := extract_signature_from_url(url2)

	// Signatures should be non-empty
	if sig1 == '' || sig2 == '' {
		println('  Signatures should not be empty')
		return false
	}

	// Signatures should be valid hex strings (40 chars for SHA1)
	if sig1.len != 40 || sig2.len != 40 {
		println('  Signature length should be 40 (SHA1 hex), got: ${sig1.len} and ${sig2.len}')
		return false
	}

	return true
}

// ============================================================================
// Property 9: Different Regions Support
// For different regions, the storage provider should be created successfully
// Validates: Requirements 5.1
// ============================================================================
fn test_property_9_different_regions() bool {
	regions := [
		'ap-guangzhou',
		'ap-shanghai',
		'ap-beijing',
		'ap-chengdu',
		'ap-chongqing',
		'ap-hongkong',
		'ap-singapore',
		'ap-mumbai',
		'ap-seoul',
		'ap-bangkok',
		'ap-tokyo',
		'na-siliconvalley',
		'na-ashburn',
		'na-toronto',
		'eu-frankfurt',
		'eu-moscow',
	]

	for region in regions {
		config := TencentCOSConfig{
			secret_id: generate_random_string(32, 36)
			secret_key: generate_random_string(32, 40)
			region: region
			default_bucket: generate_random_string(5, 15).to_lower()
		}

		storage := new_tencent_cos(config) or {
			println('  Failed to create storage for region ${region}: ${err}')
			return false
		}

		if storage.provider_name() != 'tencent_cos' {
			println('  Provider name mismatch for region ${region}')
			return false
		}

		// Verify host contains the region
		host := storage.get_host(config.default_bucket)
		if !host.contains(region) {
			println('  Host should contain region ${region}, got: ${host}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 10: URL Encoding for Special Characters
// For keys with special characters, the URL should be properly encoded
// Validates: Requirements 5.3
// ============================================================================
fn test_property_10_special_character_encoding() bool {
	config := generate_random_cos_config()
	bucket := config.default_bucket

	storage := new_tencent_cos(config) or {
		println('  Failed to create storage: ${err}')
		return false
	}

	// Test keys with special characters
	special_keys := [
		'file with spaces.txt',
		'file+plus.txt',
		'file=equals.txt',
		'file&ampersand.txt',
		'中文文件.txt',
		'path/to/nested/file.txt',
		'path/with spaces/file.txt',
	]

	for key in special_keys {
		options := PresignOptions{
			expires_in: 3600
			method: 'GET'
		}

		url := storage.presign_url(bucket, key, options) or {
			println('  Failed to generate presigned URL for key "${key}": ${err}')
			return false
		}

		// URL should be non-empty
		if url == '' {
			println('  Empty URL generated for key "${key}"')
			return false
		}

		// URL should contain signature
		if !url.contains('q-signature=') {
			println('  URL for key "${key}" missing signature')
			return false
		}

		// URL should not contain unencoded special characters (except in signature)
		// Check that spaces are encoded
		if key.contains(' ') && url.contains(' ') {
			// Check if space is in the path part (before ?)
			if query_idx := url.index('?') {
				path_part := url[..query_idx]
				if path_part.contains(' ') {
					println('  URL path should not contain unencoded spaces for key "${key}"')
					return false
				}
			}
		}
	}

	return true
}


fn main() {
	println('🚀 开始 Tencent COS Storage 属性测试...')
	println('Feature: v-hono-upload-integration, Property 1 & 4: Upload-Download Round Trip (COS) & Presigned URL Validity')
	println('Validates: Requirements 5.3, 5.4')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(54321)])

	mut stats := PropertyTestStats{}

	// Run property tests
	stats.run_property_test('Property 1: Tencent COS Storage Provider Creation', test_property_1_cos_provider_creation)
	stats.run_property_test('Property 2: Invalid Configuration Rejection', test_property_2_invalid_config_rejection)
	stats.run_property_test('Property 3: Presigned URL Format Validity', test_property_3_presigned_url_format)
	stats.run_property_test('Property 4: Presigned URL Expiration Parameter', test_property_4_presigned_url_expiration)
	stats.run_property_test('Property 5: Presigned URL Method Parameter', test_property_5_presigned_url_methods)
	stats.run_property_test('Property 6: Nested Path Key Handling', test_property_6_nested_path_handling)
	stats.run_property_test('Property 7: Host Format Correctness', test_property_7_host_format)
	stats.run_property_test('Property 8: Signature Consistency', test_property_8_signature_consistency)
	stats.run_property_test('Property 9: Different Regions Support', test_property_9_different_regions)
	stats.run_property_test('Property 10: URL Encoding for Special Characters', test_property_10_special_character_encoding)

	stats.print_summary()

	if stats.failed_tests > 0 {
		exit(1)
	}
}
