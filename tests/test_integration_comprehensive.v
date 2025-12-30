import hono
import time
import net.http
import os

fn main() {
	println('=== V-Hono 综合集成测试 ===')
	
	// 测试1: FastRouter集成测试
	test_fast_router_integration()
	
	// 测试2: 配置管理集成测试
	test_config_integration()
	
	// 测试3: 日志系统集成测试
	test_logger_integration()
	
	// 测试4: 错误处理集成测试
	test_error_handling_integration()
	
	// 测试5: 安全验证集成测试
	test_security_integration()
	
	// 测试6: 性能基准集成测试
	test_performance_integration()
	
	// 测试7: 内存管理集成测试
	test_memory_management_integration()
	
	println('✅ V-Hono 综合集成测试完成')
}

fn test_fast_router_integration() {
	println('\n📊 FastRouter集成测试...')
	
	// 创建应用实例
	mut app := hono.Hono.new()
	
	// 验证FastRouter默认启用
	if !app.use_fast_router {
		println('  ❌ FastRouter未默认启用')
		return
	}
	println('  ✅ FastRouter默认启用')
	
	// 添加各种类型的路由
	test_routes := [
		'/static/path',                                    // 静态路由
		'/users/:id',                                      // 单参数动态路由
		'/users/:id/posts/:post_id',                      // 多参数动态路由
		'/api/:version/users/:user_id/posts/:post_id',    // 复杂动态路由
		'/files/:year/:month/:day/:filename'              // 深层动态路由
	]
	
	for route in test_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
	}
	
	// 验证路由统计
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('  路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
	
	// 测试路由匹配
	test_paths := [
		'/static/path',
		'/users/123',
		'/users/123/posts/456',
		'/api/v1/users/789/posts/101',
		'/files/2023/12/26/document.pdf'
	]
	
	mut match_count := 0
	for path in test_paths {
		if _ := app.fast_router.match_route('GET', path) {
			match_count++
		}
	}
	
	if match_count == test_paths.len {
		println('  ✅ 所有路由匹配成功 (${match_count}/${test_paths.len})')
	} else {
		println('  ❌ 路由匹配失败 (${match_count}/${test_paths.len})')
	}
	
	// 测试FastRouter开关
	app.set_fast_router_enabled(false)
	if app.use_fast_router {
		println('  ❌ FastRouter开关失效')
	} else {
		println('  ✅ FastRouter开关正常')
	}
	
	app.set_fast_router_enabled(true)
	if !app.use_fast_router {
		println('  ❌ FastRouter重新启用失败')
	} else {
		println('  ✅ FastRouter重新启用成功')
	}
	
	// 性能分析
	println('  性能分析:')
	app.analyze_router_performance()
}

fn test_config_integration() {
	println('\n📊 配置管理集成测试...')
	
	// 测试默认配置
	config := hono.default_config()
	if config.server.host == '0.0.0.0' && config.server.port == 8080 {
		println('  ✅ 默认配置正确')
	} else {
		println('  ❌ 默认配置错误')
	}
	
	// 测试配置验证
	hono.validate_config(config) or {
		println('  ❌ 配置验证失败: ${err}')
		return
	}
	println('  ✅ 配置验证通过')
	
	// 测试配置保存和加载
	test_config_file := 'test_config.json'
	
	hono.save_config(config, test_config_file) or {
		println('  ❌ 配置保存失败: ${err}')
		return
	}
	println('  ✅ 配置保存成功')
	
	loaded_config := hono.load_config(test_config_file) or {
		println('  ❌ 配置加载失败: ${err}')
		return
	}
	println('  ✅ 配置加载成功')
	
	// 清理测试文件
	os.rm(test_config_file) or {}
	
	// 验证配置内容
	if loaded_config.server.host == config.server.host {
		println('  ✅ 配置内容一致')
	} else {
		println('  ❌ 配置内容不一致')
	}
}

fn test_logger_integration() {
	println('\n📊 日志系统集成测试...')
	
	// 创建日志器配置
	config := hono.LoggerConfig{
		level: .info
		output: .console
	}
	mut logger := hono.new_logger(config)
	
	// 测试各级别日志
	logger.debug('Debug message')
	logger.info('Info message')
	logger.warn('Warning message')
	logger.error('Error message')
	
	println('  ✅ 日志级别测试完成')
	
	// 测试带模块的日志
	logger.info_with_module('Module message', 'test_module')
	println('  ✅ 模块日志测试完成')
	
	// 测试带字段的日志
	fields := {
		'user_id': '123'
		'action': 'login'
	}
	logger.info_with_fields('User login', fields)
	println('  ✅ 结构化日志测试完成')
	
	// 测试带请求ID的日志
	logger.info_with_request('Request processed', 'req-12345')
	println('  ✅ 请求日志测试完成')
}

fn test_error_handling_integration() {
	println('\n📊 错误处理集成测试...')
	
	// 测试错误响应
	error_response_400 := hono.Response.error(400, 'Bad request test')
	if error_response_400.status_code == 400 {
		println('  ✅ 400 Bad Request 错误响应正确')
	} else {
		println('  ❌ 400 Bad Request 错误响应失败')
	}
	
	error_response_404 := hono.Response.error(404, 'Not found test')
	if error_response_404.status_code == 404 {
		println('  ✅ 404 Not Found 错误响应正确')
	} else {
		println('  ❌ 404 Not Found 错误响应失败')
	}
	
	error_response_500 := hono.Response.error(500, 'Internal error test')
	if error_response_500.status_code == 500 {
		println('  ✅ 500 Internal Error 错误响应正确')
	} else {
		println('  ❌ 500 Internal Error 错误响应失败')
	}
	
	println('  ✅ 错误处理方法测试通过')
}

fn test_security_integration() {
	println('\n📊 安全验证集成测试...')
	
	// 测试路径验证
	dangerous_paths := [
		'../../../etc/passwd',
		'..\\..\\windows\\system32',
		'/etc/passwd',
		'C:\\Windows\\System32',
		'file:///etc/passwd',
		'path/with/../../traversal',
		'path\\with\\..\\..\\traversal',
		'normal/path/with<script>alert(1)</script>'
	]
	
	mut blocked_count := 0
	for path in dangerous_paths {
		// validate_file_path returns !string, so error means blocked
		_ := hono.validate_file_path(path, hono.PathValidationOptions{}) or {
			blocked_count++
			continue
		}
	}
	
	if blocked_count == dangerous_paths.len {
		println('  ✅ 危险路径全部被阻止 (${blocked_count}/${dangerous_paths.len})')
	} else {
		println('  ⚠️  部分危险路径未被阻止 (${blocked_count}/${dangerous_paths.len})')
	}
	
	// 测试安全路径
	safe_paths := [
		'documents/report.pdf',
		'images/photo.jpg',
		'data/config.json'
	]
	
	mut safe_count := 0
	for path in safe_paths {
		if _ := hono.validate_file_path(path, hono.PathValidationOptions{}) {
			safe_count++
		}
	}
	
	if safe_count == safe_paths.len {
		println('  ✅ 安全路径全部通过 (${safe_count}/${safe_paths.len})')
	} else {
		println('  ❌ 部分安全路径被阻止 (${safe_count}/${safe_paths.len})')
	}
}

fn test_performance_integration() {
	println('\n📊 性能基准集成测试...')
	
	// 创建测试应用
	mut app := hono.Hono.new()
	
	// 添加多种路由
	performance_routes := [
		'/api/v1/users/:id',
		'/api/v1/users/:id/posts',
		'/api/v1/users/:id/posts/:post_id',
		'/api/v2/products/:category/:id',
		'/files/:year/:month/:day/:filename'
	]
	
	for route in performance_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
	}
	
	// 性能测试路径
	test_paths := [
		'/api/v1/users/123',
		'/api/v1/users/123/posts',
		'/api/v1/users/123/posts/456',
		'/api/v2/products/electronics/999',
		'/files/2023/12/26/document.pdf'
	]
	
	iterations := 1000
	
	// 测试FastRouter性能
	start_time := time.now()
	mut match_count := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				match_count++
			}
		}
	}
	total_time := time.since(start_time)
	
	avg_time := f64(total_time.microseconds()) / f64(match_count)
	println('  FastRouter性能: ${total_time} (${match_count}次匹配, 平均${avg_time:.3f}μs)')
	
	if avg_time < 20.0 {  // 期望平均时间小于20μs
		println('  ✅ 性能测试通过 (平均${avg_time:.3f}μs < 20μs)')
	} else {
		println('  ❌ 性能测试未达标 (平均${avg_time:.3f}μs >= 20μs)')
	}
}

fn test_memory_management_integration() {
	println('\n📊 内存管理集成测试...')
	
	// 测试LRU缓存
	mut cache := hono.ContextLRUCache.new(100)
	
	// 添加测试数据
	test_data := hono.ContextRouteMatch{
		handler: hono.ContextHandler{
			path: '/test'
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	// 测试缓存操作
	cache.put('test_key', test_data)
	
	if cached := cache.get('test_key') {
		println('  ✅ 缓存存储和获取正常')
	} else {
		println('  ❌ 缓存存储或获取失败')
	}
	
	// 测试缓存健康检查
	if cache.is_healthy() {
		println('  ✅ 缓存健康检查通过')
	} else {
		println('  ❌ 缓存健康检查失败')
	}
	
	// 测试缓存统计
	size, capacity := cache.get_stats()
	println('  缓存统计: 大小=${size}, 容量=${capacity}')
	
	// 测试缓存清理
	cache.clear()
	size_after_clear, _ := cache.get_stats()
	
	if size_after_clear == 0 {
		println('  ✅ 缓存清理成功')
	} else {
		println('  ❌ 缓存清理失败')
	}
}

// 创建模拟Context用于测试
fn create_mock_context() hono.Context {
	req := http.Request{
		method: http.Method.get
		url: '/test'
		data: ''
	}
	
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}