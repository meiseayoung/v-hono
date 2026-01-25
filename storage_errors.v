module hono

import time

// 存储错误类型枚举
pub enum StorageErrorKind {
	// 可重试错误 - 网络和临时性问题
	network_timeout
	service_unavailable
	rate_limited
	connection_reset
	temporary_failure
	// 不可重试错误 - 配置和权限问题
	invalid_credentials
	access_denied
	bucket_not_found
	object_not_found
	invalid_object_key
	quota_exceeded
	invalid_config
	bucket_not_empty
	bucket_already_exists
	object_already_exists
	invalid_range
	checksum_mismatch
	// 其他错误
	unknown
}

// 存储错误结构
pub struct StorageError {
pub:
	kind        StorageErrorKind
	message     string
	provider    string
	operation   string
	http_status int
	retry_count int
	details     map[string]string
pub mut:
	retry_history []RetryAttempt
}

// 重试尝试记录
pub struct RetryAttempt {
pub:
	attempt_number int
	timestamp      i64
	error_message  string
	delay_ms       int
}


// 判断错误是否可重试
pub fn (e StorageError) is_retryable() bool {
	return e.kind in [
		.network_timeout,
		.service_unavailable,
		.rate_limited,
		.connection_reset,
		.temporary_failure,
	]
}

// 获取建议的重试延迟（毫秒）
pub fn (e StorageError) suggested_retry_delay() int {
	base_delay := match e.kind {
		.rate_limited { 5000 } // 限流错误需要更长等待
		.service_unavailable { 2000 }
		.network_timeout { 1000 }
		.connection_reset { 500 }
		.temporary_failure { 1000 }
		else { 0 }
	}
	return base_delay
}

// 获取错误类别描述
pub fn (e StorageError) category() string {
	if e.is_retryable() {
		return 'retryable'
	}
	return 'non_retryable'
}

// 实现 IError 接口
pub fn (e StorageError) msg() string {
	return '${e.provider}/${e.operation}: ${e.message} (kind: ${e.kind}, http_status: ${e.http_status})'
}

pub fn (e StorageError) code() int {
	return e.http_status
}

// 添加重试记录
pub fn (mut e StorageError) add_retry_attempt(attempt_number int, error_message string, delay_ms int) {
	e.retry_history << RetryAttempt{
		attempt_number: attempt_number
		timestamp: time.now().unix()
		error_message: error_message
		delay_ms: delay_ms
	}
}

// 获取重试历史摘要
pub fn (e StorageError) retry_summary() string {
	if e.retry_history.len == 0 {
		return 'No retry attempts'
	}
	mut summary := 'Retry attempts: ${e.retry_history.len}\n'
	for attempt in e.retry_history {
		summary += '  Attempt ${attempt.attempt_number}: ${attempt.error_message} (delay: ${attempt.delay_ms}ms)\n'
	}
	return summary
}

// 创建存储错误的辅助函数
pub fn new_storage_error(kind StorageErrorKind, message string, provider string, operation string) StorageError {
	return StorageError{
		kind: kind
		message: message
		provider: provider
		operation: operation
		http_status: 0
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 创建带 HTTP 状态码的存储错误
pub fn new_storage_error_with_status(kind StorageErrorKind, message string, provider string, operation string, http_status int) StorageError {
	return StorageError{
		kind: kind
		message: message
		provider: provider
		operation: operation
		http_status: http_status
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 创建带详情的存储错误
pub fn new_storage_error_with_details(kind StorageErrorKind, message string, provider string, operation string, http_status int, details map[string]string) StorageError {
	return StorageError{
		kind: kind
		message: message
		provider: provider
		operation: operation
		http_status: http_status
		retry_count: 0
		details: details
		retry_history: []RetryAttempt{}
	}
}

// 创建配置错误
pub fn new_config_error(message string, field string) StorageError {
	mut details := map[string]string{}
	details['field'] = field
	return StorageError{
		kind: .invalid_config
		message: message
		provider: 'config'
		operation: 'validate'
		http_status: 0
		retry_count: 0
		details: details
		retry_history: []RetryAttempt{}
	}
}

// 创建对象未找到错误
pub fn new_not_found_error(provider string, bucket string, key string) StorageError {
	mut details := map[string]string{}
	details['bucket'] = bucket
	details['key'] = key
	return StorageError{
		kind: .object_not_found
		message: 'Object not found: ${bucket}/${key}'
		provider: provider
		operation: 'get'
		http_status: 404
		retry_count: 0
		details: details
		retry_history: []RetryAttempt{}
	}
}


// 创建存储桶未找到错误
pub fn new_bucket_not_found_error(provider string, bucket string) StorageError {
	mut details := map[string]string{}
	details['bucket'] = bucket
	return StorageError{
		kind: .bucket_not_found
		message: 'Bucket not found: ${bucket}'
		provider: provider
		operation: 'bucket'
		http_status: 404
		retry_count: 0
		details: details
		retry_history: []RetryAttempt{}
	}
}

// 创建访问拒绝错误
pub fn new_access_denied_error(provider string, operation string, resource string) StorageError {
	mut details := map[string]string{}
	details['resource'] = resource
	return StorageError{
		kind: .access_denied
		message: 'Access denied to resource: ${resource}'
		provider: provider
		operation: operation
		http_status: 403
		retry_count: 0
		details: details
		retry_history: []RetryAttempt{}
	}
}

// 创建网络超时错误
pub fn new_timeout_error(provider string, operation string) StorageError {
	return StorageError{
		kind: .network_timeout
		message: 'Network timeout during ${operation}'
		provider: provider
		operation: operation
		http_status: 0
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 创建服务不可用错误
pub fn new_service_unavailable_error(provider string, operation string, message string) StorageError {
	return StorageError{
		kind: .service_unavailable
		message: message
		provider: provider
		operation: operation
		http_status: 503
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 创建限流错误
pub fn new_rate_limited_error(provider string, operation string) StorageError {
	return StorageError{
		kind: .rate_limited
		message: 'Rate limited during ${operation}'
		provider: provider
		operation: operation
		http_status: 429
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 创建连接重置错误
pub fn new_connection_reset_error(provider string, operation string) StorageError {
	return StorageError{
		kind: .connection_reset
		message: 'Connection reset during ${operation}'
		provider: provider
		operation: operation
		http_status: 0
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 创建凭据无效错误
pub fn new_invalid_credentials_error(provider string, operation string) StorageError {
	return StorageError{
		kind: .invalid_credentials
		message: 'Invalid credentials for ${provider}'
		provider: provider
		operation: operation
		http_status: 401
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 创建配额超限错误
pub fn new_quota_exceeded_error(provider string, operation string, resource string) StorageError {
	mut details := map[string]string{}
	details['resource'] = resource
	return StorageError{
		kind: .quota_exceeded
		message: 'Quota exceeded for ${resource}'
		provider: provider
		operation: operation
		http_status: 413
		retry_count: 0
		details: details
		retry_history: []RetryAttempt{}
	}
}


// ============================================================================
// HTTP 状态码到错误类型的映射
// ============================================================================

// 从 HTTP 状态码映射到错误类型
pub fn error_kind_from_http_status(status int) StorageErrorKind {
	return match status {
		400 { StorageErrorKind.invalid_object_key }
		401 { StorageErrorKind.invalid_credentials }
		403 { StorageErrorKind.access_denied }
		404 { StorageErrorKind.object_not_found }
		409 { StorageErrorKind.bucket_already_exists }
		413 { StorageErrorKind.quota_exceeded }
		416 { StorageErrorKind.invalid_range }
		429 { StorageErrorKind.rate_limited }
		500 { StorageErrorKind.service_unavailable }
		502 { StorageErrorKind.service_unavailable }
		503 { StorageErrorKind.service_unavailable }
		504 { StorageErrorKind.network_timeout }
		else { StorageErrorKind.unknown }
	}
}

// ============================================================================
// 提供者特定的错误映射
// ============================================================================

// S3 错误代码映射
pub fn map_s3_error_code(error_code string, http_status int) StorageErrorKind {
	return match error_code {
		'AccessDenied' { StorageErrorKind.access_denied }
		'AccountProblem' { StorageErrorKind.access_denied }
		'AllAccessDisabled' { StorageErrorKind.access_denied }
		'BucketAlreadyExists' { StorageErrorKind.bucket_already_exists }
		'BucketAlreadyOwnedByYou' { StorageErrorKind.bucket_already_exists }
		'BucketNotEmpty' { StorageErrorKind.bucket_not_empty }
		'CredentialsNotSupported' { StorageErrorKind.invalid_credentials }
		'ExpiredToken' { StorageErrorKind.invalid_credentials }
		'InvalidAccessKeyId' { StorageErrorKind.invalid_credentials }
		'InvalidBucketName' { StorageErrorKind.invalid_object_key }
		'InvalidObjectName' { StorageErrorKind.invalid_object_key }
		'InvalidRange' { StorageErrorKind.invalid_range }
		'InvalidSecurity' { StorageErrorKind.invalid_credentials }
		'InvalidToken' { StorageErrorKind.invalid_credentials }
		'NoSuchBucket' { StorageErrorKind.bucket_not_found }
		'NoSuchKey' { StorageErrorKind.object_not_found }
		'NoSuchUpload' { StorageErrorKind.object_not_found }
		'RequestTimeout' { StorageErrorKind.network_timeout }
		'RequestTimeTooSkewed' { StorageErrorKind.invalid_credentials }
		'ServiceUnavailable' { StorageErrorKind.service_unavailable }
		'SignatureDoesNotMatch' { StorageErrorKind.invalid_credentials }
		'SlowDown' { StorageErrorKind.rate_limited }
		'TemporaryRedirect' { StorageErrorKind.temporary_failure }
		'TokenRefreshRequired' { StorageErrorKind.invalid_credentials }
		else { error_kind_from_http_status(http_status) }
	}
}

// 阿里云 OSS 错误代码映射
pub fn map_aliyun_oss_error_code(error_code string, http_status int) StorageErrorKind {
	return match error_code {
		'AccessDenied' { StorageErrorKind.access_denied }
		'BucketAlreadyExists' { StorageErrorKind.bucket_already_exists }
		'BucketNotEmpty' { StorageErrorKind.bucket_not_empty }
		'EntityTooLarge' { StorageErrorKind.quota_exceeded }
		'EntityTooSmall' { StorageErrorKind.invalid_object_key }
		'FileGroupTooLarge' { StorageErrorKind.quota_exceeded }
		'InvalidAccessKeyId' { StorageErrorKind.invalid_credentials }
		'InvalidArgument' { StorageErrorKind.invalid_object_key }
		'InvalidBucketName' { StorageErrorKind.invalid_object_key }
		'InvalidDigest' { StorageErrorKind.checksum_mismatch }
		'InvalidObjectName' { StorageErrorKind.invalid_object_key }
		'InvalidRange' { StorageErrorKind.invalid_range }
		'NoSuchBucket' { StorageErrorKind.bucket_not_found }
		'NoSuchKey' { StorageErrorKind.object_not_found }
		'NoSuchUpload' { StorageErrorKind.object_not_found }
		'RequestTimeout' { StorageErrorKind.network_timeout }
		'RequestTimeTooSkewed' { StorageErrorKind.invalid_credentials }
		'ServiceUnavailable' { StorageErrorKind.service_unavailable }
		'SignatureDoesNotMatch' { StorageErrorKind.invalid_credentials }
		'TooManyBuckets' { StorageErrorKind.quota_exceeded }
		else { error_kind_from_http_status(http_status) }
	}
}

// 腾讯云 COS 错误代码映射
pub fn map_tencent_cos_error_code(error_code string, http_status int) StorageErrorKind {
	return match error_code {
		'AccessDenied' { StorageErrorKind.access_denied }
		'BucketAlreadyExists' { StorageErrorKind.bucket_already_exists }
		'BucketAlreadyOwnedByYou' { StorageErrorKind.bucket_already_exists }
		'BucketNotEmpty' { StorageErrorKind.bucket_not_empty }
		'EntityTooLarge' { StorageErrorKind.quota_exceeded }
		'EntityTooSmall' { StorageErrorKind.invalid_object_key }
		'InvalidAccessKeyId' { StorageErrorKind.invalid_credentials }
		'InvalidArgument' { StorageErrorKind.invalid_object_key }
		'InvalidBucketName' { StorageErrorKind.invalid_object_key }
		'InvalidDigest' { StorageErrorKind.checksum_mismatch }
		'InvalidObjectName' { StorageErrorKind.invalid_object_key }
		'InvalidRange' { StorageErrorKind.invalid_range }
		'NoSuchBucket' { StorageErrorKind.bucket_not_found }
		'NoSuchKey' { StorageErrorKind.object_not_found }
		'NoSuchUpload' { StorageErrorKind.object_not_found }
		'RequestTimeout' { StorageErrorKind.network_timeout }
		'RequestTimeTooSkewed' { StorageErrorKind.invalid_credentials }
		'ServiceUnavailable' { StorageErrorKind.service_unavailable }
		'SignatureDoesNotMatch' { StorageErrorKind.invalid_credentials }
		'SlowDown' { StorageErrorKind.rate_limited }
		'TooManyBuckets' { StorageErrorKind.quota_exceeded }
		else { error_kind_from_http_status(http_status) }
	}
}


// ============================================================================
// 从错误消息解析错误代码
// ============================================================================

// 从 XML 错误响应中提取错误代码
pub fn extract_error_code_from_xml(body string) string {
	if code_start := body.index('<Code>') {
		if code_end := body.index('</Code>') {
			return body[code_start + 6..code_end]
		}
	}
	return ''
}

// 从 XML 错误响应中提取错误消息
pub fn extract_error_message_from_xml(body string) string {
	if message_start := body.index('<Message>') {
		if message_end := body.index('</Message>') {
			return body[message_start + 9..message_end]
		}
	}
	return ''
}

// ============================================================================
// 创建提供者特定的错误
// ============================================================================

// 从 S3 响应创建错误
pub fn new_s3_error_from_response(body string, http_status int, operation string) StorageError {
	error_code := extract_error_code_from_xml(body)
	error_message := extract_error_message_from_xml(body)
	
	kind := map_s3_error_code(error_code, http_status)
	message := if error_message != '' { error_message } else { 'HTTP ${http_status}' }
	
	mut details := map[string]string{}
	if error_code != '' {
		details['error_code'] = error_code
	}
	
	return new_storage_error_with_details(kind, message, 's3', operation, http_status, details)
}

// 从阿里云 OSS 响应创建错误
pub fn new_aliyun_oss_error_from_response(body string, http_status int, operation string) StorageError {
	error_code := extract_error_code_from_xml(body)
	error_message := extract_error_message_from_xml(body)
	
	kind := map_aliyun_oss_error_code(error_code, http_status)
	message := if error_message != '' { error_message } else { 'HTTP ${http_status}' }
	
	mut details := map[string]string{}
	if error_code != '' {
		details['error_code'] = error_code
	}
	
	return new_storage_error_with_details(kind, message, 'aliyun_oss', operation, http_status, details)
}

// 从腾讯云 COS 响应创建错误
pub fn new_tencent_cos_error_from_response(body string, http_status int, operation string) StorageError {
	error_code := extract_error_code_from_xml(body)
	error_message := extract_error_message_from_xml(body)
	
	kind := map_tencent_cos_error_code(error_code, http_status)
	message := if error_message != '' { error_message } else { 'HTTP ${http_status}' }
	
	mut details := map[string]string{}
	if error_code != '' {
		details['error_code'] = error_code
	}
	
	return new_storage_error_with_details(kind, message, 'tencent_cos', operation, http_status, details)
}
