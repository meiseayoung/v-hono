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
	config := hono.AppConfig.default()
	if config.server.host == '0.0.0.0' && config.server.port == 8080 {
		println('  ✅ 默认配置正确')
	} else {
		println('  ❌ 默认配置错误')
	}
	
	// 测试配置验证
	if config.validate() {
		println('  ✅ 配置验证通过')
	} else {
		println('  ❌ 配置验证失败')
	}
	
	// 测试配置保存和加载
	test_config_file := 'test_config.json'
	
	config.save_to_file(test_config_file) or {
		println('  ❌ 配置保存失败: ${err}')
		return
	}
	println('  ✅ 配置保存成功')
	
	loaded_config := hono.AppConfig.load_from_file(test_config_file) or {
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
	
	// 创建日志器
	mut logger := hono.Logger.new(hono.LogLevel.info, hono.LogOutput.console, hono.LogFormat.text)
	
	// 测试各级别日志
	logger.debug('Debug message', 'test')
	logger.info('Info message', 'test')
	logger.warn('Warning message', 'test')
	logger.error('Error message', 'test')
	
	println('  ✅ 日志级别测试完成')
	
	// 测试结构化日志
	fields := {
		'user_id': '123'
		'action': 'login'
		'ip': '192.168.1.1'
	}
	logger.info_with_fields('User login', 'auth', fields)
	println('  ✅ 结构化日志测试完成')
	
	// 测试HTTP请求日志
	logger.log_http_request('GET', '/api/users/123', 200, 150, 'Mozilla/5.0')
	println('  ✅ HTTP请求日志测试完成')
	
	// 测试性能监控日志
	logger.log_performance('database_query', 25, {
		'query': 'SELECT * FROM users'
		'rows': '10'
	})
	println('  ✅ 性能监控日志测试完成')
}

fn test_error_handling_integration() {
	println('\n📊 错误处理集成测试...')
	
	// 创建模拟Context
	mut ctx := create_mock_context()
	
	// 测试各种错误处理方法
	error_tests := [
		{
			'name': 'bad_request'
			'expected_code': 400
		},
		{
			'name': 'unauthorized'
			'expected_code': 401
		},
		{
			'name': 'forbidden'
			'expected_code': 403
		},
		{
			'name': 'not_found'
			'expected_code': 404
		},
		{
			'name': 'internal_error'
			'expected_code': 500
		}
	]
	
	mut success_count := 0
	for test in error_tests {
		response := match test['name'] {
			'bad_request' { hono.bad_request(mut ctx, 'Bad request test') }
			'unauthorized' { hono.unauthorized(mut ctx, 'Unauthorized test') }
			'forbidden' { hono.forbidden(mut ctx, 'Forbidden test') }
			'not_found' { hono.not_found(mut ctx, 'Not found test') }
			'internal_error' { hono.internal_error(mut ctx, 'Internal error test') }
			else { http.Response{status_code: 0} }
		}
		
		expected_code := test['expected_code'].int()
		if response.status_code == expected_code {
			success_count++
		}
	}
	
	if success_count == error_tests.len {
		println('  ✅ 错误处理方法测试通过 (${success_count}/${error_tests.len})')
	} else {
		println('  ❌ 错误处理方法测试失败 (${success_count}/${error_tests.len})')
	}
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
		if !hono.validate_file_path(path, hono.PathValidationOptions{}) {
			blocked_count++
		}
	}
	
	if blocked_count == dangerous_paths.len {
		println('  ✅ 危险路径全部被阻止 (${blocked_count}/${dangerous_paths.len})')
	} else {
		println('  ❌ 部分危险路径未被阻止 (${blocked_count}/${dangerous_paths.len})')
	}
	
	// 测试文件哈希验证
	invalid_hashes := [
		'invalid_hash',
		'12345',
		'abcdefghijklmnopqrstuvwxyz123456789',  // 太长
		'abcdefg'  // 太短
	]
	
	mut hash_blocked_count := 0
	for hash in invalid_hashes {
		if !hono.validate_file_hash(hash) {
			hash_blocked_count++
		}
	}
	
	if hash_blocked_count == invalid_hashes.len {
		println('  ✅ 无效哈希全部被阻止 (${hash_blocked_count}/${invalid_hashes.len})')
	} else {
		println('  ❌ 部分无效哈希未被阻止 (${hash_blocked_count}/${invalid_hashes.len})')
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