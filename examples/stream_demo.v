import meiseayoung.hono
import net.http
import os

fn main() {
	println('=== 基础文件流式传输测试 ===')
	
	// 直接创建测试文件
	test_content := 'Hello World from V-Hono streaming test! '.repeat(1000)
	os.write_file('stream_test.txt', test_content) or {
		println('❌ 无法创建测试文件: $err')
		return
	}
	defer {
		os.rm('stream_test.txt') or { }
	}
	
	println('✅ 创建测试文件: stream_test.txt (${test_content.len} bytes)')
	
	// 创建模拟请求
	test_req := http.Request{
		method: http.Method.get
		url: '/test'
		data: ''
		header: http.new_header()
	}
	
	// 测试传统文件服务
	println('\n--- 传统文件服务测试 ---')
	mut ctx1 := hono.Context.new(test_req, map[string]string{}, map[string]string{}, '')
	response1 := ctx1.file('stream_test.txt')
	
	if response1.status_code == 200 && response1.body.len == test_content.len {
		println('✅ 传统文件服务: 成功 (${response1.body.len} bytes)')
	} else {
		println('❌ 传统文件服务: 失败 (状态码: ${response1.status_code}, 大小: ${response1.body.len})')
	}
	
	// 测试流式文件服务
	println('\n--- 流式文件服务测试 ---')
	mut ctx2 := hono.Context.new(test_req, map[string]string{}, map[string]string{}, '')
	response2 := ctx2.file_stream('stream_test.txt')
	
	if response2.status_code == 200 && response2.body.len == test_content.len {
		println('✅ 流式文件服务: 成功 (${response2.body.len} bytes)')
	} else {
		println('❌ 流式文件服务: 失败 (状态码: ${response2.status_code}, 大小: ${response2.body.len})')
	}
	
	// 测试智能文件服务
	println('\n--- 智能文件服务测试 ---')
	mut ctx3 := hono.Context.new(test_req, map[string]string{}, map[string]string{}, '')
	response3 := ctx3.file_smart('stream_test.txt')
	
	if response3.status_code == 200 && response3.body.len == test_content.len {
		println('✅ 智能文件服务: 成功 (${response3.body.len} bytes)')
	} else {
		println('❌ 智能文件服务: 失败 (状态码: ${response3.status_code}, 大小: ${response3.body.len})')
	}
	
	// 测试自定义选项
	println('\n--- 自定义选项测试 ---')
	custom_options := hono.FileOptions{
		stream_threshold: 1024  // 1KB阈值，强制流式传输
		buffer_size: 2048
		enable_range: true
		max_age: 3600
		headers: {
			'X-Test': 'stream-test'
		}
	}
	
	mut ctx4 := hono.Context.new(test_req, map[string]string{}, map[string]string{}, '')
	response4 := ctx4.file_stream_with_options('stream_test.txt', custom_options)
	
	if response4.status_code == 200 && response4.body.len == test_content.len {
		println('✅ 自定义选项: 成功 (${response4.body.len} bytes)')
		
		// 检查自定义头部
		if test_header := response4.header.get_custom('X-Test') {
			println('  📋 自定义头部: $test_header')
		}
		
		if cache_control := response4.header.get_custom('Cache-Control') {
			println('  🕒 缓存控制: $cache_control')
		}
		
		if accept_ranges := response4.header.get_custom('Accept-Ranges') {
			println('  📊 Range支持: $accept_ranges')
		}
	} else {
		println('❌ 自定义选项: 失败 (状态码: ${response4.status_code}, 大小: ${response4.body.len})')
	}
	
	// 测试Range请求
	println('\n--- Range请求测试 ---')
	mut range_header := http.new_header()
	range_header.add_custom('Range', 'bytes=0-99') or { }
	
	range_req := http.Request{
		method: http.Method.get
		url: '/test'
		data: ''
		header: range_header
	}
	
	range_options := hono.FileOptions{
		enable_range: true
		stream_threshold: 0  // 强制流式传输
	}
	
	mut ctx5 := hono.Context.new(range_req, map[string]string{}, map[string]string{}, '')
	response5 := ctx5.file_stream_with_options('stream_test.txt', range_options)
	
	if response5.status_code == 206 {  // Partial Content
		println('✅ Range请求: 成功 (状态码: 206, 内容长度: ${response5.body.len})')
		
		if content_range := response5.header.get_custom('Content-Range') {
			println('  📊 Content-Range: $content_range')
		}
	} else {
		println('❌ Range请求: 失败 (状态码: ${response5.status_code})')
	}
	
	println('\n🎉 所有测试完成!')
}
