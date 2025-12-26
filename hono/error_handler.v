module hono

import net.http
import json

// 错误类型枚举
pub enum ErrorType {
	bad_request = 400
	unauthorized = 401
	forbidden = 403
	not_found = 404
	method_not_allowed = 405
	conflict = 409
	payload_too_large = 413
	unsupported_media_type = 415
	unprocessable_entity = 422
	internal_server_error = 500
	not_implemented = 501
	bad_gateway = 502
	service_unavailable = 503
}

// 标准化错误响应结构
pub struct ErrorResponse {
pub:
	error       string
	message     string
	code        int
	timestamp   string
	path        string
	details     map[string]string
}

// 错误处理器接口
pub interface IErrorHandler {
	handle_error(mut c Context, error_type ErrorType, message string, details map[string]string) http.Response
}

// 默认错误处理器
pub struct DefaultErrorHandler {}

// 实现错误处理器接口
pub fn (eh DefaultErrorHandler) handle_error(mut c Context, error_type ErrorType, message string, details map[string]string) http.Response {
	error_response := ErrorResponse{
		error: get_error_name(error_type)
		message: message
		code: int(error_type)
		timestamp: get_current_timestamp()
		path: c.path
		details: details
	}
	
	c.status(int(error_type))
	return c.json(json.encode(error_response))
}

// 获取错误名称
fn get_error_name(error_type ErrorType) string {
	return match error_type {
		.bad_request { 'Bad Request' }
		.unauthorized { 'Unauthorized' }
		.forbidden { 'Forbidden' }
		.not_found { 'Not Found' }
		.method_not_allowed { 'Method Not Allowed' }
		.conflict { 'Conflict' }
		.payload_too_large { 'Payload Too Large' }
		.unsupported_media_type { 'Unsupported Media Type' }
		.unprocessable_entity { 'Unprocessable Entity' }
		.internal_server_error { 'Internal Server Error' }
		.not_implemented { 'Not Implemented' }
		.bad_gateway { 'Bad Gateway' }
		.service_unavailable { 'Service Unavailable' }
	}
}

// 获取当前时间戳
fn get_current_timestamp() string {
	// 简化的时间戳实现
	return '2025-12-26T00:00:00Z'
}

// Context 扩展方法 - 便捷的错误处理
pub fn (mut c Context) error_response(error_type ErrorType, message string) http.Response {
	return c.error_response_with_details(error_type, message, map[string]string{})
}

pub fn (mut c Context) error_response_with_details(error_type ErrorType, message string, details map[string]string) http.Response {
	handler := DefaultErrorHandler{}
	return handler.handle_error(mut c, error_type, message, details)
}

// 常用错误处理快捷方法
pub fn (mut c Context) bad_request(message string) http.Response {
	return c.error_response(.bad_request, message)
}

pub fn (mut c Context) unauthorized(message string) http.Response {
	return c.error_response(.unauthorized, message)
}

pub fn (mut c Context) forbidden(message string) http.Response {
	return c.error_response(.forbidden, message)
}

pub fn (mut c Context) not_found(message string) http.Response {
	return c.error_response(.not_found, message)
}

pub fn (mut c Context) internal_error(message string) http.Response {
	return c.error_response(.internal_server_error, message)
}

pub fn (mut c Context) validation_error(message string, field_errors map[string]string) http.Response {
	return c.error_response_with_details(.unprocessable_entity, message, field_errors)
}

// 参数验证错误处理
pub fn (mut c Context) missing_parameter(param_name string) http.Response {
	return c.bad_request('Missing required parameter: ${param_name}')
}

pub fn (mut c Context) invalid_parameter(param_name string, reason string) http.Response {
	details := {
		'parameter': param_name
		'reason': reason
	}
	return c.error_response_with_details(.bad_request, 'Invalid parameter: ${param_name}', details)
}

// 资源相关错误处理
pub fn (mut c Context) resource_not_found(resource_type string, resource_id string) http.Response {
	details := {
		'resource_type': resource_type
		'resource_id': resource_id
	}
	return c.error_response_with_details(.not_found, '${resource_type} not found', details)
}

pub fn (mut c Context) resource_conflict(resource_type string, reason string) http.Response {
	details := {
		'resource_type': resource_type
		'reason': reason
	}
	return c.error_response_with_details(.conflict, 'Resource conflict: ${reason}', details)
}

// 文件操作错误处理
pub fn (mut c Context) file_operation_error(operation string, filename string, reason string) http.Response {
	details := {
		'operation': operation
		'filename': filename
		'reason': reason
	}
	return c.error_response_with_details(.internal_server_error, 'File operation failed: ${operation}', details)
}

// 数据库操作错误处理
pub fn (mut c Context) database_error(operation string, reason string) http.Response {
	details := {
		'operation': operation
		'reason': reason
	}
	return c.error_response_with_details(.internal_server_error, 'Database operation failed', details)
}

// 验证结果处理
pub fn handle_validation_result[T](mut c Context, result !T, param_name string) !T {
	return result or {
		// 这里不能直接返回 http.Response，需要在调用处处理
		return error('Validation failed for ${param_name}: ${err}')
	}
}

// 全局错误处理中间件
pub fn error_handling_middleware() fn (mut Context, fn (mut Context) http.Response) http.Response {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 捕获 panic 并转换为错误响应
		// V语言目前不支持 try-catch，这里提供结构化的错误处理框架
		response := next(mut c)
		
		// 如果响应状态码是错误状态，确保响应格式一致
		if c.status_code >= 400 {
			// 如果响应体不是标准错误格式，转换为标准格式
			if !response.body.contains('"error"') {
				error_type := match c.status_code {
					400 { ErrorType.bad_request }
					401 { ErrorType.unauthorized }
					403 { ErrorType.forbidden }
					404 { ErrorType.not_found }
					409 { ErrorType.conflict }
					422 { ErrorType.unprocessable_entity }
					500 { ErrorType.internal_server_error }
					else { ErrorType.internal_server_error }
				}
				return c.error_response(error_type, response.body)
			}
		}
		
		return response
	}
}

// 错误日志记录
pub struct ErrorLogger {
mut:
	enabled bool = true
}

pub fn (mut logger ErrorLogger) log_error(error_response ErrorResponse, request_info string) {
	if !logger.enabled {
		return
	}
	
	println('[ERROR] ${error_response.timestamp} - ${error_response.code} ${error_response.error}')
	println('  Path: ${error_response.path}')
	println('  Message: ${error_response.message}')
	if error_response.details.len > 0 {
		println('  Details: ${error_response.details}')
	}
	println('  Request: ${request_info}')
}

// 创建错误日志实例
pub fn new_error_logger() ErrorLogger {
	return ErrorLogger{
		enabled: true
	}
}