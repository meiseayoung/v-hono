module hono

import os
import x.json2

// 存储类型枚举
pub enum StorageType {
	local
	s3
	aliyun_oss
	tencent_cos
}

// 本地存储配置
pub struct LocalStorageConfig {
pub:
	base_path   string = './storage'
	url_prefix  string = '/files' // 用于生成访问URL
	create_dirs bool   = true
}

// S3 存储配置
pub struct S3Config {
pub:
	endpoint       string
	access_key     string
	secret_key     string
	region         string = 'us-east-1'
	use_ssl        bool   = true
	path_style     bool // MinIO 通常需要 true
	default_bucket string
}

// 阿里云 OSS 配置
pub struct AliyunOSSConfig {
pub:
	endpoint          string // oss-cn-hangzhou.aliyuncs.com
	access_key_id     string
	access_key_secret string
	internal_endpoint string // 内网端点（可选）
	default_bucket    string
}

// 腾讯云 COS 配置
pub struct TencentCOSConfig {
pub:
	secret_id      string
	secret_key     string
	region         string // ap-guangzhou
	default_bucket string
}


// 统一存储配置
pub struct StorageConfig {
pub:
	storage_type  StorageType
	local         LocalStorageConfig
	s3            S3Config
	aliyun_oss    AliyunOSSConfig
	tencent_cos   TencentCOSConfig
	// 通用配置
	retry_count    int = 3
	retry_delay_ms int = 1000
	timeout_ms     int = 30000
}

// 配置验证结果
pub struct ConfigValidationResult {
pub:
	valid          bool
	missing_fields []string
	error_message  string
}

// 验证本地存储配置
pub fn validate_local_config(config LocalStorageConfig) ConfigValidationResult {
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

// 验证 S3 配置
pub fn validate_s3_config(config S3Config) ConfigValidationResult {
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

// 验证阿里云 OSS 配置
pub fn validate_aliyun_oss_config(config AliyunOSSConfig) ConfigValidationResult {
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

// 验证腾讯云 COS 配置
pub fn validate_tencent_cos_config(config TencentCOSConfig) ConfigValidationResult {
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

// 验证存储配置
pub fn validate_storage_config(config StorageConfig) ConfigValidationResult {
	match config.storage_type {
		.local {
			return validate_local_config(config.local)
		}
		.s3 {
			return validate_s3_config(config.s3)
		}
		.aliyun_oss {
			return validate_aliyun_oss_config(config.aliyun_oss)
		}
		.tencent_cos {
			return validate_tencent_cos_config(config.tencent_cos)
		}
	}
}


// JSON 配置文件结构（用于解析）
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

// 从 JSON 文件加载存储配置
pub fn load_storage_config_from_file(file_path string) !StorageConfig {
	if !os.exists(file_path) {
		return error('Configuration file not found: ${file_path}')
	}

	content := os.read_file(file_path) or {
		return error('Failed to read configuration file: ${err}')
	}

	return parse_storage_config_from_json(content)
}

// 从 JSON 字符串解析存储配置
pub fn parse_storage_config_from_json(json_str string) !StorageConfig {
	json_config := json2.decode[JsonStorageConfig](json_str) or {
		return error('Failed to parse JSON configuration: ${err}')
	}

	storage_type := parse_storage_type(json_config.storage_type) or {
		return error('Invalid storage type: ${json_config.storage_type}')
	}

	config := StorageConfig{
		storage_type: storage_type
		local: LocalStorageConfig{
			base_path: if json_config.local.base_path != '' {
				json_config.local.base_path
			} else {
				'./storage'
			}
			url_prefix: if json_config.local.url_prefix != '' {
				json_config.local.url_prefix
			} else {
				'/files'
			}
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
		retry_delay_ms: if json_config.retry_delay_ms > 0 {
			json_config.retry_delay_ms
		} else {
			1000
		}
		timeout_ms: if json_config.timeout_ms > 0 { json_config.timeout_ms } else { 30000 }
	}

	// 验证配置
	validation := validate_storage_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return config
}

// 解析存储类型字符串
fn parse_storage_type(type_str string) !StorageType {
	match type_str.to_lower() {
		'local' { return .local }
		's3' { return .s3 }
		'aliyun_oss', 'oss' { return .aliyun_oss }
		'tencent_cos', 'cos' { return .tencent_cos }
		else { return error('Unknown storage type: ${type_str}') }
	}
}


// 从环境变量加载存储配置
pub fn load_storage_config_from_env() !StorageConfig {
	storage_type_str := os.getenv('STORAGE_TYPE')
	if storage_type_str == '' {
		return error('Environment variable STORAGE_TYPE is not set')
	}

	storage_type := parse_storage_type(storage_type_str) or {
		return error('Invalid STORAGE_TYPE: ${storage_type_str}')
	}

	config := StorageConfig{
		storage_type: storage_type
		local: LocalStorageConfig{
			base_path: os.getenv_opt('STORAGE_LOCAL_BASE_PATH') or { './storage' }
			url_prefix: os.getenv_opt('STORAGE_LOCAL_URL_PREFIX') or { '/files' }
			create_dirs: os.getenv_opt('STORAGE_LOCAL_CREATE_DIRS') or { 'true' } == 'true'
		}
		s3: S3Config{
			endpoint: os.getenv('STORAGE_S3_ENDPOINT')
			access_key: os.getenv('STORAGE_S3_ACCESS_KEY')
			secret_key: os.getenv('STORAGE_S3_SECRET_KEY')
			region: os.getenv_opt('STORAGE_S3_REGION') or { 'us-east-1' }
			use_ssl: os.getenv_opt('STORAGE_S3_USE_SSL') or { 'true' } == 'true'
			path_style: os.getenv_opt('STORAGE_S3_PATH_STYLE') or { 'false' } == 'true'
			default_bucket: os.getenv('STORAGE_S3_DEFAULT_BUCKET')
		}
		aliyun_oss: AliyunOSSConfig{
			endpoint: os.getenv('STORAGE_OSS_ENDPOINT')
			access_key_id: os.getenv('STORAGE_OSS_ACCESS_KEY_ID')
			access_key_secret: os.getenv('STORAGE_OSS_ACCESS_KEY_SECRET')
			internal_endpoint: os.getenv('STORAGE_OSS_INTERNAL_ENDPOINT')
			default_bucket: os.getenv('STORAGE_OSS_DEFAULT_BUCKET')
		}
		tencent_cos: TencentCOSConfig{
			secret_id: os.getenv('STORAGE_COS_SECRET_ID')
			secret_key: os.getenv('STORAGE_COS_SECRET_KEY')
			region: os.getenv('STORAGE_COS_REGION')
			default_bucket: os.getenv('STORAGE_COS_DEFAULT_BUCKET')
		}
		retry_count: os.getenv_opt('STORAGE_RETRY_COUNT') or { '3' }.int()
		retry_delay_ms: os.getenv_opt('STORAGE_RETRY_DELAY_MS') or { '1000' }.int()
		timeout_ms: os.getenv_opt('STORAGE_TIMEOUT_MS') or { '30000' }.int()
	}

	// 验证配置
	validation := validate_storage_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return config
}

// 创建默认本地存储配置
pub fn new_local_storage_config(base_path string) StorageConfig {
	return StorageConfig{
		storage_type: .local
		local: LocalStorageConfig{
			base_path: base_path
			url_prefix: '/files'
			create_dirs: true
		}
	}
}

// 创建 S3 存储配置
pub fn new_s3_storage_config(endpoint string, access_key string, secret_key string, bucket string) StorageConfig {
	return StorageConfig{
		storage_type: .s3
		s3: S3Config{
			endpoint: endpoint
			access_key: access_key
			secret_key: secret_key
			region: 'us-east-1'
			use_ssl: true
			path_style: false
			default_bucket: bucket
		}
	}
}

// 创建 MinIO 存储配置（S3 兼容，使用 path_style）
pub fn new_minio_storage_config(endpoint string, access_key string, secret_key string, bucket string) StorageConfig {
	return StorageConfig{
		storage_type: .s3
		s3: S3Config{
			endpoint: endpoint
			access_key: access_key
			secret_key: secret_key
			region: 'us-east-1'
			use_ssl: false
			path_style: true
			default_bucket: bucket
		}
	}
}

// 创建阿里云 OSS 存储配置
pub fn new_aliyun_oss_storage_config(endpoint string, access_key_id string, access_key_secret string, bucket string) StorageConfig {
	return StorageConfig{
		storage_type: .aliyun_oss
		aliyun_oss: AliyunOSSConfig{
			endpoint: endpoint
			access_key_id: access_key_id
			access_key_secret: access_key_secret
			internal_endpoint: ''
			default_bucket: bucket
		}
	}
}

// 创建腾讯云 COS 存储配置
pub fn new_tencent_cos_storage_config(secret_id string, secret_key string, region string, bucket string) StorageConfig {
	return StorageConfig{
		storage_type: .tencent_cos
		tencent_cos: TencentCOSConfig{
			secret_id: secret_id
			secret_key: secret_key
			region: region
			default_bucket: bucket
		}
	}
}

// 获取存储类型名称
pub fn (t StorageType) str() string {
	match t {
		.local { return 'local' }
		.s3 { return 's3' }
		.aliyun_oss { return 'aliyun_oss' }
		.tencent_cos { return 'tencent_cos' }
	}
}
