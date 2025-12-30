import hono
import net.http
import os
import time
import strings

fn main() {
	println('=== 字符串拼接优化测试 ===')
	
	// 测试1: 简单JSON构建性能
	test_json_building()
	
	// 测试2: 大量字符串拼接性能
	test_large_string_concatenation()
	
	// 测试3: 路由路径构建性能
	test_path_building()
	
	println('✅ 所有字符串优化测试完成')
}

fn test_json_building() {
	println('\n📊 测试JSON构建性能...')
	
	// 测试数据
	test_data := {
		'action': 'test_action'
		'id': '12345'
		'path': '/api/test'
		'url': 'http://localhost:8080/api/test'
	}
	
	// 方法1: 使用字符串插值（优化后）
	start_time := time.now()
	for i in 0 .. 10000 {
		_ := '{"message": "测试", "params": {"action": "${test_data['action']}", "id": "${test_data['id']}"}}'
	}
	interpolation_time := time.since(start_time)
	
	// 方法2: 使用StringBuilder（复杂场景）
	start_time2 := time.now()
	for i in 0 .. 10000 {
		mut builder := strings.new_builder(256)
		builder.write_string('{"message": "测试", "params": {"action": "')
		builder.write_string(test_data['action'])
		builder.write_string('", "id": "')
		builder.write_string(test_data['id'])
		builder.write_string('"}}')
		_ := builder.str()
	}
	builder_time := time.since(start_time2)
	
	println('  字符串插值方法: ${interpolation_time}')
	println('  StringBuilder方法: ${builder_time}')
	
	if interpolation_time < builder_time {
		println('  ✅ 字符串插值更快 (简单场景)')
	} else {
		println('  ✅ StringBuilder更快 (复杂场景)')
	}
}

fn test_large_string_concatenation() {
	println('\n📊 测试大量字符串拼接性能...')
	
	// 方法1: 使用StringBuilder（优化后）
	start_time := time.now()
	mut content := strings.new_builder(1024 * 1024)
	for i in 0 .. 10000 {
		content.write_string('Line ${i:05d}: This is a test line with some content.\n')
	}
	result1 := content.str()
	builder_time := time.since(start_time)
	
	// 方法2: 传统字符串拼接（对比）
	start_time2 := time.now()
	mut content2 := ''
	for i in 0 .. 1000 {  // 减少次数避免过慢
		content2 += 'Line ${i:05d}: This is a test line with some content.\n'
	}
	concat_time := time.since(start_time2)
	
	println('  StringBuilder方法 (10000行): ${builder_time}')
	println('  传统拼接方法 (1000行): ${concat_time}')
	println('  StringBuilder结果长度: ${result1.len}')
	println('  传统拼接结果长度: ${content2.len}')
	
	// 计算性能提升
	if builder_time.milliseconds() > 0 && concat_time.milliseconds() > 0 {
		// 标准化到相同的操作数量进行比较
		normalized_concat_time := concat_time.milliseconds() * 10  // 1000 -> 10000
		improvement := f64(normalized_concat_time) / f64(builder_time.milliseconds())
		println('  ✅ StringBuilder性能提升约: ${improvement:.1f}x')
	}
}

fn test_path_building() {
	println('\n📊 测试路径构建性能...')
	
	base_paths := ['/api', '/users', '/posts', '/comments']
	segments := ['123', 'test', 'data', 'info']
	
	// 方法1: 使用字符串插值（优化后）
	start_time := time.now()
	for i in 0 .. 10000 {
		base := base_paths[i % base_paths.len]
		segment := segments[i % segments.len]
		_ := '${base}/${segment}'
	}
	interpolation_time := time.since(start_time)
	
	// 方法2: 传统字符串拼接（对比）
	start_time2 := time.now()
	for i in 0 .. 10000 {
		base := base_paths[i % base_paths.len]
		segment := segments[i % segments.len]
		_ := base + '/' + segment
	}
	concat_time := time.since(start_time2)
	
	println('  字符串插值方法: ${interpolation_time}')
	println('  传统拼接方法: ${concat_time}')
	
	if interpolation_time < concat_time {
		println('  ✅ 字符串插值更快')
	} else {
		println('  ✅ 传统拼接更快')
	}
}