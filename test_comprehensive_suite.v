import hono
import os
import time
import strings

// 测试统计
struct TestStats {
mut:
	total_tests int
	passed_tests int
	failed_tests int
	start_time time.Time
}

fn (mut stats TestStats) start_test(test_name string) {
	stats.total_tests++
	println('🧪 运行测试: ${test_name}')
}

fn (mut stats TestStats) pass_test(test_name string) {
	stats.passed_tests++
	println('✅ 测试通过: ${test_name}')
}

fn (mut stats TestStats) fail_test(test_name string, error string) {
	stats.failed_tests++
	println('❌ 测试失败: ${test_name} - ${error}')
}

fn (stats TestStats) print_summary() {
	duration := time.since(stats.start_time)
	println('\n=== 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')
	println('成功率: ${(stats.passed_tests * 100 / stats.total_tests)}%')
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
	mut cache := hono.new_context_lru_cache(3)
	
	// 测试基本操作
	cache.put('key1', 'value1')
	cache.put('key2', 'value2')
	cache.put('key3', 'value3')
	
	// 验证获取
	if val := cache.get('key1') {
		if val != 'value1' {
			stats.fail_test('缓存系统', '获取值不匹配')
			return
		}
	} else {
		stats.fail_test('缓存系统', '无法获取缓存值')
		return
	}
	
	// 测试LRU淘汰
	cache.put('key4', 'value4')  // 应该淘汰key2
	
	if cache.get('key2') or { '' } != '' {
		stats.fail_test('缓存系统', 'LRU淘汰机制失效')
		return
	}
	
	// 测试健康检查
	if !cache.is_healthy() {
		stats.fail_test('缓存系统', '缓存健康检查失败')
		return
	}
	
	stats.pass_test('缓存系统')
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
		'file|rm -rf',
		'CON.txt',
		'PRN.log'
	]
	
	for path in dangerous_paths {
		if hono.validate_file_path(path, hono.PathValidationOptions{}) {
			stats.fail_test('安全验证', '危险路径未被拒绝: ${path}')
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
		if !hono.validate_file_path(path, hono.PathValidationOptions{}) {
			stats.fail_test('安全验证', '安全路径被错误拒绝: ${path}')
			return
		}
	}
	
	// 测试哈希验证
	invalid_hashes := [
		'invalid_hash',
		'12345',
		'abcdefghijklmnopqrstuvwxyz123456789',
		'hash with spaces'
	]
	
	for hash in invalid_hashes {
		if hono.validate_file_hash(hash) {
			stats.fail_test('安全验证', '无效哈希未被拒绝: ${hash}')
			return
		}
	}
	
	// 测试有效哈希
	valid_hash := 'a1b2c3d4e5f6789012345678901234567'
	if !hono.validate_file_hash(valid_hash) {
		stats.fail_test('安全验证', '有效哈希被错误拒绝')
		return
	}
	
	stats.pass_test('安全验证')
}

// 3. 测试错误处理
fn test_error_handling(mut stats TestStats) {
	stats.start_test('错误处理')
	
	// 测试各种错误类型
	error_tests := [
		{
			'type': 'bad_request'
			'expected_code': '400'
		},
		{
			'type': 'unauthorized'
			'expected_code': '401'
		},
		{
			'type': 'forbidden'
			'expected_code': '403'
		},
		{
			'type': 'not_found'
			'expected_code': '404'
		},
		{
			'type': 'internal_error'
			'expected_code': '500'
		}
	]
	
	for test in error_tests {
		mut response := match test['type'] {
			'bad_request' { hono.bad_request('测试错误', '/test') }
			'unauthorized' { hono.unauthorized('未授权', '/test') }
			'forbidden' { hono.forbidden('禁止访问', '/test') }
			'not_found' { hono.not_found('未找到', '/test') }
			'internal_error' { hono.internal_error('内部错误', '/test') }
			else { hono.bad_request('默认错误', '/test') }
		}
		
		if !response.contains('"code":"${test['expected_code']}"') {
			stats.fail_test('错误处理', '错误代码不匹配: ${test['type']}')
			return
		}
		
		if !response.contains('"timestamp"') {
			stats.fail_test('错误处理', '缺少时间戳: ${test['type']}')
			return
		}
	}
	
	stats.pass_test('错误处理')
}

// 4. 测试路由系统
fn test_router_system(mut stats TestStats) {
	stats.start_test('路由系统')
	
	mut router := hono.new_router()
	
	// 添加路由
	router.add_route('GET', '/users', 'get_users')
	router.add_route('POST', '/users', 'create_user')
	router.add_route('GET', '/users/:id', 'get_user')
	router.add_route('PUT', '/users/:id', 'update_user')
	
	// 测试路由匹配
	route_tests := [
		{
			'method': 'GET'
			'path': '/users'
			'expected': 'get_users'
		},
		{
			'method': 'POST'
			'path': '/users'
			'expected': 'create_user'
		},
		{
			'method': 'GET'
			'path': '/users/123'
			'expected': 'get_user'
		},
		{
			'method': 'PUT'
			'path': '/users/456'
			'expected': 'update_user'
		}
	]
	
	for test in route_tests {
		if route := router.match_route(test['method'], test['path']) {
			if route.handler != test['expected'] {
				stats.fail_test('路由系统', '路由处理器不匹配: ${test['path']}')
				return
			}
		} else {
			stats.fail_test('路由系统', '路由匹配失败: ${test['path']}')
			return
		}
	}
	
	// 测试不存在的路由
	if router.match_route('DELETE', '/nonexistent') != none {
		stats.fail_test('路由系统', '不应该匹配不存在的路由')
		return
	}
	
	stats.pass_test('路由系统')
}

// 5. 测试配置管理
fn test_config_management(mut stats TestStats) {
	stats.start_test('配置管理')
	
	// 测试默认配置
	config := hono.default_config()
	
	if config.server.host != '127.0.0.1' {
		stats.fail_test('配置管理', '默认主机地址不正确')
		return
	}
	
	if config.server.port != 8080 {
		stats.fail_test('配置管理', '默认端口不正确')
		return
	}
	
	// 测试配置验证
	mut invalid_config := config
	invalid_config.server.port = 0
	
	hono.validate_config(invalid_config) or {
		// 应该验证失败
		stats.pass_test('配置管理')
		return
	}
	
	stats.fail_test('配置管理', '无效配置未被拒绝')
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
	
	// 测试日志级别
	if !logger.should_log(hono.LogLevel.info) {
		stats.fail_test('日志系统', '日志级别检查失败')
		return
	}
	
	if logger.should_log(hono.LogLevel.debug) && config.level != hono.LogLevel.debug {
		stats.fail_test('日志系统', '日志级别过滤失败')
		return
	}
	
	// 测试日志级别转换
	if hono.parse_log_level('info') != hono.LogLevel.info {
		stats.fail_test('日志系统', '日志级别解析失败')
		return
	}
	
	if hono.log_level_to_string(hono.LogLevel.error) != 'ERROR' {
		stats.fail_test('日志系统', '日志级别转字符串失败')
		return
	}
	
	stats.pass_test('日志系统')
}

// 7. 测试文件上传
fn test_file_upload(mut stats TestStats) {
	stats.start_test('文件上传')
	
	// 创建上传配置
	config := hono.ChunkUploadConfig{
		upload_dir: './test_uploads'
		max_file_size: 1024 * 1024  // 1MB
		max_chunk_size: 1024        // 1KB
		merge_buffer_size: 512      // 512B
	}
	
	mut uploader := hono.new_chunk_uploader(config)
	
	// 清理测试目录
	if os.exists(config.upload_dir) {
		os.rmdir_all(config.upload_dir) or {}
	}
	
	// 创建测试分片
	test_hash := 'test123456789012345678901234567890'
	chunk_data := 'Hello, World! This is test chunk data.'
	
	// 上传分片
	uploader.upload_chunk(test_hash, 0, chunk_data.bytes()) or {
		stats.fail_test('文件上传', '分片上传失败: ${err}')
		return
	}
	
	// 检查分片是否存在
	if !uploader.chunk_exists(test_hash, 0) {
		stats.fail_test('文件上传', '分片检查失败')
		return
	}
	
	// 测试合并（单个分片）
	uploader.merge_chunks(test_hash, 1) or {
		stats.fail_test('文件上传', '分片合并失败: ${err}')
		return
	}
	
	// 验证合并后的文件
	merged_file := '${config.upload_dir}/${test_hash}'
	if !os.exists(merged_file) {
		stats.fail_test('文件上传', '合并后文件不存在')
		return
	}
	
	content := os.read_file(merged_file) or {
		stats.fail_test('文件上传', '无法读取合并文件')
		return
	}
	
	if content != chunk_data {
		stats.fail_test('文件上传', '合并文件内容不匹配')
		return
	}
	
	// 清理测试文件
	os.rmdir_all(config.upload_dir) or {}
	
	stats.pass_test('文件上传')
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
		stats.fail_test('性能测试', '字符串构建失败')
		return
	}
	
	if duration.milliseconds() > 100 {  // 应该在100ms内完成
		stats.fail_test('性能测试', '字符串构建性能不达标: ${duration.milliseconds()}ms')
		return
	}
	
	// 测试缓存性能
	start_time2 := time.now()
	
	mut cache := hono.new_context_lru_cache(1000)
	for i in 0 .. 1000 {
		cache.put('key${i}', 'value${i}')
	}
	
	for i in 0 .. 1000 {
		cache.get('key${i}') or { '' }
	}
	
	duration2 := time.since(start_time2)
	
	if duration2.milliseconds() > 500 {  // 应该在500ms内完成
		stats.fail_test('性能测试', '缓存性能不达标: ${duration2.milliseconds()}ms')
		return
	}
	
	stats.pass_test('性能测试')
}

// 9. 测试内存管理
fn test_memory_management(mut stats TestStats) {
	stats.start_test('内存管理')
	
	// 测试缓存清理
	mut cache := hono.new_context_lru_cache(5)
	
	// 填充缓存
	for i in 0 .. 10 {
		cache.put('key${i}', 'value${i}')
	}
	
	// 验证大小限制
	if cache.size() > 5 {
		stats.fail_test('内存管理', '缓存大小超出限制')
		return
	}
	
	// 清理缓存
	cache.clear()
	
	if cache.size() != 0 {
		stats.fail_test('内存管理', '缓存清理失败')
		return
	}
	
	// 验证健康状态
	if !cache.is_healthy() {
		stats.fail_test('内存管理', '缓存清理后健康检查失败')
		return
	}
	
	stats.pass_test('内存管理')
}

// 10. 集成测试
fn test_integration(mut stats TestStats) {
	stats.start_test('集成测试')
	
	// 创建完整的应用配置
	app_config := hono.default_config()
	
	// 创建日志器
	log_config := hono.LoggerConfig{
		level: hono.LogLevel.info
		output: hono.LogOutput.console
		enable_colors: false
	}
	mut logger := hono.new_logger(log_config)
	
	// 创建路由器
	mut router := hono.new_router()
	router.add_route('GET', '/health', 'health_check')
	
	// 创建缓存
	mut cache := hono.new_context_lru_cache(100)
	cache.put('app_status', 'running')
	
	// 验证组件协作
	if route := router.match_route('GET', '/health') {
		if route.handler != 'health_check' {
			stats.fail_test('集成测试', '路由匹配失败')
			return
		}
	} else {
		stats.fail_test('集成测试', '路由不存在')
		return
	}
	
	if status := cache.get('app_status') {
		if status != 'running' {
			stats.fail_test('集成测试', '缓存状态不正确')
			return
		}
	} else {
		stats.fail_test('集成测试', '缓存获取失败')
		return
	}
	
	// 记录集成测试日志
	logger.info_with_module('集成测试完成', 'TEST')
	
	stats.pass_test('集成测试')
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
	test_file_upload(mut stats)
	test_performance(mut stats)
	test_memory_management(mut stats)
	test_integration(mut stats)
	
	// 打印测试总结
	stats.print_summary()
}