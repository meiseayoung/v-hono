import hono
import time
import net.http

fn main() {
	println('=== 路由性能详细分析 ===')
	
	// 测试1: 分步骤性能分析
	test_step_by_step_performance()
	
	// 测试2: 不同复杂度路由的性能对比
	test_complexity_performance()
	
	println('✅ 路由性能分析完成')
}

fn test_step_by_step_performance() {
	println('\n📊 分步骤性能分析...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 测试路由
	route_path := '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id'
	test_path := '/api/v1/users/123/posts/456/comments/789'
	
	handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	
	// 步骤1: 添加路由的时间
	start_time1 := time.now()
	router.add_route('GET', handler, '')
	add_route_time := time.since(start_time1)
	println('  添加路由时间: ${add_route_time}')
	
	// 步骤2: 第一次匹配（包含编译）
	start_time2 := time.now()
	result1 := router.match_route('GET', test_path)
	first_match_time := time.since(start_time2)
	println('  第一次匹配时间 (含编译): ${first_match_time}')
	
	if result1 != none {
		println('  ✅ 第一次匹配成功')
	}
	
	// 步骤3: 第二次匹配（使用缓存）
	start_time3 := time.now()
	_ = router.match_route('GET', test_path)
	second_match_time := time.since(start_time3)
	println('  第二次匹配时间 (使用缓存): ${second_match_time}')
	
	// 步骤4: 分析缓存状态
	cache_size, cache_capacity := router.get_cache_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	println('  路由缓存: ${cache_size}/${cache_capacity}')
	println('  正则缓存: ${regex_compiled}/${regex_total}')
	
	// 步骤5: 测试纯正则匹配时间（安全访问）
	if cached := router.regex_cache[route_path] {
		if cached.compiled {
			// 先验证正则能匹配
			if cached.regex.matches_string(test_path) {
				start_time4 := time.now()
				for _ in 0 .. 1000 {
					cached.regex.matches_string(test_path)
				}
				pure_regex_time := time.since(start_time4)
				avg_regex_time := f64(pure_regex_time.microseconds()) / 1000.0
				println('  纯正则匹配平均时间: ${avg_regex_time:.3f}μs')
			} else {
				println('  ⚠️  正则表达式无法匹配测试路径')
			}
		}
	} else {
		println('  ⚠️  正则缓存中未找到路由')
	}
	
	// 步骤6: 测试参数提取时间（安全访问）
	if cached := router.regex_cache[route_path] {
		if cached.compiled && cached.param_names.len > 0 {
			// 先执行一次匹配确保正则状态正确
			if cached.regex.matches_string(test_path) {
				start_time5 := time.now()
				mut extract_count := 0
				for _ in 0 .. 1000 {
					// 每次提取前重新匹配
					if cached.regex.matches_string(test_path) {
						for param_name in cached.param_names {
							group := cached.regex.get_group_by_name(test_path, param_name)
							if group.len > 0 {
								extract_count++
							}
						}
					}
				}
				param_extract_time := time.since(start_time5)
				avg_param_time := f64(param_extract_time.microseconds()) / 1000.0
				println('  参数提取平均时间: ${avg_param_time:.3f}μs')
				println('  参数数量: ${cached.param_names.len}')
			}
		}
	}
}

fn test_complexity_performance() {
	println('\n📊 不同复杂度路由性能对比...')
	
	// 定义不同复杂度的路由
	test_cases := [
		{
			'name': '简单路由 (1个参数)'
			'route': '/users/:id'
			'path': '/users/123'
		},
		{
			'name': '中等路由 (2个参数)'
			'route': '/users/:id/posts/:post_id'
			'path': '/users/123/posts/456'
		},
		{
			'name': '复杂路由 (3个参数)'
			'route': '/api/:version/users/:user_id/posts/:post_id'
			'path': '/api/v1/users/123/posts/456'
		},
		{
			'name': '很复杂路由 (5个参数)'
			'route': '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id/replies/:reply_id'
			'path': '/api/v1/users/123/posts/456/comments/789/replies/101'
		}
	]
	
	for test_case in test_cases {
		println('\n  测试: ${test_case['name']}')
		
		mut router := hono.ContextHybridRouter.new()
		
		handler := hono.ContextHandler{
			path: test_case['route']
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		
		router.add_route('GET', handler, '')
		
		// 第一次匹配（编译）
		start_time1 := time.now()
		result1 := router.match_route('GET', test_case['path'])
		first_time := time.since(start_time1)
		
		// 多次缓存匹配
		iterations := 10000
		start_time2 := time.now()
		mut cache_matches := 0
		for _ in 0 .. iterations {
			if _ := router.match_route('GET', test_case['path']) {
				cache_matches++
			}
		}
		cache_time := time.since(start_time2)
		
		if result1 != none {
			println('    第一次匹配: ${first_time}')
			if cache_matches > 0 {
				avg_cache_time := f64(cache_time.microseconds()) / f64(cache_matches)
				println('    平均缓存匹配: ${avg_cache_time:.3f}μs')
			}
			
			// 分析路由复杂度
			param_count := test_case['route'].count(':')
			path_segments := test_case['route'].split('/').len
			println('    参数数量: ${param_count}')
			println('    路径段数: ${path_segments}')
		} else {
			println('    ❌ 匹配失败')
		}
	}
	
	// 测试路由排序效果
	println('\n  📈 测试路由排序效果...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加不同复杂度的路由（故意按复杂度递减顺序添加）
	routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',  // 最复杂
		'/api/:version/users/:user_id/posts/:post_id',                      // 中等复杂
		'/users/:id/posts/:post_id',                                        // 较简单
		'/users/:id'                                                        // 最简单
	]
	
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	// 测试匹配最简单的路由（应该最先被匹配）
	simple_path := '/users/123'
	
	start_time := time.now()
	for _ in 0 .. 10000 {
		router.match_route('GET', simple_path)
	}
	sorted_time := time.since(start_time)
	
	avg_sorted_time := f64(sorted_time.microseconds()) / 10000.0
	println('    排序后简单路由平均匹配时间: ${avg_sorted_time:.3f}μs')
	
	// 显示路由顺序
	_, dynamic_paths := router.get_all_routes()
	println('    路由排序后顺序:')
	for i, path in dynamic_paths {
		println('      ${i+1}. ${path}')
	}
}
