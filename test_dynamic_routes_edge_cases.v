import hono
import time
import net.http

fn main() {
	println('=== 动态路由边界情况测试 ===')
	
	// 测试1: 特殊字符和编码
	test_special_characters()
	
	// 测试2: 长路径和深层嵌套
	test_long_paths()
	
	// 测试3: 相似路由冲突
	test_route_conflicts()
	
	// 测试4: 参数边界值
	test_parameter_boundaries()
	
	// 测试5: 性能退化场景
	test_performance_degradation()
	
	// 测试6: 内存使用测试
	test_memory_usage()
	
	// 测试7: 并发安全测试
	test_concurrent_access()
	
	// 测试8: 错误恢复测试
	test_error_recovery()
	
	println('✅ 动态路由边界情况测试完成')
}

fn test_special_characters() {
	println('\n📊 特殊字符和编码测试...')
	
	mut app := hono.Hono.new()
	
	// 包含特殊字符的路由
	special_routes := [
		'/users/:user_id',                    // 基础路由
		'/files/:filename',                   // 文件名可能包含特殊字符
		'/search/:query',                     // 搜索查询
		'/categories/:category_name',         // 分类名称
		'/tags/:tag_name',                    // 标签名称
		'/paths/:path_segment',               // 路径段
	]
	
	for route in special_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('special response')
		})
	}
	
	// 测试包含特殊字符的路径
	special_test_cases := [
		// 数字和字母
		{ 'path': '/users/user123', 'expect': true, 'desc': '数字字母组合' },
		{ 'path': '/users/USER_123', 'expect': true, 'desc': '大写字母下划线' },
		
		// 连字符和下划线
		{ 'path': '/files/my-file.txt', 'expect': true, 'desc': '连字符文件名' },
		{ 'path': '/files/my_file.txt', 'expect': true, 'desc': '下划线文件名' },
		
		// URL编码字符 (注意：实际应用中可能需要解码)
		{ 'path': '/search/hello%20world', 'expect': true, 'desc': 'URL编码空格' },
		{ 'path': '/categories/tech%26dev', 'expect': true, 'desc': 'URL编码&符号' },
		
		// 特殊标识符
		{ 'path': '/tags/c++', 'expect': true, 'desc': 'C++标签' },
		{ 'path': '/tags/node.js', 'expect': true, 'desc': '点号标签' },
		
		// 长标识符
		{ 'path': '/users/very-long-username-with-many-characters-123456789', 'expect': true, 'desc': '长用户名' },
		
		// 边界情况
		{ 'path': '/users/', 'expect': false, 'desc': '空参数' },
		{ 'path': '/users', 'expect': false, 'desc': '缺少参数' },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in special_test_cases {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if test_case['expect'] == 'true' {
				success_count++
				params := match_result.params
				param_value := params.values().first() or { 'none' }
				println('  ✅ ${test_case['desc']}: ${test_case['path']} → ${param_value} (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: ${test_case['path']} - 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if test_case['expect'] == 'false' {
				success_count++
				println('  ✅ ${test_case['desc']}: ${test_case['path']} - 正确拒绝 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: ${test_case['path']} - 匹配失败 (${match_time})')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(special_test_cases.len)
	println('  📈 特殊字符测试: ${success_count}/${special_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_long_paths() {
	println('\n📊 长路径和深层嵌套测试...')
	
	mut app := hono.Hono.new()
	
	// 创建不同深度的嵌套路由
	nesting_levels := [3, 5, 7, 10, 15]
	
	for level in nesting_levels {
		mut route_parts := []string{}
		route_parts << ''  // 开始的斜杠
		
		for i in 0 .. level {
			route_parts << 'level${i}'
			route_parts << ':param${i}'
		}
		
		route := route_parts.join('/')
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('deep response')
		})
	}
	
	// 创建长路径测试用例
	mut long_path_tests := []map[string]string{}
	
	for level in nesting_levels {
		mut path_parts := []string{}
		path_parts << ''  // 开始的斜杠
		
		for i in 0 .. level {
			path_parts << 'level${i}'
			path_parts << 'value${i}'
		}
		
		path := path_parts.join('/')
		long_path_tests << {
			'path': path
			'level': level.str()
			'expect': 'true'
		}
	}
	
	// 添加一些无效的长路径
	long_path_tests << {
		'path': '/level0/value0/level1/value1/level2/value2/level3/value3/extra'
		'level': 'invalid'
		'expect': 'false'
	}
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in long_path_tests {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if test_case['expect'] == 'true' {
				success_count++
				param_count := match_result.params.len
				path_length := test_case['path'].len
				println('  ✅ 嵌套级别${test_case['level']}: ${param_count}参数, ${path_length}字符 (${match_time})')
			} else {
				println('  ❌ ${test_case['path']} - 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if test_case['expect'] == 'false' {
				success_count++
				println('  ✅ 无效路径正确拒绝: ${test_case['path']} (${match_time})')
			} else {
				println('  ❌ 嵌套级别${test_case['level']} - 匹配失败 (${match_time})')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(long_path_tests.len)
	println('  📈 长路径测试: ${success_count}/${long_path_tests.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_route_conflicts() {
	println('\n📊 相似路由冲突测试...')
	
	mut app := hono.Hono.new()
	
	// 添加可能冲突的路由
	conflicting_routes := [
		// 静态 vs 动态
		'/users/profile',                    // 静态路由
		'/users/:id',                        // 动态路由
		
		// 不同参数名
		'/posts/:id',                        // 第一个动态路由
		'/posts/:post_id',                   // 相同模式，不同参数名 (应该冲突)
		
		// 不同深度
		'/api/users',                        // 静态路由
		'/api/:resource',                    // 动态路由
		'/api/:version/users',               // 更深层的动态路由
		
		// 相似模式
		'/files/:category/:name',            // 两个参数
		'/files/:type/:filename',            // 相同结构，不同参数名
		
		// 前缀冲突
		'/admin',                            // 静态
		'/admin/:section',                   // 动态
		'/admin/users/:id',                  // 更具体的动态
	]
	
	// 逐个添加路由，观察行为
	for i, route in conflicting_routes {
		app.get(route, fn [i] (mut c hono.Context) http.Response {
			return c.text('response from route ${i}')
		})
	}
	
	// 测试冲突解决
	conflict_test_cases := [
		{ 'path': '/users/profile', 'desc': '静态路由优先' },
		{ 'path': '/users/123', 'desc': '动态路由匹配' },
		{ 'path': '/posts/456', 'desc': '第一个动态路由' },
		{ 'path': '/api/users', 'desc': '静态API路由' },
		{ 'path': '/api/posts', 'desc': '动态资源路由' },
		{ 'path': '/api/v1/users', 'desc': '版本化API路由' },
		{ 'path': '/files/images/photo.jpg', 'desc': '文件路由匹配' },
		{ 'path': '/admin', 'desc': '管理员首页' },
		{ 'path': '/admin/settings', 'desc': '管理员设置' },
		{ 'path': '/admin/users/789', 'desc': '管理员用户详情' },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in conflict_test_cases {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			
			// 显示匹配的路由模式
			matched_pattern := match_result.path
			param_count := match_result.params.len
			println('  ✅ ${test_case['desc']}: ${test_case['path']} → ${matched_pattern} (${param_count}参数, ${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${test_case['desc']}: ${test_case['path']} - 无匹配 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(conflict_test_cases.len)
	println('  📈 路由冲突测试: ${success_count}/${conflict_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_parameter_boundaries() {
	println('\n📊 参数边界值测试...')
	
	mut app := hono.Hono.new()
	
	// 参数边界测试路由
	boundary_routes := [
		'/short/:id',                        // 短参数
		'/long/:very_long_parameter_name',   // 长参数名
		'/multi/:a/:b/:c/:d/:e',            // 多参数
		'/numeric/:number',                  // 数字参数
		'/mixed/:id/:name/:type',           // 混合参数
	]
	
	for route in boundary_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('boundary response')
		})
	}
	
	// 边界值测试用例
	boundary_test_cases := [
		// 短参数值
		{ 'path': '/short/1', 'desc': '单字符参数' },
		{ 'path': '/short/a', 'desc': '单字母参数' },
		
		// 长参数值
		{ 'path': '/long/this-is-a-very-long-parameter-value-with-many-characters-and-hyphens-123456789', 'desc': '超长参数值' },
		
		// 多参数
		{ 'path': '/multi/a/b/c/d/e', 'desc': '5个短参数' },
		{ 'path': '/multi/param1/param2/param3/param4/param5', 'desc': '5个中等参数' },
		
		// 数字参数
		{ 'path': '/numeric/0', 'desc': '零值' },
		{ 'path': '/numeric/123456789', 'desc': '大数字' },
		{ 'path': '/numeric/-123', 'desc': '负数' },
		
		// 混合参数
		{ 'path': '/mixed/123/john-doe/admin', 'desc': '混合类型参数' },
		{ 'path': '/mixed/0/a/x', 'desc': '最小混合参数' },
		
		// 边界情况
		{ 'path': '/short/', 'desc': '空参数', 'expect': false },
		{ 'path': '/multi/a/b/c/d', 'desc': '参数不足', 'expect': false },
		{ 'path': '/multi/a/b/c/d/e/f', 'desc': '参数过多', 'expect': false },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in boundary_test_cases {
		start_time := time.now()
		expect_match := test_case['expect'] or { 'true' } == 'true'
		
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if expect_match {
				success_count++
				params := match_result.params
				param_info := []string{}
				for key, value in params {
					param_info << '${key}=${value}'
				}
				println('  ✅ ${test_case['desc']}: [${param_info.join(', ')}] (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if !expect_match {
				success_count++
				println('  ✅ ${test_case['desc']}: 正确拒绝 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 匹配失败 (${match_time})')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(boundary_test_cases.len)
	println('  📈 参数边界测试: ${success_count}/${boundary_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_performance_degradation() {
	println('\n📊 性能退化场景测试...')
	
	mut app := hono.Hono.new()
	
	// 创建可能导致性能退化的路由模式
	degradation_scenarios := [
		// 场景1: 大量相似路由
		{
			'name': '相似路由模式'
			'count': 100
			'pattern': '/api/v1/resources/:id/items/:item_id'
		},
		// 场景2: 复杂嵌套路由
		{
			'name': '复杂嵌套路由'
			'count': 50
			'pattern': '/complex/:a/:b/:c/:d/:e/:f'
		},
		// 场景3: 长路径路由
		{
			'name': '长路径路由'
			'count': 30
			'pattern': '/very/long/path/with/many/segments/:param1/:param2/:param3'
		},
	]
	
	for scenario in degradation_scenarios {
		println('  创建${scenario['name']} (${scenario['count']}个路由)...')
		
		count := scenario['count'].int()
		pattern := scenario['pattern']
		
		for i in 0 .. count {
			// 为每个路由添加唯一标识
			unique_pattern := pattern.replace(':id', ':id${i}').replace(':item_id', ':item_id${i}')
			
			app.get(unique_pattern, fn [i] (mut c hono.Context) http.Response {
				return c.text('response ${i}')
			})
		}
	}
	
	// 测试性能退化
	test_iterations := [10, 100, 1000, 5000]
	
	for iterations in test_iterations {
		println('  测试 ${iterations} 次匹配...')
		
		test_paths := [
			'/api/v1/resources/123/items/456',
			'/complex/a/b/c/d/e/f',
			'/very/long/path/with/many/segments/param1/param2/param3',
		]
		
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
		total_requests := iterations * test_paths.len
		avg_time := f64(total_time.microseconds()) / f64(total_requests)
		
		println('    ${iterations}次: ${match_count}/${total_requests} 匹配, 平均 ${avg_time:.3f}μs')
	}
	
	// 显示最终统计
	static_count, dynamic_count, cache_count := app.fast_router.get_stats()
	println('  📊 最终统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}

fn test_memory_usage() {
	println('\n📊 内存使用测试...')
	
	mut app := hono.Hono.new()
	
	// 测试不同规模的路由对内存的影响
	memory_test_scales := [10, 50, 100, 500, 1000]
	
	for scale in memory_test_scales {
		println('  测试 ${scale} 个路由的内存使用...')
		
		// 清理之前的路由
		app = hono.Hono.new()
		
		// 添加指定数量的路由
		for i in 0 .. scale {
			route_pattern := '/test${i}/:param1/:param2/:param3'
			app.get(route_pattern, fn [i] (mut c hono.Context) http.Response {
				return c.text('response ${i}')
			})
		}
		
		// 执行一些匹配操作来填充缓存
		for i in 0 .. 10 {
			test_path := '/test${i % scale}/value1/value2/value3'
			app.fast_router.match_route('GET', test_path)
		}
		
		// 获取统计信息
		static_count, dynamic_count, cache_count := app.fast_router.get_stats()
		
		println('    ${scale}个路由: 动态=${dynamic_count}, 缓存=${cache_count}')
		
		// 简单的内存使用估算 (基于数据结构)
		estimated_memory := dynamic_count * 200 + cache_count * 150  // 粗略估算，单位字节
		println('    估算内存使用: ~${estimated_memory} 字节')
	}
}

fn test_concurrent_access() {
	println('\n📊 并发安全测试...')
	
	mut app := hono.Hono.new()
	
	// 添加一些测试路由
	concurrent_routes := [
		'/concurrent/:id',
		'/parallel/:type/:value',
		'/shared/:resource/:action',
	]
	
	for route in concurrent_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('concurrent response')
		})
	}
	
	// 模拟并发访问 (注意：V语言的并发模型可能不同)
	test_paths := [
		'/concurrent/123',
		'/parallel/user/create',
		'/shared/database/read',
		'/concurrent/456',
		'/parallel/admin/delete',
		'/shared/cache/write',
	]
	
	println('  模拟并发路由匹配...')
	
	// 连续快速执行多次匹配 (模拟并发)
	iterations := 1000
	start_time := time.now()
	mut success_count := 0
	
	for i in 0 .. iterations {
		path := test_paths[i % test_paths.len]
		if _ := app.fast_router.match_route('GET', path) {
			success_count++
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(iterations)
	
	println('  📈 并发测试: ${success_count}/${iterations} 成功, 平均 ${avg_time:.3f}μs')
	
	// 检查缓存一致性
	static_count, dynamic_count, cache_count := app.fast_router.get_stats()
	println('  📊 缓存状态: 动态=${dynamic_count}, 缓存=${cache_count}')
}

fn test_error_recovery() {
	println('\n📊 错误恢复测试...')
	
	mut app := hono.Hono.new()
	
	// 添加正常路由
	app.get('/normal/:id', fn (mut c hono.Context) http.Response {
		return c.text('normal response')
	})
	
	// 测试各种错误情况的恢复
	error_test_cases := [
		{ 'path': '/normal/123', 'desc': '正常路径', 'expect': true },
		{ 'path': '/nonexistent', 'desc': '不存在的路径', 'expect': false },
		{ 'path': '/normal/', 'desc': '空参数', 'expect': false },
		{ 'path': '/normal', 'desc': '缺少参数', 'expect': false },
		{ 'path': '', 'desc': '空路径', 'expect': false },
		{ 'path': '/', 'desc': '根路径', 'expect': false },
		{ 'path': '/normal/123/extra', 'desc': '额外路径段', 'expect': false },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in error_test_cases {
		start_time := time.now()
		expect_match := test_case['expect'].str() == 'true'
		
		// 测试错误恢复
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if expect_match {
				success_count++
				println('  ✅ ${test_case['desc']}: 正常匹配 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 意外匹配 (${match_time})')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if !expect_match {
				success_count++
				println('  ✅ ${test_case['desc']}: 正确处理错误 (${match_time})')
			} else {
				println('  ❌ ${test_case['desc']}: 匹配失败 (${match_time})')
			}
		}
		
		// 验证系统仍然正常工作
		if recovery_result := app.fast_router.match_route('GET', '/normal/recovery-test') {
			println('    ↳ 系统恢复正常')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(error_test_cases.len)
	println('  📈 错误恢复测试: ${success_count}/${error_test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}