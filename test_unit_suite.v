import hono
import os
import time
import strings

// 简化的测试统计
struct TestStats {
mut:
	total_tests int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) run_test(test_name string, test_func fn() bool) {
	stats.total_tests++
	print('🧪 ${test_name}... ')
	
	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats TestStats) print_summary() {
	println('\n=== 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')
	
	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// 1. 测试缓存系统
fn test_cache_system() bool {
	mut cache := hono.ContextLRUCache.new(3)
	
	// 测试基本操作
	test_route := hono.ContextRouteMatch{
		handler: 'test_handler'
		params: {'id': '123'}
	}
	
	cache.put('key1', test_route)
	
	// 验证获取
	if val := cache.get('key1') {
		if val.handler != 'test_handler' {
			return false
		}
	} else {
		return false
	}
	
	// 测试健康检查
	return cache.is_healthy()
}

// 2. 测试安全验证
fn test_security_validation() bool {
	// 测试危险路径
	dangerous_paths := [
		'../../../etc/passwd',
		'..\\..\\windows\\system32',
		'/etc/passwd',
		'C:\\Windows\\System32'
	]
	
	options := hono.PathValidationOptions{}
	
	for path in dangerous_paths {
		result := hono.validate_file_path(path, options)
		if result == '' {  // 空字符串表示验证失败，这是我们期望的
			continue
		} else {
			return false  // 危险路径应该被拒绝
		}
	}
	
	// 测试安全路径
	safe_path := 'documents/file.txt'
	result := hono.validate_file_path(safe_path, options)
	return result != ''  // 安全路径应该通过验证
}

// 3. 测试配置管理
fn test_config_management() bool {
	// 测试默认配置
	config := hono.default_config()
	
	if config.server.host != '127.0.0.1' {
		return false
	}
	
	if config.server.port != 8080 {
		return false
	}
	
	// 测试配置验证
	hono.validate_config(config) or {
		return false
	}
	
	return true
}

// 4. 测试日志系统
fn test_logging_system() bool {
	// 创建测试日志器
	config := hono.LoggerConfig{
		level: hono.LogLevel.debug
		output: hono.LogOutput.console
		enable_colors: false
	}
	
	mut logger := hono.new_logger(config)
	
	// 测试基本日志方法
	logger.info('测试信息日志')
	logger.warn('测试警告日志')
	logger.error('测试错误日志')
	
	// 测试日志级别转换
	if hono.parse_log_level('info') != hono.LogLevel.info {
		return false
	}
	
	if hono.log_level_to_string(hono.LogLevel.error) != 'ERROR' {
		return false
	}
	
	return true
}

// 5. 测试文件上传配置
fn test_upload_config() bool {
	config := hono.ChunkUploadConfig{
		upload_dir: './test_uploads'
		max_file_size: 1024 * 1024  // 1MB
		max_chunk_size: 1024        // 1KB
		merge_buffer_size: 512      // 512B
	}
	
	mut manager := hono.ChunkUploadManager.new(config)
	
	// 测试配置是否正确设置
	return manager.config.upload_dir == './test_uploads' &&
		   manager.config.max_file_size == 1024 * 1024 &&
		   manager.config.max_chunk_size == 1024
}

// 6. 测试字符串优化
fn test_string_optimization() bool {
	// 测试StringBuilder性能
	start_time := time.now()
	
	mut builder := strings.new_builder(1000)
	for i in 0 .. 100 {
		builder.write_string('test string ${i} ')
	}
	result := builder.str()
	
	duration := time.since(start_time)
	
	// 验证结果和性能
	return result.len > 0 && duration.milliseconds() < 100
}

// 7. 测试路由匹配
fn test_route_matching() bool {
	mut router := hono.Router.new()
	
	// 添加测试路由
	router.add_route('GET', '/users', 'get_users')
	router.add_route('GET', '/users/:id', 'get_user')
	
	// 测试静态路由匹配
	if route := router.match_route('GET', '/users') {
		if route.handler != 'get_users' {
			return false
		}
	} else {
		return false
	}
	
	// 测试动态路由匹配
	if route := router.match_route('GET', '/users/123') {
		if route.handler != 'get_user' {
			return false
		}
		if route.params['id'] != '123' {
			return false
		}
	} else {
		return false
	}
	
	return true
}

// 8. 测试内存管理
fn test_memory_management() bool {
	mut cache := hono.ContextLRUCache.new(5)
	
	// 填充缓存
	for i in 0 .. 10 {
		test_route := hono.ContextRouteMatch{
			handler: 'handler_${i}'
			params: {'id': '${i}'}
		}
		cache.put('key${i}', test_route)
	}
	
	// 验证大小限制
	size, capacity := cache.get_stats()
	if size > capacity {
		return false
	}
	
	// 清理缓存
	cache.clear()
	
	size_after, _ := cache.get_stats()
	if size_after != 0 {
		return false
	}
	
	// 验证健康状态
	return cache.is_healthy()
}

// 9. 测试错误处理结构
fn test_error_handling() bool {
	// 测试错误类型
	error_types := [
		hono.ErrorType.bad_request,
		hono.ErrorType.unauthorized,
		hono.ErrorType.forbidden,
		hono.ErrorType.not_found,
		hono.ErrorType.internal_server_error
	]
	
	// 验证错误代码
	expected_codes := [400, 401, 403, 404, 500]
	
	for i, error_type in error_types {
		if int(error_type) != expected_codes[i] {
			return false
		}
	}
	
	return true
}

// 10. 测试配置文件操作
fn test_config_file_operations() bool {
	config_path := './test_config.json'
	
	// 清理可能存在的测试文件
	if os.exists(config_path) {
		os.rm(config_path) or { return false }
	}
	
	// 创建和保存配置
	config := hono.default_config()
	hono.save_config(config, config_path) or {
		return false
	}
	
	// 加载配置
	loaded_config := hono.load_config(config_path) or {
		return false
	}
	
	// 验证配置内容
	success := loaded_config.server.host == config.server.host &&
			   loaded_config.server.port == config.server.port
	
	// 清理测试文件
	os.rm(config_path) or {}
	
	return success
}

fn main() {
	println('🚀 开始V-Hono单元测试套件...\n')
	
	mut stats := TestStats{}
	
	// 运行所有测试
	stats.run_test('缓存系统', test_cache_system)
	stats.run_test('安全验证', test_security_validation)
	stats.run_test('配置管理', test_config_management)
	stats.run_test('日志系统', test_logging_system)
	stats.run_test('上传配置', test_upload_config)
	stats.run_test('字符串优化', test_string_optimization)
	stats.run_test('路由匹配', test_route_matching)
	stats.run_test('内存管理', test_memory_management)
	stats.run_test('错误处理', test_error_handling)
	stats.run_test('配置文件操作', test_config_file_operations)
	
	// 打印测试总结
	stats.print_summary()
}