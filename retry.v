module hono

import time
import rand
import math

// ============================================================================
// 重试配置
// ============================================================================

// 重试配置结构
pub struct RetryConfig {
pub:
	max_retries     int  = 3      // 最大重试次数
	initial_delay   int  = 1000   // 初始延迟（毫秒）
	max_delay       int  = 30000  // 最大延迟（毫秒）
	multiplier      f64  = 2.0    // 延迟倍增因子
	jitter          bool = true   // 是否添加随机抖动
	jitter_factor   f64  = 0.25   // 抖动因子 (0.0 - 1.0)
}

// 默认重试配置
pub fn default_retry_config() RetryConfig {
	return RetryConfig{
		max_retries: 3
		initial_delay: 1000
		max_delay: 30000
		multiplier: 2.0
		jitter: true
		jitter_factor: 0.25
	}
}

// 激进重试配置（更多重试，更短延迟）
pub fn aggressive_retry_config() RetryConfig {
	return RetryConfig{
		max_retries: 5
		initial_delay: 500
		max_delay: 10000
		multiplier: 1.5
		jitter: true
		jitter_factor: 0.2
	}
}

// 保守重试配置（更少重试，更长延迟）
pub fn conservative_retry_config() RetryConfig {
	return RetryConfig{
		max_retries: 2
		initial_delay: 2000
		max_delay: 60000
		multiplier: 3.0
		jitter: true
		jitter_factor: 0.3
	}
}


// ============================================================================
// 重试结果
// ============================================================================

// 重试执行结果
pub struct RetryResult[T] {
pub:
	success       bool
	value         T
	total_retries int
	total_delay   int  // 总延迟时间（毫秒）
	final_error   StorageError
	history       []RetryAttempt
}

// 创建成功的重试结果
fn new_retry_success[T](value T, total_retries int, total_delay int, history []RetryAttempt) RetryResult[T] {
	return RetryResult[T]{
		success: true
		value: value
		total_retries: total_retries
		total_delay: total_delay
		final_error: StorageError{}
		history: history
	}
}

// 创建失败的重试结果
fn new_retry_failure[T](final_error StorageError, total_retries int, total_delay int, history []RetryAttempt) RetryResult[T] {
	return RetryResult[T]{
		success: false
		value: T{}
		total_retries: total_retries
		total_delay: total_delay
		final_error: final_error
		history: history
	}
}

// ============================================================================
// 重试执行器
// ============================================================================

// 重试执行器
pub struct RetryExecutor {
	config RetryConfig
}

// 创建重试执行器
pub fn new_retry_executor(config RetryConfig) RetryExecutor {
	return RetryExecutor{
		config: config
	}
}

// 使用默认配置创建重试执行器
pub fn new_default_retry_executor() RetryExecutor {
	return RetryExecutor{
		config: default_retry_config()
	}
}

// 计算下一次重试的延迟时间
pub fn (r RetryExecutor) calculate_delay(attempt int) int {
	// 指数退避: delay = initial_delay * (multiplier ^ attempt)
	base_delay := f64(r.config.initial_delay) * math.pow(r.config.multiplier, f64(attempt))
	
	// 限制最大延迟
	mut delay := int(math.min(base_delay, f64(r.config.max_delay)))
	
	// 添加随机抖动
	if r.config.jitter && delay > 0 {
		jitter_range := int(f64(delay) * r.config.jitter_factor)
		if jitter_range > 0 {
			jitter := rand.int_in_range(0, jitter_range * 2) or { 0 }
			delay = delay - jitter_range + jitter
		}
	}
	
	// 确保延迟不为负
	if delay < 0 {
		delay = 0
	}
	
	return delay
}


// 执行带重试的操作（返回 []u8）
pub fn (r RetryExecutor) execute_bytes(operation fn () ![]u8, provider string, op_name string) RetryResult[[]u8] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// 执行操作
		result := operation() or {
			// 解析错误
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// 检查是否可重试
			if !storage_err.is_retryable() {
				// 不可重试错误，立即返回
				return new_retry_failure[[]u8](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// 如果还有重试机会
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// 记录重试尝试
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// 等待后重试
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// 操作成功
		return new_retry_success[[]u8](result, attempt, total_delay, history)
	}
	
	// 所有重试都失败
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[[]u8](final_error, r.config.max_retries, total_delay, history)
}

// 执行带重试的操作（返回 StorageResult）
pub fn (r RetryExecutor) execute_storage_result(operation fn () !StorageResult, provider string, op_name string) RetryResult[StorageResult] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// 执行操作
		result := operation() or {
			// 解析错误
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// 检查是否可重试
			if !storage_err.is_retryable() {
				// 不可重试错误，立即返回
				return new_retry_failure[StorageResult](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// 如果还有重试机会
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// 记录重试尝试
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// 等待后重试
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// 操作成功
		return new_retry_success[StorageResult](result, attempt, total_delay, history)
	}
	
	// 所有重试都失败
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[StorageResult](final_error, r.config.max_retries, total_delay, history)
}


// 执行带重试的操作（返回 bool）
pub fn (r RetryExecutor) execute_bool(operation fn () !bool, provider string, op_name string) RetryResult[bool] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// 执行操作
		result := operation() or {
			// 解析错误
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// 检查是否可重试
			if !storage_err.is_retryable() {
				// 不可重试错误，立即返回
				return new_retry_failure[bool](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// 如果还有重试机会
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// 记录重试尝试
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// 等待后重试
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// 操作成功
		return new_retry_success[bool](result, attempt, total_delay, history)
	}
	
	// 所有重试都失败
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[bool](final_error, r.config.max_retries, total_delay, history)
}

// 执行带重试的操作（无返回值）
pub fn (r RetryExecutor) execute_void(operation fn () !, provider string, op_name string) RetryResult[bool] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// 执行操作
		operation() or {
			// 解析错误
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// 检查是否可重试
			if !storage_err.is_retryable() {
				// 不可重试错误，立即返回
				return new_retry_failure[bool](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// 如果还有重试机会
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// 记录重试尝试
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// 等待后重试
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// 操作成功
		return new_retry_success[bool](true, attempt, total_delay, history)
	}
	
	// 所有重试都失败
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[bool](final_error, r.config.max_retries, total_delay, history)
}


// 执行带重试的操作（返回 string）
pub fn (r RetryExecutor) execute_string(operation fn () !string, provider string, op_name string) RetryResult[string] {
	mut history := []RetryAttempt{}
	mut total_delay := 0
	mut last_error := StorageError{}
	
	for attempt in 0 .. r.config.max_retries + 1 {
		// 执行操作
		result := operation() or {
			// 解析错误
			error_msg := err.msg()
			storage_err := parse_error_message(error_msg, provider, op_name)
			
			// 检查是否可重试
			if !storage_err.is_retryable() {
				// 不可重试错误，立即返回
				return new_retry_failure[string](storage_err, attempt, total_delay, history)
			}
			
			last_error = storage_err
			
			// 如果还有重试机会
			if attempt < r.config.max_retries {
				delay := r.calculate_delay(attempt)
				
				// 记录重试尝试
				history << RetryAttempt{
					attempt_number: attempt + 1
					timestamp: time.now().unix()
					error_message: error_msg
					delay_ms: delay
				}
				
				total_delay += delay
				
				// 等待后重试
				if delay > 0 {
					time.sleep(delay * time.millisecond)
				}
			}
			continue
		}
		
		// 操作成功
		return new_retry_success[string](result, attempt, total_delay, history)
	}
	
	// 所有重试都失败
	mut final_error := last_error
	final_error.retry_history = history
	return new_retry_failure[string](final_error, r.config.max_retries, total_delay, history)
}

// ============================================================================
// 辅助函数
// ============================================================================

// 从错误消息解析 StorageError
fn parse_error_message(error_msg string, provider string, operation string) StorageError {
	// 尝试从错误消息中提取信息
	// 格式: "provider/operation: message (kind: xxx, http_status: yyy)"
	
	// 检查是否包含已知的错误类型关键字
	kind := detect_error_kind_from_message(error_msg)
	
	// 尝试提取 HTTP 状态码
	http_status := extract_http_status_from_message(error_msg)
	
	return StorageError{
		kind: kind
		message: error_msg
		provider: provider
		operation: operation
		http_status: http_status
		retry_count: 0
		details: map[string]string{}
		retry_history: []RetryAttempt{}
	}
}

// 从错误消息检测错误类型
fn detect_error_kind_from_message(msg string) StorageErrorKind {
	lower_msg := msg.to_lower()
	
	// 可重试错误
	if lower_msg.contains('timeout') || lower_msg.contains('timed out') {
		return .network_timeout
	}
	if lower_msg.contains('service unavailable') || lower_msg.contains('503') {
		return .service_unavailable
	}
	if lower_msg.contains('rate limit') || lower_msg.contains('too many requests') || lower_msg.contains('429') {
		return .rate_limited
	}
	if lower_msg.contains('connection reset') || lower_msg.contains('connection refused') {
		return .connection_reset
	}
	if lower_msg.contains('temporary') || lower_msg.contains('retry') {
		return .temporary_failure
	}
	
	// 不可重试错误
	if lower_msg.contains('invalid credentials') || lower_msg.contains('401') || lower_msg.contains('unauthorized') {
		return .invalid_credentials
	}
	if lower_msg.contains('access denied') || lower_msg.contains('403') || lower_msg.contains('forbidden') {
		return .access_denied
	}
	if lower_msg.contains('bucket not found') || lower_msg.contains('nosuchbucket') {
		return .bucket_not_found
	}
	if lower_msg.contains('not found') || lower_msg.contains('404') || lower_msg.contains('nosuchkey') {
		return .object_not_found
	}
	if lower_msg.contains('invalid') && (lower_msg.contains('key') || lower_msg.contains('name')) {
		return .invalid_object_key
	}
	if lower_msg.contains('quota') || lower_msg.contains('limit exceeded') {
		return .quota_exceeded
	}
	if lower_msg.contains('config') {
		return .invalid_config
	}
	
	return .unknown
}

// 从错误消息提取 HTTP 状态码
fn extract_http_status_from_message(msg string) int {
	// 尝试查找 "http_status: xxx" 模式
	if status_idx := msg.index('http_status:') {
		start := status_idx + 12
		mut end := start
		for end < msg.len && (msg[end].is_digit() || msg[end] == ` `) {
			end++
		}
		status_str := msg[start..end].trim_space()
		return status_str.int()
	}
	
	// 尝试查找常见的 HTTP 状态码
	status_codes := [400, 401, 403, 404, 409, 413, 429, 500, 502, 503, 504]
	for code in status_codes {
		if msg.contains(code.str()) {
			return code
		}
	}
	
	return 0
}


// ============================================================================
// 简化的重试函数
// ============================================================================

// 使用默认配置执行带重试的操作（返回 []u8）
pub fn retry_bytes(operation fn () ![]u8, provider string, op_name string) RetryResult[[]u8] {
	executor := new_default_retry_executor()
	return executor.execute_bytes(operation, provider, op_name)
}

// 使用默认配置执行带重试的操作（返回 StorageResult）
pub fn retry_storage_result(operation fn () !StorageResult, provider string, op_name string) RetryResult[StorageResult] {
	executor := new_default_retry_executor()
	return executor.execute_storage_result(operation, provider, op_name)
}

// 使用默认配置执行带重试的操作（返回 bool）
pub fn retry_bool(operation fn () !bool, provider string, op_name string) RetryResult[bool] {
	executor := new_default_retry_executor()
	return executor.execute_bool(operation, provider, op_name)
}

// 使用默认配置执行带重试的操作（无返回值）
pub fn retry_void(operation fn () !, provider string, op_name string) RetryResult[bool] {
	executor := new_default_retry_executor()
	return executor.execute_void(operation, provider, op_name)
}

// 使用默认配置执行带重试的操作（返回 string）
pub fn retry_string(operation fn () !string, provider string, op_name string) RetryResult[string] {
	executor := new_default_retry_executor()
	return executor.execute_string(operation, provider, op_name)
}

// 使用自定义配置执行带重试的操作（返回 []u8）
pub fn retry_bytes_with_config(operation fn () ![]u8, provider string, op_name string, config RetryConfig) RetryResult[[]u8] {
	executor := new_retry_executor(config)
	return executor.execute_bytes(operation, provider, op_name)
}

// 使用自定义配置执行带重试的操作（返回 StorageResult）
pub fn retry_storage_result_with_config(operation fn () !StorageResult, provider string, op_name string, config RetryConfig) RetryResult[StorageResult] {
	executor := new_retry_executor(config)
	return executor.execute_storage_result(operation, provider, op_name)
}
