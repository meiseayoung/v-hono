import hono
import time
import strings
import net.http

// 测试统计
struct TestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
	start_time   time.Time
}

fn (mut stats TestStats) start_test(test_name string) {
	stats.total_tests++
	print('🧪 ${test_name}... ')
}

fn (mut stats TestStats) pass_test() {
	stats.passed_tests++
	println('✅')
}

fn (mut stats TestStats) fail_test(error string) {
	stats.failed_tests++
	println('❌ ${error}')
}

fn (stats TestStats) print_summary() {
	duration := time.since(stats.start_time)
	println('\n=== 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')
	if stats.total_tests > 0 {
		println('成功率: ${(stats.passed_tests * 100 / stats.total_tests)}%')
	}
	println('耗时: ${duration.milliseconds()}ms')
	
	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// 1. 测试缓存系统
fn test_cache_system(mut stats TestStats) {
	stats.start_test('缓存系统')
	
	// 创建缓存
	mut cache := hono.ContextLRUCache.new(3)
	
	// 创建测试数据
	test_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{ path: '/test' }
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	// 测试基本操作
	cache.put('key1', test_match)
	cache.put('key2', test_match)
	cache.put('key3', test_match)
	
	// 验证获取
	if _ := cache.get('key1') {
		// 获取成功
	} else {
		stats.fail_test('无法获取缓存值')
		return
	}
	
	// 测试LRU淘汰 - key1 被访问后移到头部，key2 成为最久未使用
	cache.put('key4', test_match)  // 应该淘汰 key2
	
	if _ := cache.get('key2') {
		stats.fail_test('LRU淘汰机制失效')
		return
	}
	
	// 测试健康检查
	if !cache.is_healthy() {
		stats.fail_test('缓存健康检查失败')
		return
	}
	
	stats.pass_test()
}

// 2. 测试安全验证
fn test_security_validation(mut stats TestStats) {
	stats.start_test('安全验证')
	
	// 测试路径验证
	dangerous_paths := [
		'../../../etc/passwd',
		'..\\..\\windows\\system32',
		'/etc/passwd',
		'C:\\Windows\\System32',
		'file<script>',
		'file|rm -rf'
	]
	
	for path in dangerous_paths {
		result := hono.validate_file_path(path, hono.PathValidationOptions{}) or { '' }
		if result != '' {
			stats.fail_test('危险路径未被拒绝: ${path}')
			return
		}
	}
	
	// 测试安全路径
	safe_paths := [
		'documents/file.txt',
		'images/photo.jpg',
		'data/report.pdf'
	]
	
	for path in safe_paths {
		result := hono.validate_file_path(path, hono.PathValidationOptions{}) or {
			stats.fail_test('安全路径被错误拒绝: ${path} - ${err}')
			return
		}
		if result == '' {
			stats.fail_test('安全路径返回空: ${path}')
			return
		}
	}
	
	// 测试哈希验证
	invalid_hashes := [
		'invalid_hash',
		'12345',
		'hash with spaces'
	]
	
	for hash in invalid_hashes {
		result := hono.validate_file_hash(hash) or { '' }
		if result != '' {
			stats.fail_test('无效哈希未被拒绝: ${hash}')
			return
		}
	}
	
	// 测试有效哈希 (32字符)
	valid_hash := 'a1b2c3d4e5f67890123456789012abcd'
	result := hono.validate_file_hash(valid_hash) or {
		stats.fail_test('有效哈希被错误拒绝: ${err}')
		return
	}
	if result == '' {
		stats.fail_test('有效哈希返回空')
		return
	}
	
	stats.pass_test()
}

// 3. 测试错误处理
fn test_error_handling(mut stats TestStats) {
	stats.start_test('错误处理')
	
	// 创建测试 Context
	mut ctx := create_test_context()
	
	// 测试各种错误响应
	response := ctx.bad_request('测试错误')
	if response.status_code != 400 {
		stats.fail_test('bad_request 状态码错误')
		return
	}
	
	response2 := ctx.unauthorized('未授权')
	if response2.status_code != 401 {
		stats.fail_test('unauthorized 状态码错误')
		return
	}
	
	response3 := ctx.forbidden('禁止访问')
	if response3.status_code != 403 {
		stats.fail_test('forbidden 状态码错误')
		return
	}
	
	response4 := ctx.not_found('未找到')
	if response4.status_code != 404 {
		stats.fail_test('not_found 状态码错误')
		return
	}
	
	response5 := ctx.internal_error('内部错误')
	if response5.status_code != 500 {
		stats.fail_test('internal_error 状态码错误')
		return
	}
	
	stats.pass_test()
}

// 4. 测试路由系统
fn test_router_system(mut stats TestStats) {
	stats.start_test('路由系统')
	
	mut router := hono.FastRouter.new()
	
	// 添加路由
	routes := [
		['/users', 'get_users'],
		['/users/:id', 'get_user'],
		['/posts/:post_id/comments/:comment_id', 'get_comment']
	]
	
	for route in routes {
		handler := hono.ContextHandler{
			path: route[0]
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			stats.fail_test('添加路由失败: ${route[0]}')
			return
		}
	}
	
	// 测试静态路由匹配
	if _ := router.match_route('GET', '/users') {
		// 匹配成功
	} else {
		stats.fail_test('静态路由匹配失败')
		return
	}
	
	// 测试动态路由匹配
	if match_result := router.match_route('GET', '/users/123') {
		if match_result.params['id'] != '123' {
			stats.fail_test('参数提取失败')
			return
		}
	} else {
		stats.fail_test('动态路由匹配失败')
		return
	}
	
	// 测试多参数路由
	if match_result := router.match_route('GET', '/posts/456/comments/789') {
		if match_result.params['post_id'] != '456' || match_result.params['comment_id'] != '789' {
			stats.fail_test('多参数提取失败')
			return
		}
	} else {
		stats.fail_test('多参数路由匹配失败')
		return
	}
	
	// 测试不存在的路由
	if _ := router.match_route('DELETE', '/nonexistent') {
		stats.fail_test('不应该匹配不存在的路由')
		return
	}
	
	stats.pass_test()
}

// 5. 测试配置管理
fn test_config_management(mut stats TestStats) {
	stats.start_test('配置管理')
	
	// 测试默认配置
	config := hono.default_config()
	
	if config.server.host != '127.0.0.1' {
		stats.fail_test('默认主机地址不正确')
		return
	}
	
	if config.server.port != 8080 {
		stats.fail_test('默认端口不正确')
		return
	}
	
	// 测试配置验证
	mut invalid_config := config
	invalid_config.server.port = 0
	
	hono.validate_config(invalid_config) or {
		// 应该验证失败
		stats.pass_test()
		return
	}
	
	stats.fail_test('无效配置未被拒绝')
}

// 6. 测试日志系统
fn test_logging_system(mut stats TestStats) {
	stats.start_test('日志系统')
	
	// 创建测试日志器
	config := hono.LoggerConfig{
		level: hono.LogLevel.debug
		output: hono.LogOutput.console
		enable_colors: false
	}
	
	mut logger := hono.new_logger(config)
	
	// 测试日志级别转换
	if hono.parse_log_level('info') != hono.LogLevel.info {
		stats.fail_test('日志级别解析失败')
		return
	}
	
	if hono.log_level_to_string(hono.LogLevel.error) != 'ERROR' {
		stats.fail_test('日志级别转字符串失败')
		return
	}
	
	// 测试日志输出（不会失败，只是验证不崩溃）
	logger.info('测试信息日志')
	logger.warn('测试警告日志')
	logger.error('测试错误日志')
	
	stats.pass_test()
}


// 7. 测试文件上传配置
fn test_file_upload_config(mut stats TestStats) {
	stats.start_test('文件上传配置')
	
	// 创建上传配置
	config := hono.ChunkUploadConfig{
		upload_dir: './test_uploads'
		max_file_size: 1024 * 1024  // 1MB
		chunk_size: 1024            // 1KB
	}
	
	// 验证配置
	if config.upload_dir != './test_uploads' {
		stats.fail_test('上传目录配置错误')
		return
	}
	
	if config.max_file_size != 1024 * 1024 {
		stats.fail_test('最大文件大小配置错误')
		return
	}
	
	// 创建上传管理器
	mut manager := hono.new_chunk_upload_manager(config)
	
	// 验证管理器创建成功
	if manager.config.chunk_size != 1024 {
		stats.fail_test('上传管理器配置错误')
		return
	}
	
	stats.pass_test()
}

// 8. 测试性能
fn test_performance(mut stats TestStats) {
	stats.start_test('性能测试')
	
	// 测试字符串构建性能
	start_time := time.now()
	
	mut builder := strings.new_builder(1000)
	for i in 0 .. 100 {
		builder.write_string('test string ${i} ')
	}
	result := builder.str()
	
	duration := time.since(start_time)
	
	if result.len == 0 {
		stats.fail_test('字符串构建失败')
		return
	}
	
	if duration.milliseconds() > 100 {
		stats.fail_test('字符串构建性能不达标: ${duration.milliseconds()}ms')
		return
	}
	
	// 测试缓存性能
	start_time2 := time.now()
	
	mut cache := hono.ContextLRUCache.new(1000)
	test_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{ path: '/test' }
		params: {}
		path: '/test'
		base_path: ''
	}
	
	for i in 0 .. 1000 {
		cache.put('key${i}', test_match)
	}
	
	for i in 0 .. 1000 {
		_ := cache.get('key${i}') or { continue }
	}
	
	duration2 := time.since(start_time2)
	
	if duration2.milliseconds() > 500 {
		stats.fail_test('缓存性能不达标: ${duration2.milliseconds()}ms')
		return
	}
	
	stats.pass_test()
}

// 9. 测试内存管理
fn test_memory_management(mut stats TestStats) {
	stats.start_test('内存管理')
	
	// 测试缓存清理
	mut cache := hono.ContextLRUCache.new(5)
	
	test_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{ path: '/test' }
		params: {}
		path: '/test'
		base_path: ''
	}
	
	// 填充缓存
	for i in 0 .. 10 {
		cache.put('key${i}', test_match)
	}
	
	// 验证大小限制
	size, capacity := cache.get_stats()
	if size > capacity {
		stats.fail_test('缓存大小超出限制: ${size}/${capacity}')
		return
	}
	
	// 清理缓存
	cache.clear()
	
	size2, _ := cache.get_stats()
	if size2 != 0 {
		stats.fail_test('缓存清理失败')
		return
	}
	
	// 验证健康状态
	if !cache.is_healthy() {
		stats.fail_test('缓存清理后健康检查失败')
		return
	}
	
	stats.pass_test()
}

// 10. 集成测试
fn test_integration(mut stats TestStats) {
	stats.start_test('集成测试')
	
	// 创建完整的应用
	mut app := hono.Hono.new()
	
	// 添加路由
	app.get('/health', fn (mut c hono.Context) http.Response {
		return c.json('{"status": "ok"}')
	})
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		return c.json('{"user_id": "${user_id}"}')
	})
	
	// 验证路由统计
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	
	if static_count + dynamic_count < 2 {
		stats.fail_test('路由添加失败')
		return
	}
	
	// 创建缓存
	mut cache := hono.ContextLRUCache.new(100)
	test_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{ path: '/test' }
		params: {}
		path: '/test'
		base_path: ''
	}
	cache.put('app_status', test_match)
	
	// 验证缓存
	if _ := cache.get('app_status') {
		// 缓存获取成功
	} else {
		stats.fail_test('缓存获取失败')
		return
	}
	
	// 创建日志器
	log_config := hono.LoggerConfig{
		level: hono.LogLevel.info
		output: hono.LogOutput.console
		enable_colors: false
	}
	mut logger := hono.new_logger(log_config)
	logger.info_with_module('集成测试完成', 'TEST')
	
	stats.pass_test()
}

// 辅助函数：创建测试 Context
fn create_test_context() hono.Context {
	req := http.Request{
		method: .get
		url: '/test'
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

fn main() {
	println('🚀 开始V-Hono综合测试套件...\n')
	
	mut stats := TestStats{
		start_time: time.now()
	}
	
	// 运行所有测试
	test_cache_system(mut stats)
	test_security_validation(mut stats)
	test_error_handling(mut stats)
	test_router_system(mut stats)
	test_config_management(mut stats)
	test_logging_system(mut stats)
	test_file_upload_config(mut stats)
	test_performance(mut stats)
	test_memory_management(mut stats)
	test_integration(mut stats)
	
	// 打印测试总结
	stats.print_summary()
}
