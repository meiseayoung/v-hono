module main

import rand
import time
import x.json2

// ============================================================================
// Property 3: Configuration Validation
// Feature: v-hono-upload-integration, Property 3: Configuration Validation
// Validates: Requirements 3.3, 4.2, 5.2, 6.4, 6.5
//
// *For any* storage configuration with missing required fields, attempting to
// create a storage provider should return an error that identifies the missing field(s).
// ============================================================================

const test_iterations = 100

// ============================================================================
// Type definitions (copied from storage_config.v for standalone testing)
// ============================================================================

enum StorageType {
	local
	s3
	aliyun_oss
	tencent_cos
}

struct LocalStorageConfig {
pub:
	base_path   string = './storage'
	url_prefix  string = '/files'
	create_dirs bool   = true
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

struct AliyunOSSConfig {
pub:
	endpoint          string
	access_key_id     string
	access_key_secret string
	internal_endpoint string
	default_bucket    string
}

struct TencentCOSConfig {
pub:
	secret_id      string
	secret_key     string
	region         string
	default_bucket string
}

struct StorageConfig {
pub:
	storage_type   StorageType
	local          LocalStorageConfig
	s3             S3Config
	aliyun_oss     AliyunOSSConfig
	tencent_cos    TencentCOSConfig
	retry_count    int = 3
	retry_delay_ms int = 1000
	timeout_ms     int = 30000
}

struct ConfigValidationResult {
pub:
	valid          bool
	missing_fields []string
	error_message  string
}


// ============================================================================
// Validation functions (copied from storage_config.v for standalone testing)
// ============================================================================

fn validate_local_config(config LocalStorageConfig) ConfigValidationResult {
	mut missing := []string{}
	if config.base_path == '' {
		missing << 'local.base_path'
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

fn validate_aliyun_oss_config(config AliyunOSSConfig) ConfigValidationResult {
	mut missing := []string{}
	if config.endpoint == '' {
		missing << 'aliyun_oss.endpoint'
	}
	if config.access_key_id == '' {
		missing << 'aliyun_oss.access_key_id'
	}
	if config.access_key_secret == '' {
		missing << 'aliyun_oss.access_key_secret'
	}
	if config.default_bucket == '' {
		missing << 'aliyun_oss.default_bucket'
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

fn validate_storage_config(config StorageConfig) ConfigValidationResult {
	match config.storage_type {
		.local { return validate_local_config(config.local) }
		.s3 { return validate_s3_config(config.s3) }
		.aliyun_oss { return validate_aliyun_oss_config(config.aliyun_oss) }
		.tencent_cos { return validate_tencent_cos_config(config.tencent_cos) }
	}
}


// ============================================================================
// JSON parsing structures and functions
// ============================================================================

struct JsonStorageConfig {
pub:
	storage_type   string @[json: 'storage_type']
	local          JsonLocalConfig @[json: 'local']
	s3             JsonS3Config @[json: 's3']
	aliyun_oss     JsonAliyunOSSConfig @[json: 'aliyun_oss']
	tencent_cos    JsonTencentCOSConfig @[json: 'tencent_cos']
	retry_count    int = 3 @[json: 'retry_count']
	retry_delay_ms int = 1000 @[json: 'retry_delay_ms']
	timeout_ms     int = 30000 @[json: 'timeout_ms']
}

struct JsonLocalConfig {
pub:
	base_path   string @[json: 'base_path']
	url_prefix  string @[json: 'url_prefix']
	create_dirs bool   = true @[json: 'create_dirs']
}

struct JsonS3Config {
pub:
	endpoint       string @[json: 'endpoint']
	access_key     string @[json: 'access_key']
	secret_key     string @[json: 'secret_key']
	region         string = 'us-east-1' @[json: 'region']
	use_ssl        bool   = true @[json: 'use_ssl']
	path_style     bool   @[json: 'path_style']
	default_bucket string @[json: 'default_bucket']
}

struct JsonAliyunOSSConfig {
pub:
	endpoint          string @[json: 'endpoint']
	access_key_id     string @[json: 'access_key_id']
	access_key_secret string @[json: 'access_key_secret']
	internal_endpoint string @[json: 'internal_endpoint']
	default_bucket    string @[json: 'default_bucket']
}

struct JsonTencentCOSConfig {
pub:
	secret_id      string @[json: 'secret_id']
	secret_key     string @[json: 'secret_key']
	region         string @[json: 'region']
	default_bucket string @[json: 'default_bucket']
}

fn parse_storage_type(type_str string) !StorageType {
	match type_str.to_lower() {
		'local' { return .local }
		's3' { return .s3 }
		'aliyun_oss', 'oss' { return .aliyun_oss }
		'tencent_cos', 'cos' { return .tencent_cos }
		else { return error('Unknown storage type: ${type_str}') }
	}
}

fn parse_storage_config_from_json(json_str string) !StorageConfig {
	json_config := json2.decode[JsonStorageConfig](json_str) or {
		return error('Failed to parse JSON configuration: ${err}')
	}

	storage_type := parse_storage_type(json_config.storage_type) or {
		return error('Invalid storage type: ${json_config.storage_type}')
	}

	config := StorageConfig{
		storage_type: storage_type
		local: LocalStorageConfig{
			base_path: if json_config.local.base_path != '' { json_config.local.base_path } else { './storage' }
			url_prefix: if json_config.local.url_prefix != '' { json_config.local.url_prefix } else { '/files' }
			create_dirs: json_config.local.create_dirs
		}
		s3: S3Config{
			endpoint: json_config.s3.endpoint
			access_key: json_config.s3.access_key
			secret_key: json_config.s3.secret_key
			region: if json_config.s3.region != '' { json_config.s3.region } else { 'us-east-1' }
			use_ssl: json_config.s3.use_ssl
			path_style: json_config.s3.path_style
			default_bucket: json_config.s3.default_bucket
		}
		aliyun_oss: AliyunOSSConfig{
			endpoint: json_config.aliyun_oss.endpoint
			access_key_id: json_config.aliyun_oss.access_key_id
			access_key_secret: json_config.aliyun_oss.access_key_secret
			internal_endpoint: json_config.aliyun_oss.internal_endpoint
			default_bucket: json_config.aliyun_oss.default_bucket
		}
		tencent_cos: TencentCOSConfig{
			secret_id: json_config.tencent_cos.secret_id
			secret_key: json_config.tencent_cos.secret_key
			region: json_config.tencent_cos.region
			default_bucket: json_config.tencent_cos.default_bucket
		}
		retry_count: if json_config.retry_count > 0 { json_config.retry_count } else { 3 }
		retry_delay_ms: if json_config.retry_delay_ms > 0 { json_config.retry_delay_ms } else { 1000 }
		timeout_ms: if json_config.timeout_ms > 0 { json_config.timeout_ms } else { 30000 }
	}

	validation := validate_storage_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return config
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
	println('\n=== Configuration Validation 属性测试总结 ===')
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

fn generate_random_bool() bool {
	return rand.int_in_range(0, 2) or { 0 } == 1
}


// ============================================================================
// Property 3.1: Local Storage Config Validation - Missing base_path
// ============================================================================
fn test_property_3_1_local_missing_base_path() bool {
	for _ in 0 .. test_iterations {
		config := StorageConfig{
			storage_type: .local
			local: LocalStorageConfig{
				base_path: ''
				url_prefix: generate_random_string(1, 20)
				create_dirs: generate_random_bool()
			}
		}

		result := validate_storage_config(config)

		if result.valid {
			println('  Failed: Config with empty base_path was marked as valid')
			return false
		}

		if 'local.base_path' !in result.missing_fields {
			println('  Failed: Missing fields does not contain "local.base_path": ${result.missing_fields}')
			return false
		}

		if result.error_message == '' {
			println('  Failed: Error message is empty')
			return false
		}
	}
	return true
}

// ============================================================================
// Property 3.2: Local Storage Config Validation - Valid config
// ============================================================================
fn test_property_3_2_local_valid_config() bool {
	for _ in 0 .. test_iterations {
		config := StorageConfig{
			storage_type: .local
			local: LocalStorageConfig{
				base_path: generate_random_string(1, 50)
				url_prefix: generate_random_string(1, 20)
				create_dirs: generate_random_bool()
			}
		}

		result := validate_storage_config(config)

		if !result.valid {
			println('  Failed: Valid config was marked as invalid: ${result.error_message}')
			return false
		}

		if result.missing_fields.len > 0 {
			println('  Failed: Valid config has missing fields: ${result.missing_fields}')
			return false
		}
	}
	return true
}

// ============================================================================
// Property 3.3: S3 Config Validation - Missing required fields
// Validates: Requirements 3.3
// ============================================================================
fn test_property_3_3_s3_missing_fields() bool {
	for _ in 0 .. test_iterations {
		has_endpoint := generate_random_bool()
		has_access_key := generate_random_bool()
		has_secret_key := generate_random_bool()
		has_bucket := generate_random_bool()

		if has_endpoint && has_access_key && has_secret_key && has_bucket {
			continue
		}

		config := StorageConfig{
			storage_type: .s3
			s3: S3Config{
				endpoint: if has_endpoint { generate_random_string(5, 30) } else { '' }
				access_key: if has_access_key { generate_random_string(10, 30) } else { '' }
				secret_key: if has_secret_key { generate_random_string(20, 50) } else { '' }
				region: 'us-east-1'
				use_ssl: true
				default_bucket: if has_bucket { generate_random_string(3, 20) } else { '' }
			}
		}

		result := validate_storage_config(config)

		if result.valid {
			println('  Failed: Config with missing fields was marked as valid')
			return false
		}

		if !has_endpoint && 's3.endpoint' !in result.missing_fields {
			println('  Failed: Missing s3.endpoint not identified')
			return false
		}
		if !has_access_key && 's3.access_key' !in result.missing_fields {
			println('  Failed: Missing s3.access_key not identified')
			return false
		}
		if !has_secret_key && 's3.secret_key' !in result.missing_fields {
			println('  Failed: Missing s3.secret_key not identified')
			return false
		}
		if !has_bucket && 's3.default_bucket' !in result.missing_fields {
			println('  Failed: Missing s3.default_bucket not identified')
			return false
		}
	}
	return true
}

// ============================================================================
// Property 3.4: S3 Config Validation - Valid config
// ============================================================================
fn test_property_3_4_s3_valid_config() bool {
	for _ in 0 .. test_iterations {
		config := StorageConfig{
			storage_type: .s3
			s3: S3Config{
				endpoint: generate_random_string(5, 30)
				access_key: generate_random_string(10, 30)
				secret_key: generate_random_string(20, 50)
				region: generate_random_string(5, 15)
				use_ssl: generate_random_bool()
				path_style: generate_random_bool()
				default_bucket: generate_random_string(3, 20)
			}
		}

		result := validate_storage_config(config)

		if !result.valid {
			println('  Failed: Valid S3 config was marked as invalid: ${result.error_message}')
			return false
		}
	}
	return true
}


// ============================================================================
// Property 3.5: Aliyun OSS Config Validation - Missing required fields
// Validates: Requirements 4.2
// ============================================================================
fn test_property_3_5_aliyun_oss_missing_fields() bool {
	for _ in 0 .. test_iterations {
		has_endpoint := generate_random_bool()
		has_key_id := generate_random_bool()
		has_key_secret := generate_random_bool()
		has_bucket := generate_random_bool()

		if has_endpoint && has_key_id && has_key_secret && has_bucket {
			continue
		}

		config := StorageConfig{
			storage_type: .aliyun_oss
			aliyun_oss: AliyunOSSConfig{
				endpoint: if has_endpoint { generate_random_string(10, 40) } else { '' }
				access_key_id: if has_key_id { generate_random_string(10, 30) } else { '' }
				access_key_secret: if has_key_secret { generate_random_string(20, 50) } else { '' }
				default_bucket: if has_bucket { generate_random_string(3, 20) } else { '' }
			}
		}

		result := validate_storage_config(config)

		if result.valid {
			println('  Failed: Config with missing fields was marked as valid')
			return false
		}

		if !has_endpoint && 'aliyun_oss.endpoint' !in result.missing_fields {
			println('  Failed: Missing aliyun_oss.endpoint not identified')
			return false
		}
		if !has_key_id && 'aliyun_oss.access_key_id' !in result.missing_fields {
			println('  Failed: Missing aliyun_oss.access_key_id not identified')
			return false
		}
		if !has_key_secret && 'aliyun_oss.access_key_secret' !in result.missing_fields {
			println('  Failed: Missing aliyun_oss.access_key_secret not identified')
			return false
		}
		if !has_bucket && 'aliyun_oss.default_bucket' !in result.missing_fields {
			println('  Failed: Missing aliyun_oss.default_bucket not identified')
			return false
		}
	}
	return true
}

// ============================================================================
// Property 3.6: Tencent COS Config Validation - Missing required fields
// Validates: Requirements 5.2
// ============================================================================
fn test_property_3_6_tencent_cos_missing_fields() bool {
	for _ in 0 .. test_iterations {
		has_secret_id := generate_random_bool()
		has_secret_key := generate_random_bool()
		has_region := generate_random_bool()
		has_bucket := generate_random_bool()

		if has_secret_id && has_secret_key && has_region && has_bucket {
			continue
		}

		config := StorageConfig{
			storage_type: .tencent_cos
			tencent_cos: TencentCOSConfig{
				secret_id: if has_secret_id { generate_random_string(10, 30) } else { '' }
				secret_key: if has_secret_key { generate_random_string(20, 50) } else { '' }
				region: if has_region { generate_random_string(5, 15) } else { '' }
				default_bucket: if has_bucket { generate_random_string(3, 20) } else { '' }
			}
		}

		result := validate_storage_config(config)

		if result.valid {
			println('  Failed: Config with missing fields was marked as valid')
			return false
		}

		if !has_secret_id && 'tencent_cos.secret_id' !in result.missing_fields {
			println('  Failed: Missing tencent_cos.secret_id not identified')
			return false
		}
		if !has_secret_key && 'tencent_cos.secret_key' !in result.missing_fields {
			println('  Failed: Missing tencent_cos.secret_key not identified')
			return false
		}
		if !has_region && 'tencent_cos.region' !in result.missing_fields {
			println('  Failed: Missing tencent_cos.region not identified')
			return false
		}
		if !has_bucket && 'tencent_cos.default_bucket' !in result.missing_fields {
			println('  Failed: Missing tencent_cos.default_bucket not identified')
			return false
		}
	}
	return true
}

// ============================================================================
// Property 3.7: JSON Config Parsing - Invalid config returns error
// Validates: Requirements 6.4, 6.5
// ============================================================================
fn test_property_3_7_json_parsing_invalid_config() bool {
	invalid_json := '{"storage_type": "s3", "s3": {"endpoint": "", "access_key": "", "secret_key": "", "default_bucket": ""}}'

	_ := parse_storage_config_from_json(invalid_json) or {
		if err.msg() == '' {
			println('  Failed: Error message is empty')
			return false
		}
		return true
	}

	println('  Failed: Invalid JSON config was parsed successfully')
	return false
}

// ============================================================================
// Property 3.8: JSON Config Parsing - Valid config parses successfully
// Validates: Requirements 6.4, 6.5
// ============================================================================
fn test_property_3_8_json_parsing_valid_config() bool {
	for _ in 0 .. test_iterations {
		base_path := generate_random_string(5, 30)
		url_prefix := '/' + generate_random_string(3, 10)

		valid_json := '{"storage_type": "local", "local": {"base_path": "${base_path}", "url_prefix": "${url_prefix}", "create_dirs": true}}'

		config := parse_storage_config_from_json(valid_json) or {
			println('  Failed: Valid JSON config failed to parse: ${err}')
			return false
		}

		if config.storage_type != .local {
			println('  Failed: Storage type mismatch')
			return false
		}

		if config.local.base_path != base_path {
			println('  Failed: base_path mismatch')
			return false
		}
	}
	return true
}


fn main() {
	println('🚀 开始 Configuration Validation 属性测试...')
	println('Feature: v-hono-upload-integration, Property 3: Configuration Validation')
	println('Validates: Requirements 3.3, 4.2, 5.2, 6.4, 6.5')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(12345)])

	mut stats := PropertyTestStats{}

	stats.run_property_test('Property 3.1: Local Storage - Missing base_path', test_property_3_1_local_missing_base_path)
	stats.run_property_test('Property 3.2: Local Storage - Valid config', test_property_3_2_local_valid_config)
	stats.run_property_test('Property 3.3: S3 - Missing required fields', test_property_3_3_s3_missing_fields)
	stats.run_property_test('Property 3.4: S3 - Valid config', test_property_3_4_s3_valid_config)
	stats.run_property_test('Property 3.5: Aliyun OSS - Missing required fields', test_property_3_5_aliyun_oss_missing_fields)
	stats.run_property_test('Property 3.6: Tencent COS - Missing required fields', test_property_3_6_tencent_cos_missing_fields)
	stats.run_property_test('Property 3.7: JSON Parsing - Invalid config returns error', test_property_3_7_json_parsing_invalid_config)
	stats.run_property_test('Property 3.8: JSON Parsing - Valid config parses successfully', test_property_3_8_json_parsing_valid_config)

	stats.print_summary()

	if stats.failed_tests > 0 {
		exit(1)
	}
}
