module main

import rand
import time

// ============================================================================
// Property 8: Error Classification
// Feature: v-hono-upload-integration, Property 8: Error Classification
// Validates: Requirements 9.4
//
// *For any* storage operation failure, the error should be correctly classified
// as retryable (network timeout, temporary unavailable) or non-retryable
// (invalid credentials, file not found).
// ============================================================================

const test_iterations = 100

// ============================================================================
// Type definitions (copied from storage_errors.v for standalone testing)
// ============================================================================

// 存储错误类型枚举
enum StorageErrorKind {
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

// 重试尝试记录
struct RetryAttempt {
pub:
	attempt_number int
	timestamp      i64
	error_message  string
	delay_ms       int
}

// 存储错误结构
struct StorageError {
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


// 判断错误是否可重试
fn (e StorageError) is_retryable() bool {
	return e.kind in [
		.network_timeout,
		.service_unavailable,
		.rate_limited,
		.connection_reset,
		.temporary_failure,
	]
}

// 获取建议的重试延迟（毫秒）
fn (e StorageError) suggested_retry_delay() int {
	base_delay := match e.kind {
		.rate_limited { 5000 }
		.service_unavailable { 2000 }
		.network_timeout { 1000 }
		.connection_reset { 500 }
		.temporary_failure { 1000 }
		else { 0 }
	}
	return base_delay
}

// 获取错误类别描述
fn (e StorageError) category() string {
	if e.is_retryable() {
		return 'retryable'
	}
	return 'non_retryable'
}

// 实现 IError 接口
fn (e StorageError) msg() string {
	return '${e.provider}/${e.operation}: ${e.message} (kind: ${e.kind}, http_status: ${e.http_status})'
}

// 添加重试记录
fn (mut e StorageError) add_retry_attempt(attempt_number int, error_message string, delay_ms int) {
	e.retry_history << RetryAttempt{
		attempt_number: attempt_number
		timestamp: time.now().unix()
		error_message: error_message
		delay_ms: delay_ms
	}
}

// 获取重试历史摘要
fn (e StorageError) retry_summary() string {
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
fn new_storage_error(kind StorageErrorKind, message string, provider string, operation string) StorageError {
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


// ============================================================================
// HTTP 状态码到错误类型的映射
// ============================================================================

fn error_kind_from_http_status(status int) StorageErrorKind {
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

fn map_s3_error_code(error_code string, http_status int) StorageErrorKind {
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

fn map_aliyun_oss_error_code(error_code string, http_status int) StorageErrorKind {
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

fn map_tencent_cos_error_code(error_code string, http_status int) StorageErrorKind {
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
// XML 错误解析
// ============================================================================

fn extract_error_code_from_xml(body string) string {
	if code_start := body.index('<Code>') {
		if code_end := body.index('</Code>') {
			return body[code_start + 6..code_end]
		}
	}
	return ''
}

fn extract_error_message_from_xml(body string) string {
	if message_start := body.index('<Message>') {
		if message_end := body.index('</Message>') {
			return body[message_start + 9..message_end]
		}
	}
	return ''
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
	println('\n=== Error Classification 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// 生成随机字符串
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

// 生成随机提供者名称
fn generate_random_provider() string {
	providers := ['local', 's3', 'aliyun_oss', 'tencent_cos']
	idx := rand.int_in_range(0, providers.len) or { 0 }
	return providers[idx]
}

// 生成随机操作名称
fn generate_random_operation() string {
	operations := ['upload', 'download', 'delete', 'exists', 'head', 'list', 'copy', 'presign_url']
	idx := rand.int_in_range(0, operations.len) or { 0 }
	return operations[idx]
}


// ============================================================================
// Property 8.1: Retryable Error Classification
// For any error of type network_timeout, service_unavailable, rate_limited,
// connection_reset, or temporary_failure, is_retryable() should return true
// ============================================================================
fn test_property_8_1_retryable_errors() bool {
	retryable_kinds := [
		StorageErrorKind.network_timeout,
		StorageErrorKind.service_unavailable,
		StorageErrorKind.rate_limited,
		StorageErrorKind.connection_reset,
		StorageErrorKind.temporary_failure,
	]

	for _ in 0 .. test_iterations {
		// Pick a random retryable error kind
		idx := rand.int_in_range(0, retryable_kinds.len) or { 0 }
		kind := retryable_kinds[idx]

		// Create error with random provider and operation
		provider := generate_random_provider()
		operation := generate_random_operation()
		message := generate_random_string(10, 50)

		err := new_storage_error(kind, message, provider, operation)

		// Verify is_retryable returns true
		if !err.is_retryable() {
			println('  Failed: Error kind ${kind} should be retryable but is_retryable() returned false')
			return false
		}

		// Verify category is 'retryable'
		if err.category() != 'retryable' {
			println('  Failed: Error kind ${kind} should have category "retryable" but got "${err.category()}"')
			return false
		}
	}
	return true
}

// ============================================================================
// Property 8.2: Non-Retryable Error Classification
// For any error of type invalid_credentials, access_denied, bucket_not_found,
// object_not_found, invalid_object_key, quota_exceeded, invalid_config,
// is_retryable() should return false
// ============================================================================
fn test_property_8_2_non_retryable_errors() bool {
	non_retryable_kinds := [
		StorageErrorKind.invalid_credentials,
		StorageErrorKind.access_denied,
		StorageErrorKind.bucket_not_found,
		StorageErrorKind.object_not_found,
		StorageErrorKind.invalid_object_key,
		StorageErrorKind.quota_exceeded,
		StorageErrorKind.invalid_config,
		StorageErrorKind.bucket_not_empty,
		StorageErrorKind.bucket_already_exists,
		StorageErrorKind.object_already_exists,
		StorageErrorKind.invalid_range,
		StorageErrorKind.checksum_mismatch,
		StorageErrorKind.unknown,
	]

	for _ in 0 .. test_iterations {
		// Pick a random non-retryable error kind
		idx := rand.int_in_range(0, non_retryable_kinds.len) or { 0 }
		kind := non_retryable_kinds[idx]

		// Create error with random provider and operation
		provider := generate_random_provider()
		operation := generate_random_operation()
		message := generate_random_string(10, 50)

		err := new_storage_error(kind, message, provider, operation)

		// Verify is_retryable returns false
		if err.is_retryable() {
			println('  Failed: Error kind ${kind} should NOT be retryable but is_retryable() returned true')
			return false
		}

		// Verify category is 'non_retryable'
		if err.category() != 'non_retryable' {
			println('  Failed: Error kind ${kind} should have category "non_retryable" but got "${err.category()}"')
			return false
		}
	}
	return true
}


// ============================================================================
// Property 8.3: HTTP Status Code Mapping
// For any HTTP status code, error_kind_from_http_status should return
// the correct error kind
// ============================================================================
fn test_property_8_3_http_status_mapping() bool {
	// Define expected mappings
	status_mappings := {
		400: StorageErrorKind.invalid_object_key
		401: StorageErrorKind.invalid_credentials
		403: StorageErrorKind.access_denied
		404: StorageErrorKind.object_not_found
		409: StorageErrorKind.bucket_already_exists
		413: StorageErrorKind.quota_exceeded
		416: StorageErrorKind.invalid_range
		429: StorageErrorKind.rate_limited
		500: StorageErrorKind.service_unavailable
		502: StorageErrorKind.service_unavailable
		503: StorageErrorKind.service_unavailable
		504: StorageErrorKind.network_timeout
	}

	for status, expected_kind in status_mappings {
		actual_kind := error_kind_from_http_status(status)
		if actual_kind != expected_kind {
			println('  Failed: HTTP status ${status} should map to ${expected_kind} but got ${actual_kind}')
			return false
		}
	}

	// Test unknown status codes
	unknown_statuses := [200, 201, 204, 301, 302, 418, 451]
	for status in unknown_statuses {
		kind := error_kind_from_http_status(status)
		if kind != StorageErrorKind.unknown {
			println('  Failed: HTTP status ${status} should map to unknown but got ${kind}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 8.4: S3 Error Code Mapping
// For any S3 error code, map_s3_error_code should return the correct error kind
// ============================================================================
fn test_property_8_4_s3_error_code_mapping() bool {
	// Define expected mappings for S3 error codes
	s3_mappings := {
		'AccessDenied':             StorageErrorKind.access_denied
		'InvalidAccessKeyId':       StorageErrorKind.invalid_credentials
		'NoSuchBucket':             StorageErrorKind.bucket_not_found
		'NoSuchKey':                StorageErrorKind.object_not_found
		'BucketAlreadyExists':      StorageErrorKind.bucket_already_exists
		'BucketNotEmpty':           StorageErrorKind.bucket_not_empty
		'RequestTimeout':           StorageErrorKind.network_timeout
		'ServiceUnavailable':       StorageErrorKind.service_unavailable
		'SlowDown':                 StorageErrorKind.rate_limited
		'InvalidRange':             StorageErrorKind.invalid_range
		'SignatureDoesNotMatch':    StorageErrorKind.invalid_credentials
	}

	for error_code, expected_kind in s3_mappings {
		actual_kind := map_s3_error_code(error_code, 0)
		if actual_kind != expected_kind {
			println('  Failed: S3 error code "${error_code}" should map to ${expected_kind} but got ${actual_kind}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 8.5: Aliyun OSS Error Code Mapping
// For any Aliyun OSS error code, map_aliyun_oss_error_code should return
// the correct error kind
// ============================================================================
fn test_property_8_5_aliyun_oss_error_code_mapping() bool {
	// Define expected mappings for Aliyun OSS error codes
	oss_mappings := {
		'AccessDenied':             StorageErrorKind.access_denied
		'InvalidAccessKeyId':       StorageErrorKind.invalid_credentials
		'NoSuchBucket':             StorageErrorKind.bucket_not_found
		'NoSuchKey':                StorageErrorKind.object_not_found
		'BucketAlreadyExists':      StorageErrorKind.bucket_already_exists
		'BucketNotEmpty':           StorageErrorKind.bucket_not_empty
		'RequestTimeout':           StorageErrorKind.network_timeout
		'ServiceUnavailable':       StorageErrorKind.service_unavailable
		'InvalidRange':             StorageErrorKind.invalid_range
		'InvalidDigest':            StorageErrorKind.checksum_mismatch
		'SignatureDoesNotMatch':    StorageErrorKind.invalid_credentials
		'EntityTooLarge':           StorageErrorKind.quota_exceeded
	}

	for error_code, expected_kind in oss_mappings {
		actual_kind := map_aliyun_oss_error_code(error_code, 0)
		if actual_kind != expected_kind {
			println('  Failed: Aliyun OSS error code "${error_code}" should map to ${expected_kind} but got ${actual_kind}')
			return false
		}
	}

	return true
}


// ============================================================================
// Property 8.6: Tencent COS Error Code Mapping
// For any Tencent COS error code, map_tencent_cos_error_code should return
// the correct error kind
// ============================================================================
fn test_property_8_6_tencent_cos_error_code_mapping() bool {
	// Define expected mappings for Tencent COS error codes
	cos_mappings := {
		'AccessDenied':             StorageErrorKind.access_denied
		'InvalidAccessKeyId':       StorageErrorKind.invalid_credentials
		'NoSuchBucket':             StorageErrorKind.bucket_not_found
		'NoSuchKey':                StorageErrorKind.object_not_found
		'BucketAlreadyExists':      StorageErrorKind.bucket_already_exists
		'BucketNotEmpty':           StorageErrorKind.bucket_not_empty
		'RequestTimeout':           StorageErrorKind.network_timeout
		'ServiceUnavailable':       StorageErrorKind.service_unavailable
		'SlowDown':                 StorageErrorKind.rate_limited
		'InvalidRange':             StorageErrorKind.invalid_range
		'InvalidDigest':            StorageErrorKind.checksum_mismatch
		'SignatureDoesNotMatch':    StorageErrorKind.invalid_credentials
		'EntityTooLarge':           StorageErrorKind.quota_exceeded
	}

	for error_code, expected_kind in cos_mappings {
		actual_kind := map_tencent_cos_error_code(error_code, 0)
		if actual_kind != expected_kind {
			println('  Failed: Tencent COS error code "${error_code}" should map to ${expected_kind} but got ${actual_kind}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 8.7: Error Message Contains Required Information
// For any storage error, the error message should contain provider, operation,
// and error kind information
// ============================================================================
fn test_property_8_7_error_message_format() bool {
	all_kinds := [
		StorageErrorKind.network_timeout,
		StorageErrorKind.service_unavailable,
		StorageErrorKind.rate_limited,
		StorageErrorKind.connection_reset,
		StorageErrorKind.temporary_failure,
		StorageErrorKind.invalid_credentials,
		StorageErrorKind.access_denied,
		StorageErrorKind.bucket_not_found,
		StorageErrorKind.object_not_found,
		StorageErrorKind.invalid_object_key,
		StorageErrorKind.quota_exceeded,
		StorageErrorKind.invalid_config,
	]

	for _ in 0 .. test_iterations {
		// Pick a random error kind
		idx := rand.int_in_range(0, all_kinds.len) or { 0 }
		kind := all_kinds[idx]

		provider := generate_random_provider()
		operation := generate_random_operation()
		message := generate_random_string(10, 50)

		err := new_storage_error(kind, message, provider, operation)
		error_msg := err.msg()

		// Verify error message contains provider
		if !error_msg.contains(provider) {
			println('  Failed: Error message should contain provider "${provider}" but got: ${error_msg}')
			return false
		}

		// Verify error message contains operation
		if !error_msg.contains(operation) {
			println('  Failed: Error message should contain operation "${operation}" but got: ${error_msg}')
			return false
		}

		// Verify error message contains kind
		if !error_msg.contains('kind:') {
			println('  Failed: Error message should contain "kind:" but got: ${error_msg}')
			return false
		}
	}
	return true
}


// ============================================================================
// Property 8.8: Suggested Retry Delay for Retryable Errors
// For any retryable error, suggested_retry_delay should return a positive value
// ============================================================================
fn test_property_8_8_suggested_retry_delay() bool {
	retryable_kinds := [
		StorageErrorKind.network_timeout,
		StorageErrorKind.service_unavailable,
		StorageErrorKind.rate_limited,
		StorageErrorKind.connection_reset,
		StorageErrorKind.temporary_failure,
	]

	for _ in 0 .. test_iterations {
		// Pick a random retryable error kind
		idx := rand.int_in_range(0, retryable_kinds.len) or { 0 }
		kind := retryable_kinds[idx]

		provider := generate_random_provider()
		operation := generate_random_operation()
		message := generate_random_string(10, 50)

		err := new_storage_error(kind, message, provider, operation)
		delay := err.suggested_retry_delay()

		// Verify delay is positive for retryable errors
		if delay <= 0 {
			println('  Failed: Retryable error kind ${kind} should have positive suggested_retry_delay but got ${delay}')
			return false
		}
	}

	// Verify non-retryable errors have zero delay
	non_retryable_kinds := [
		StorageErrorKind.invalid_credentials,
		StorageErrorKind.access_denied,
		StorageErrorKind.object_not_found,
	]

	for kind in non_retryable_kinds {
		err := new_storage_error(kind, 'test', 'test', 'test')
		delay := err.suggested_retry_delay()

		if delay != 0 {
			println('  Failed: Non-retryable error kind ${kind} should have zero suggested_retry_delay but got ${delay}')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 8.9: XML Error Code Extraction
// For any XML error response, extract_error_code_from_xml should correctly
// extract the error code
// ============================================================================
fn test_property_8_9_xml_error_code_extraction() bool {
	for _ in 0 .. test_iterations {
		// Generate random error code
		error_code := generate_random_string(5, 20)
		error_message := generate_random_string(10, 50)

		// Create XML response
		xml_response := '<?xml version="1.0" encoding="UTF-8"?><Error><Code>${error_code}</Code><Message>${error_message}</Message></Error>'

		// Extract error code
		extracted_code := extract_error_code_from_xml(xml_response)

		if extracted_code != error_code {
			println('  Failed: Expected error code "${error_code}" but got "${extracted_code}"')
			return false
		}

		// Extract error message
		extracted_message := extract_error_message_from_xml(xml_response)

		if extracted_message != error_message {
			println('  Failed: Expected error message "${error_message}" but got "${extracted_message}"')
			return false
		}
	}

	// Test with empty/invalid XML
	empty_code := extract_error_code_from_xml('')
	if empty_code != '' {
		println('  Failed: Empty XML should return empty error code but got "${empty_code}"')
		return false
	}

	invalid_code := extract_error_code_from_xml('<Invalid>XML</Invalid>')
	if invalid_code != '' {
		println('  Failed: Invalid XML should return empty error code but got "${invalid_code}"')
		return false
	}

	return true
}


// ============================================================================
// Property 8.10: Retry History Tracking
// For any storage error, retry history should be correctly tracked
// ============================================================================
fn test_property_8_10_retry_history_tracking() bool {
	for _ in 0 .. test_iterations {
		provider := generate_random_provider()
		operation := generate_random_operation()
		message := generate_random_string(10, 50)

		mut err := new_storage_error(
			StorageErrorKind.network_timeout,
			message,
			provider,
			operation
		)

		// Initially, retry history should be empty
		if err.retry_history.len != 0 {
			println('  Failed: New error should have empty retry history')
			return false
		}

		// Add some retry attempts
		num_retries := rand.int_in_range(1, 5) or { 1 }
		for i in 0 .. num_retries {
			delay := rand.int_in_range(100, 5000) or { 1000 }
			err.add_retry_attempt(i + 1, 'Retry attempt ${i + 1}', delay)
		}

		// Verify retry history length
		if err.retry_history.len != num_retries {
			println('  Failed: Expected ${num_retries} retry attempts but got ${err.retry_history.len}')
			return false
		}

		// Verify retry summary is not empty
		summary := err.retry_summary()
		if summary == '' || summary == 'No retry attempts' {
			println('  Failed: Retry summary should not be empty after adding attempts')
			return false
		}

		// Verify each attempt is recorded correctly
		for i, attempt in err.retry_history {
			if attempt.attempt_number != i + 1 {
				println('  Failed: Attempt number mismatch at index ${i}')
				return false
			}
		}
	}

	return true
}

fn main() {
	println('🚀 开始 Error Classification 属性测试...')
	println('Feature: v-hono-upload-integration, Property 8: Error Classification')
	println('Validates: Requirements 9.4')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(54321)])

	mut stats := PropertyTestStats{}

	// Run property tests
	stats.run_property_test('Property 8.1: Retryable Error Classification', test_property_8_1_retryable_errors)
	stats.run_property_test('Property 8.2: Non-Retryable Error Classification', test_property_8_2_non_retryable_errors)
	stats.run_property_test('Property 8.3: HTTP Status Code Mapping', test_property_8_3_http_status_mapping)
	stats.run_property_test('Property 8.4: S3 Error Code Mapping', test_property_8_4_s3_error_code_mapping)
	stats.run_property_test('Property 8.5: Aliyun OSS Error Code Mapping', test_property_8_5_aliyun_oss_error_code_mapping)
	stats.run_property_test('Property 8.6: Tencent COS Error Code Mapping', test_property_8_6_tencent_cos_error_code_mapping)
	stats.run_property_test('Property 8.7: Error Message Contains Required Information', test_property_8_7_error_message_format)
	stats.run_property_test('Property 8.8: Suggested Retry Delay for Retryable Errors', test_property_8_8_suggested_retry_delay)
	stats.run_property_test('Property 8.9: XML Error Code Extraction', test_property_8_9_xml_error_code_extraction)
	stats.run_property_test('Property 8.10: Retry History Tracking', test_property_8_10_retry_history_tracking)

	// Print summary
	stats.print_summary()

	// Exit with error code if any tests failed
	if stats.failed_tests > 0 {
		exit(1)
	}
}
