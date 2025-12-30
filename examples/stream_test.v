import hono
import net.http
import os
import time
import strings

fn main() {
	println('=== 文件流式传输测试 ===')
	
	// 创建测试文件
	create_test_files()
	
	// 创建应用
	mut app := &hono.Hono{}
	
	// 测试路由
	setup_test_routes(mut app)
	
	// 在后台启动服务器
	spawn app.listen(':8081')
	
	// 等待服务器启动
	time.sleep(2 * time.second)
	println('服务器已启动在 http://127.0.0.1:8081')
	
	// 执行测试
	run_tests()
	
	println('\n所有测试完成!')
}

fn create_test_files() {
	println('创建测试文件...')
	
	// 创建小文件 (1KB)
	small_content := 'Hello World! '.repeat(80) // 约1KB
	os.write_file('test_small.txt', small_content) or { panic(err) }
	println('  创建小文件: test_small.txt (${small_content.len} bytes)')
	
	// 创建中等文件 (1MB) 
	mut medium_content := strings.new_builder(1024 * 1024)
	for i in 0 .. 1000 {
		medium_content.write_string('This is line ${i:04d} with some content to make it longer.\n')
	}
	medium_str := medium_content.str()
	os.write_file('test_medium.txt', medium_str) or { panic(err) }
	println('  创建中等文件: test_medium.txt (${medium_str.len} bytes)')
	
	// 创建大文件 (模拟5MB)
	mut large_content := strings.new_builder(5 * 1024 * 1024)
	base_line := 'This is a long line of text that will be repeated many times to create a large file for testing streaming functionality. '
	for i in 0 .. 50000 {  // 约5MB
		large_content.write_string('${i:06d}: $base_line\n')
	}
	large_str := large_content.str()
	os.write_file('test_large.txt', large_str) or { panic(err) }
	println('  创建大文件: test_large.txt (${large_str.len} bytes)')
}

fn setup_test_routes(mut app hono.Hono) {
	// 传统文件服务（内存加载）
	app.get('/traditional/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		return c.file(filename)
	})
	
	// 流式文件服务
	app.get('/stream/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		return c.file_stream(filename)
	})
	
	// 智能文件服务（自动选择）
	app.get('/smart/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		return c.file_smart(filename)
	})
	
	// 带自定义选项的流式服务
	app.get('/custom/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		options := hono.FileOptions{
			stream_threshold: 100 * 1024  // 100KB阈值
			buffer_size: 4096             // 4KB缓冲区
			enable_range: true
			max_age: 3600
		}
		return c.file_stream_with_options(filename, options)
	})
	
	// Range请求测试
	app.get('/range/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		options := hono.FileOptions{
			enable_range: true
			stream_threshold: 1024  // 1KB阈值，强制使用流式传输
		}
		return c.file_stream_with_options(filename, options)
	})
}

fn run_tests() {
	println('\n开始性能测试...')
	
	// 测试1：小文件性能对比
	test_small_file_performance()
	
	// 测试2：中等文件性能对比  
	test_medium_file_performance()
	
	// 测试3：大文件性能对比
	test_large_file_performance()
	
	// 测试4：Range请求测试
	test_range_requests()
	
	// 测试5：智能选择测试
	test_smart_selection()
}

fn test_small_file_performance() {
	println('\n--- 小文件性能测试 ---')
	
	// 传统方式
	start := time.now()
	for i in 0 .. 100 {
		_ = os.execute('curl -s http://127.0.0.1:8081/traditional/test_small.txt > nul')
	}
	traditional_time := time.now() - start
	println('传统方式 100次请求: $traditional_time')
	
	// 流式方式
	start2 := time.now()
	for i in 0 .. 100 {
		_ = os.execute('curl -s http://127.0.0.1:8081/stream/test_small.txt > nul')
	}
	stream_time := time.now() - start2
	println('流式方式 100次请求: $stream_time')
	
	// 智能方式
	start3 := time.now()
	for i in 0 .. 100 {
		_ = os.execute('curl -s http://127.0.0.1:8081/smart/test_small.txt > nul')
	}
	smart_time := time.now() - start3
	println('智能方式 100次请求: $smart_time')
}

fn test_medium_file_performance() {
	println('\n--- 中等文件性能测试 ---')
	
	// 传统方式
	start := time.now()
	for i in 0 .. 10 {
		_ = os.execute('curl -s http://127.0.0.1:8081/traditional/test_medium.txt > nul')
	}
	traditional_time := time.now() - start
	println('传统方式 10次请求: $traditional_time')
	
	// 流式方式
	start2 := time.now()
	for i in 0 .. 10 {
		_ = os.execute('curl -s http://127.0.0.1:8081/stream/test_medium.txt > nul')
	}
	stream_time := time.now() - start2
	println('流式方式 10次请求: $stream_time')
}

fn test_large_file_performance() {
	println('\n--- 大文件性能测试 ---')
	
	// 只测试流式方式，避免内存问题
	start := time.now()
	for i in 0 .. 5 {
		result := os.execute('curl -s http://127.0.0.1:8081/stream/test_large.txt > nul')
		if result.exit_code != 0 {
			println('  请求 $i 失败')
		}
	}
	stream_time := time.now() - start
	println('流式方式 5次大文件请求: $stream_time')
	
	// 智能方式（应该自动选择流式传输）
	start2 := time.now()
	for i in 0 .. 5 {
		result := os.execute('curl -s http://127.0.0.1:8081/smart/test_large.txt > nul')
		if result.exit_code != 0 {
			println('  智能方式请求 $i 失败')
		}
	}
	smart_time := time.now() - start2
	println('智能方式 5次大文件请求: $smart_time')
}

fn test_range_requests() {
	println('\n--- Range请求测试 ---')
	
	// 测试部分内容请求
	result1 := os.execute('curl -s -H "Range: bytes=0-99" http://127.0.0.1:8081/range/test_medium.txt')
	if result1.exit_code == 0 {
		println('✅ Range请求 0-99: 成功')
	} else {
		println('❌ Range请求 0-99: 失败')
	}
	
	result2 := os.execute('curl -s -H "Range: bytes=100-199" http://127.0.0.1:8081/range/test_medium.txt')
	if result2.exit_code == 0 {
		println('✅ Range请求 100-199: 成功')  
	} else {
		println('❌ Range请求 100-199: 失败')
	}
}

fn test_smart_selection() {
	println('\n--- 智能选择测试 ---')
	
	// 测试小文件（应该使用内存加载）
	result1 := os.execute('curl -s http://127.0.0.1:8081/smart/test_small.txt')
	if result1.exit_code == 0 {
		println('✅ 智能选择小文件: 成功')
	} else {
		println('❌ 智能选择小文件: 失败')
	}
	
	// 测试大文件（应该使用流式传输）
	result2 := os.execute('curl -s -o large_output.txt http://127.0.0.1:8081/smart/test_large.txt')
	if result2.exit_code == 0 {
		// 检查下载的文件大小
		if os.exists('large_output.txt') {
			downloaded_size := os.file_size('large_output.txt')
			original_size := os.file_size('test_large.txt')
			if downloaded_size == original_size {
				println('✅ 智能选择大文件: 成功 (${downloaded_size} bytes)')
			} else {
				println('❌ 智能选择大文件: 大小不匹配 (${downloaded_size} vs ${original_size})')
			}
			os.rm('large_output.txt') or {}
		}
	} else {
		println('❌ 智能选择大文件: 失败')
	}
}
