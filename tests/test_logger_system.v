import hono
import os
import time

fn test_logger_creation() {
	println('=== 测试日志器创建 ===')
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.debug
		output: hono.LogOutput.console
		enable_colors: true
	}
	
	logger := hono.new_logger(config)
	assert logger.config.level == hono.LogLevel.debug
	assert logger.config.output == hono.LogOutput.console
	
	println('✅ 日志器创建测试通过')
}

fn test_log_levels() {
	println('=== 测试日志级别 ===')
	
	// 测试字符串转日志级别
	assert hono.parse_log_level('debug') == hono.LogLevel.debug
	assert hono.parse_log_level('info') == hono.LogLevel.info
	assert hono.parse_log_level('warn') == hono.LogLevel.warn
	assert hono.parse_log_level('error') == hono.LogLevel.error
	assert hono.parse_log_level('invalid') == hono.LogLevel.info  // 默认值
	
	// 测试日志级别转字符串
	assert hono.log_level_to_string(hono.LogLevel.debug) == 'DEBUG'
	assert hono.log_level_to_string(hono.LogLevel.info) == 'INFO'
	assert hono.log_level_to_string(hono.LogLevel.warn) == 'WARN'
	assert hono.log_level_to_string(hono.LogLevel.error) == 'ERROR'
	
	println('✅ 日志级别测试通过')
}

fn test_console_logging() {
	println('=== 测试控制台日志输出 ===')
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.debug
		output: hono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := hono.new_logger(config)
	
	// 测试基本日志方法
	logger.debug('这是一条调试消息')
	logger.info('这是一条信息消息')
	logger.warn('这是一条警告消息')
	logger.error('这是一条错误消息')
	
	// 测试带模块的日志
	logger.info_with_module('模块信息消息', 'TEST')
	
	// 测试带字段的日志
	fields := {
		'user_id': '12345'
		'action': 'login'
		'ip': '192.168.1.1'
	}
	logger.info_with_fields('用户登录', fields)
	
	// 测试带请求ID的日志
	logger.info_with_request('处理请求', 'req-123456')
	
	println('✅ 控制台日志输出测试通过')
}

fn test_file_logging() {
	println('=== 测试文件日志输出 ===')
	
	log_file := './test_log.log'
	
	// 清理可能存在的测试文件
	if os.exists(log_file) {
		os.rm(log_file) or {}
	}
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.info
		output: hono.LogOutput.file
		file_path: log_file
		enable_colors: false  // 文件输出不需要颜色
	}
	
	mut logger := hono.new_logger(config)
	
	// 写入一些日志
	logger.info('测试文件日志 1')
	logger.warn('测试文件日志 2')
	logger.error('测试文件日志 3')
	
	// 等待一下确保文件写入完成
	time.sleep(100 * time.millisecond)
	
	// 验证文件是否存在且有内容
	assert os.exists(log_file)
	
	content := os.read_file(log_file) or {
		panic('无法读取日志文件: ${err}')
	}
	
	assert content.contains('测试文件日志 1')
	assert content.contains('测试文件日志 2')
	assert content.contains('测试文件日志 3')
	assert content.contains('INFO')
	assert content.contains('WARN')
	assert content.contains('ERROR')
	
	// 清理测试文件
	os.rm(log_file) or {}
	
	println('✅ 文件日志输出测试通过')
}

fn test_json_logging() {
	println('=== 测试JSON格式日志 ===')
	
	log_file := './test_json_log.log'
	
	// 清理可能存在的测试文件
	if os.exists(log_file) {
		os.rm(log_file) or {}
	}
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.info
		output: hono.LogOutput.file
		file_path: log_file
		enable_json: true
	}
	
	mut logger := hono.new_logger(config)
	
	// 写入JSON格式日志
	fields := {
		'user_id': '12345'
		'action': 'test'
	}
	logger.info_with_fields('JSON日志测试', fields)
	
	// 等待文件写入
	time.sleep(100 * time.millisecond)
	
	// 验证JSON格式
	assert os.exists(log_file)
	content := os.read_file(log_file) or {
		panic('无法读取JSON日志文件: ${err}')
	}
	
	assert content.contains('"level":"INFO"')
	assert content.contains('"message":"JSON日志测试"')
	assert content.contains('"user_id":"12345"')
	
	// 清理测试文件
	os.rm(log_file) or {}
	
	println('✅ JSON格式日志测试通过')
}

fn test_global_logger() {
	println('=== 测试全局日志器 ===')
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.info
		output: hono.LogOutput.console
		enable_colors: true
	}
	
	// 创建日志器实例
	mut logger := hono.new_logger(config)
	
	// 使用日志器方法
	logger.info('日志器信息消息')
	logger.warn('日志器警告消息')
	logger.error('日志器错误消息')
	
	println('✅ 全局日志器测试通过')
}

fn test_request_logging() {
	println('=== 测试HTTP请求日志 ===')
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.info
		output: hono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := hono.new_logger(config)
	
	req_log := hono.RequestLog{
		method: 'GET'
		path: '/api/users'
		status_code: 200
		response_time: 45.67
		user_agent: 'Mozilla/5.0'
		remote_addr: '192.168.1.100'
		request_size: 1024
		response_size: 2048
		request_id: 'req-789'
	}
	
	hono.log_request(mut logger, req_log)
	
	println('✅ HTTP请求日志测试通过')
}

fn test_performance_logging() {
	println('=== 测试性能监控日志 ===')
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.info
		output: hono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := hono.new_logger(config)
	
	details := {
		'cache_hit': 'true'
		'db_queries': '3'
		'memory_usage': '45MB'
	}
	
	hono.log_performance(mut logger, '数据库查询', 123.45, details)
	
	println('✅ 性能监控日志测试通过')
}

fn test_error_logging() {
	println('=== 测试错误日志 ===')
	
	config := hono.LoggerConfig{
		level: hono.LogLevel.error
		output: hono.LogOutput.console
		enable_colors: true
	}
	
	mut logger := hono.new_logger(config)
	
	hono.log_error_with_stack(mut logger, '数据库连接失败', '连接超时: 5秒', 'DATABASE')
	
	println('✅ 错误日志测试通过')
}

fn main() {
	println('开始日志系统测试...\n')
	
	test_logger_creation()
	println('')
	
	test_log_levels()
	println('')
	
	test_console_logging()
	println('')
	
	test_file_logging()
	println('')
	
	test_json_logging()
	println('')
	
	test_global_logger()
	println('')
	
	test_request_logging()
	println('')
	
	test_performance_logging()
	println('')
	
	test_error_logging()
	println('')
	
	println('🎉 所有日志系统测试通过！')
}