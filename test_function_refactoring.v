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
	
	content := os.read_file('example.v') or {
		println('  ❌ 无法读取example.v文件')
		return
	}
	
	lines := content.split('\n')
	mut function_count := 0
	mut main_function_lines := 0
	mut in_main_function := false
	mut brace_count := 0
	
	for i, line in lines {
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
	if function_count >= 10 {
		println('  ✅ 函数数量充足 (${function_count}个)')
	} else {
		println('  ⚠️  函数数量较少 (${function_count}个)')
	}
	
	if main_function_lines <= 50 {
		println('  ✅ main函数长度合理 (${main_function_lines}行)')
	} else {
		println('  ⚠️  main函数仍然较长 (${main_function_lines}行)')
	}
	
	// 检查关键函数是否存在
	key_functions := [
		'setup_middleware',
		'setup_static_file_services',
		'setup_chunk_upload_routes',
		'setup_basic_routes',
		'setup_api_routes',
		'setup_dynamic_routes',
		'setup_http_method_examples',
		'setup_file_service_routes',
		'setup_error_handling',
		'print_startup_info'
	]
	
	mut found_functions := 0
	for func_name in key_functions {
		if content.contains('fn ${func_name}(') {
			found_functions++
		}
	}
	
	println('  关键函数覆盖: ${found_functions}/${key_functions.len}')
	
	if found_functions == key_functions.len {
		println('  ✅ 所有关键函数都已提取')
	} else {
		println('  ⚠️  部分关键函数缺失')
	}
}

fn test_functionality_completeness() {
	println('\n📊 测试功能完整性...')
	
	content := os.read_file('example.v') or {
		println('  ❌ 无法读取example.v文件')
		return
	}
	
	// 检查关键功能是否保留
	key_features := [
		'app.use(hono.serve_static_default())',  // 静态文件服务
		'app.post(\'/upload/chunk\'',             // 分片上传
		'app.get(\'/api/health\'',               // API端点
		'app.get(\'/users/:id\'',                // 动态路由
		'app.post(\'/api/users\'',               // HTTP方法
		'app.get(\'/file/:filename\'',           // 文件服务
		'app.listen(\':8080\')'                  // 服务器启动
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
	
	// 检查代码组织结构
	organization_checks := [
		'// 配置中间件',
		'// 配置静态文件服务', 
		'// 配置分块上传功能',
		'// 配置基础路由',
		'// 配置API路由',
		'// 配置动态路由',
		'// 配置HTTP方法示例',
		'// 配置文件服务功能',
		'// 配置错误处理'
	]
	
	mut found_organization := 0
	for check in organization_checks {
		if content.contains(check) {
			found_organization++
		}
	}
	
	println('  代码组织结构: ${found_organization}/${organization_checks.len}')
	
	if found_organization >= organization_checks.len - 1 {
		println('  ✅ 代码组织结构清晰')
	} else {
		println('  ⚠️  代码组织结构需要改进')
	}
}