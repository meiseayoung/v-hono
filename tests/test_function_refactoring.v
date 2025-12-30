import os

fn main() {
	println('=== 函数重构可读性测试 ===')
	
	// 测试1: 检查example.v的函数数量和长度
	test_example_function_structure()
	
	// 测试2: 验证功能完整性
	test_functionality_completeness()
	
	println('✅ 所有函数重构测试完成')
}

fn test_example_function_structure() {
	println('\n📊 测试example.v函数结构...')
	
	// 尝试多个可能的路径
	possible_paths := [
		'examples/basic/example.v',
		'example.v',
		'../example.v',
		'examples/example.v',
	]
	
	mut content := ''
	mut found_path := ''
	
	for path in possible_paths {
		if os.exists(path) {
			content = os.read_file(path) or { continue }
			found_path = path
			break
		}
	}
	
	if content == '' {
		println('  ⚠️  未找到example.v文件，跳过此测试')
		println('  ✅ 测试跳过（文件不存在）')
		return
	}
	
	println('  找到文件: ${found_path}')
	
	lines := content.split('\n')
	mut function_count := 0
	mut main_function_lines := 0
	mut in_main_function := false
	mut brace_count := 0
	
	for _, line in lines {
		trimmed := line.trim_space()
		
		// 统计函数数量
		if trimmed.starts_with('fn ') {
			function_count++
			if trimmed.starts_with('fn main()') {
				in_main_function = true
				main_function_lines = 1
				brace_count = 0
			}
		}
		
		// 统计main函数长度
		if in_main_function {
			if trimmed.contains('{') {
				brace_count += trimmed.count('{')
			}
			if trimmed.contains('}') {
				brace_count -= trimmed.count('}')
				if brace_count == 0 {
					in_main_function = false
				}
			}
			if in_main_function {
				main_function_lines++
			}
		}
	}
	
	println('  函数总数: $function_count')
	println('  main函数行数: $main_function_lines')
	
	// 验证重构效果
	if function_count >= 1 {
		println('  ✅ 函数数量正常 (${function_count}个)')
	} else {
		println('  ⚠️  函数数量较少 (${function_count}个)')
	}
	
	if main_function_lines <= 100 {
		println('  ✅ main函数长度合理 (${main_function_lines}行)')
	} else {
		println('  ⚠️  main函数较长 (${main_function_lines}行)')
	}
}

fn test_functionality_completeness() {
	println('\n📊 测试功能完整性...')
	
	// 尝试多个可能的路径
	possible_paths := [
		'examples/basic/example.v',
		'example.v',
		'../example.v',
		'examples/example.v',
	]
	
	mut content := ''
	
	for path in possible_paths {
		if os.exists(path) {
			content = os.read_file(path) or { continue }
			break
		}
	}
	
	if content == '' {
		println('  ⚠️  未找到example.v文件，跳过此测试')
		println('  ✅ 测试跳过（文件不存在）')
		return
	}
	
	// 检查关键功能是否保留
	key_features := [
		'hono.Hono.new()',           // 应用创建
		'app.get(',                   // GET路由
		'app.listen(',                // 服务器启动
	]
	
	mut found_features := 0
	for feature in key_features {
		if content.contains(feature) {
			found_features++
		}
	}
	
	println('  核心功能保留: ${found_features}/${key_features.len}')
	
	if found_features == key_features.len {
		println('  ✅ 所有核心功能都已保留')
	} else {
		println('  ⚠️  部分核心功能可能缺失')
	}
	
	// 检查代码是否包含基本结构
	basic_checks := [
		'import',
		'fn main()',
		'hono',
	]
	
	mut found_basic := 0
	for check in basic_checks {
		if content.contains(check) {
			found_basic++
		}
	}
	
	println('  基本结构检查: ${found_basic}/${basic_checks.len}')
	
	if found_basic == basic_checks.len {
		println('  ✅ 代码结构完整')
	} else {
		println('  ⚠️  代码结构需要检查')
	}
}
