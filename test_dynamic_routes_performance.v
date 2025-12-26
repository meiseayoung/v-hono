import hono
import time
import net.http

fn main() {
	println('=== 动态路由性能压力测试 ===')
	
	// 测试1: 大规模动态路由性能
	test_large_scale_dynamic_routes()
	
	// 测试2: 深层嵌套路由性能
	test_deep_nested_routes_performance()
	
	// 测试3: 高频访问路由性能
	test_high_frequency_routes()
	
	// 测试4: 混合路由类型性能
	test_mixed_route_types_performance()
	
	// 测试5: 路由缓存效率测试
	test_route_cache_efficiency()
	
	// 测试6: 并发路由匹配性能
	test_concurrent_route_matching()
	
	println('✅ 动态路由性能压力测试完成')
}

fn test_large_scale_dynamic_routes() {
	println('\n📊 大规模动态路由性能测试...')
	
	mut app := hono.Hono.new()
	
	// 创建大量动态路由
	route_count := 1000
	println('  创建 ${route_count} 个动态路由...')
	
	mut route_patterns := []string{}
	
	for i in 0 .. route_count {
		// 生成不同复杂度的路由
		complexity := i % 5
		mut route := ''
		
		match complexity {
			0 { route = '/simple/:id${i}' }
			1 { route = '/api/v${i % 3}/users/:id${i}' }
			2 { route = '/api/v${i % 3}/users/:user_id/posts/:post_id${i}' }
			3 { route = '/api/v${i % 3}/orgs/:org_id/teams/:team_id/members/:member_id${i}' }
			4 { route = '/complex/:region/:city/stores/:store_id/products/:category/:product_id${i}' }
			else { route = '/default/:id${i}' }
		}
		
		route_patterns << route
		
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
	}
	
	println('  路由创建完成，开始性能测试...')
	
	// 生成测试路径
	mut test_paths := []string{}
	for i in 0 .. 100 {  // 测试100个不同的路径
		complexity := i % 5
		mut path := ''
		
		match complexity {
			0 { path = '/simple/id${i}' }
			1 { path = '/api/v${i % 3}/users/user${i}' }
			2 { path = '/api/v${i % 3}/users/user${i}/posts/post${i}' }
			3 { path = '/api/v${i % 3}/orgs/org${i}/teams/team${i}/members/member${i}' }
			4 { path = '/complex/region${i}/city${i}/stores/store${i}/products/cat${i}/prod${i}' }
			else { path = '/default/id${i}' }
		}
		
		test_paths << path
	}
	
	// 性能测试
	iterations := 1000
	
	start_time := time.now()
	mut match_count := 0
	mut total_matches := 0
	
	for _ in 0 .. iterations {
		for path in test_paths {
			total_matches++
			if _ := app.fast_router.match_route('GET', path) {
				match_count++
			}
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(total_matches)
	throughput := f64(total_matches) / total_time.seconds()
	
	println('  大规模路由性能结果:')
	println('    路由数量: ${route_count}')
	println('    测试路径: ${test_paths.len}')
	println('    总匹配次数: ${total_matches}')
	println('    成功匹配: ${match_count}')
	println('    总时间: ${total_time}')
	println('    平均时间: ${avg_time:.3f}μs')
	println('    吞吐量: ${throughput:.0f} 请求/秒')
	
	if avg_time < 50.0 {
		println('    ✅ 性能优秀 (< 50μs)')
	} else if avg_time < 100.0 {
		println('    ✅ 性能良好 (< 100μs)')
	} else {
		println('    ⚠️  性能一般 (>= 100μs)')
	}
}

fn test_deep_nested_routes_performance() {
	println('\n📊 深层嵌套路由性能测试...')
	
	mut app := hono.Hono.new()
	
	// 创建不同深度的嵌套路由
	nested_routes := [
		// 深度1
		'/level1/:param1',
		
		// 深度3
		'/level3/:param1/:param2/:param3',
		
		// 深度5
		'/level5/:param1/:param2/:param3/:param4/:param5',
		
		// 深度7
		'/level7/:param1/:param2/:param3/:param4/:param5/:param6/:param7',
		
		// 深度10
		'/level10/:param1/:param2/:param3/:param4/:param5/:param6/:param7/:param8/:param9/:param10',
		
		// 深度15 (极深嵌套)
		'/level15/:p1/:p2/:p3/:p4/:p5/:p6/:p7/:p8/:p9/:p10/:p11/:p12/:p13/:p14/:p15'
	]
	
	for route in nested_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('nested response')
		})
	}
	
	// 对应的测试路径
	nested_test_paths := [
		'/level1/value1',
		'/level3/value1/value2/value3',
		'/level5/value1/value2/value3/value4/value5',
		'/level7/value1/value2/value3/value4/value5/value6/value7',
		'/level10/value1/value2/value3/value4/value5/value6/value7/value8/value9/value10',
		'/level15/v1/v2/v3/v4/v5/v6/v7/v8/v9/v10/v11/v12/v13/v14/v15'
	]
	
	iterations := 5000
	
	println('  测试不同嵌套深度的性能:')
	
	for i, path in nested_test_paths {
		depth := match i {
			0 { 1 }
			1 { 3 }
			2 { 5 }
			3 { 7 }
			4 { 10 }
			5 { 15 }
			else { 0 }
		}
		
		start_time := time.now()
		mut matches := 0
		
		for _ in 0 .. iterations {
			if _ := app.fast_router.match_route('GET', path) {
				matches++
			}
		}
		
		test_time := time.since(start_time)
		avg_time := f64(test_time.microseconds()) / f64(matches)
		
		println('    深度${depth}: ${matches}次匹配, 平均${avg_time:.3f}μs')
	}
}

fn test_high_frequency_routes() {
	println('\n📊 高频访问路由性能测试...')
	
	mut app := hono.Hono.new()
	
	// 模拟真实应用的高频路由
	high_freq_routes := [
		'/api/v1/auth/verify',           // 认证验证 (最高频)
		'/api/v1/users/:id',             // 用户信息 (高频)
		'/api/v1/posts/:id',             // 文章详情 (高频)
		'/api/v1/search/:query',         // 搜索 (中高频)
		'/api/v1/notifications/:user_id', // 通知 (中频)
		'/health',                       // 健康检查 (高频)
		'/metrics',                      // 监控指标 (中频)
		'/api/v1/upload/:type',          // 文件上传 (中频)
		'/api/v1/analytics/:event',      // 分析事件 (低频)
		'/admin/dashboard'               // 管理后台 (低频)
	]
	
	for route in high_freq_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('high freq response')
		})
	}
	
	// 模拟真实访问模式 (加权)
	weighted_paths := []string{}
	
	// 最高频路由 (40%)
	for _ in 0 .. 400 {
		weighted_paths << '/api/v1/auth/verify'
		weighted_paths << '/health'
	}
	
	// 高频路由 (30%)
	for _ in 0 .. 150 {
		weighted_paths << '/api/v1/users/123'
		weighted_paths << '/api/v1/posts/456'
	}
	
	// 中频路由 (20%)
	for _ in 0 .. 100 {
		weighted_paths << '/api/v1/search/keyword'
		weighted_paths << '/api/v1/notifications/user789'
	}
	
	// 低频路由 (10%)
	for _ in 0 .. 50 {
		weighted_paths << '/api/v1/analytics/click'
		weighted_paths << '/admin/dashboard'
	}
	
	iterations := 1000
	
	println('  高频访问模式测试 (${weighted_paths.len}个加权路径):')
	
	start_time := time.now()
	mut total_matches := 0
	
	for _ in 0 .. iterations {
		for path in weighted_paths {
			if _ := app.fast_router.match_route('GET', path) {
				total_matches++
			}
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(total_matches)
	throughput := f64(total_matches) / total_time.seconds()
	
	println('    总匹配: ${total_matches}')
	println('    总时间: ${total_time}')
	println('    平均时间: ${avg_time:.3f}μs')
	println('    吞吐量: ${throughput:.0f} 请求/秒')
	
	// 测试缓存效果
	println('\n  缓存效果测试:')
	
	// 清除缓存后的性能
	app.clear_cache()
	start_time_no_cache := time.now()
	mut no_cache_matches := 0
	
	for _ in 0 .. 100 {
		app.clear_cache()
		for path in weighted_paths[0..10] {  // 只测试前10个路径
			if _ := app.fast_router.match_route('GET', path) {
				no_cache_matches++
			}
		}
	}
	
	no_cache_time := time.since(start_time_no_cache)
	no_cache_avg := f64(no_cache_time.microseconds()) / f64(no_cache_matches)
	
	// 有缓存的性能
	start_time_with_cache := time.now()
	mut with_cache_matches := 0
	
	for _ in 0 .. 100 {
		for path in weighted_paths[0..10] {
			if _ := app.fast_router.match_route('GET', path) {
				with_cache_matches++
			}
		}
	}
	
	with_cache_time := time.since(start_time_with_cache)
	with_cache_avg := f64(with_cache_time.microseconds()) / f64(with_cache_matches)
	
	cache_improvement := no_cache_avg / with_cache_avg
	
	println('    无缓存: ${no_cache_avg:.3f}μs')
	println('    有缓存: ${with_cache_avg:.3f}μs')
	println('    缓存提升: ${cache_improvement:.2f}x')
}

fn test_mixed_route_types_performance() {
	println('\n📊 混合路由类型性能测试...')
	
	mut app := hono.Hono.new()
	
	// 混合不同类型的路由
	mixed_routes := [
		// 静态路由 (20%)
		'/static/home',
		'/static/about',
		'/static/contact',
		'/static/help',
		'/static/terms',
		
		// 简单动态路由 (40%)
		'/users/:id',
		'/posts/:id',
		'/products/:id',
		'/orders/:id',
		'/files/:id',
		'/comments/:id',
		'/tags/:id',
		'/categories/:id',
		
		// 复杂动态路由 (30%)
		'/api/:version/users/:id',
		'/api/:version/posts/:id/comments',
		'/users/:id/posts/:post_id',
		'/users/:id/settings/:section',
		'/projects/:id/files/:file_id',
		'/orgs/:org_id/teams/:team_id',
		
		// 极复杂动态路由 (10%)
		'/api/:version/orgs/:org_id/projects/:project_id/tasks/:task_id',
		'/shop/:region/:city/stores/:store_id/products/:category/:product_id',
		'/enterprise/:tenant/departments/:dept_id/teams/:team_id/members/:member_id'
	]
	
	for route in mixed_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('mixed response')
		})
	}
	
	// 对应的测试路径
	mixed_test_paths := [
		// 静态路径
		'/static/home',
		'/static/about',
		'/static/contact',
		'/static/help',
		'/static/terms',
		
		// 简单动态路径
		'/users/123',
		'/posts/456',
		'/products/789',
		'/orders/101',
		'/files/202',
		'/comments/303',
		'/tags/404',
		'/categories/505',
		
		// 复杂动态路径
		'/api/v1/users/606',
		'/api/v2/posts/707/comments',
		'/users/808/posts/909',
		'/users/111/settings/privacy',
		'/projects/222/files/333',
		'/orgs/444/teams/555',
		
		// 极复杂动态路径
		'/api/v1/orgs/666/projects/777/tasks/888',
		'/shop/asia/beijing/stores/999/products/electronics/phone123',
		'/enterprise/company1/departments/dept1/teams/team1/members/member1'
	]
	
	iterations := 2000
	
	println('  混合路由类型性能测试:')
	
	// 按路由类型分组测试
	route_types := [
		{
			'name': '静态路由'
			'paths': mixed_test_paths[0..5]
		},
		{
			'name': '简单动态路由'
			'paths': mixed_test_paths[5..13]
		},
		{
			'name': '复杂动态路由'
			'paths': mixed_test_paths[13..19]
		},
		{
			'name': '极复杂动态路由'
			'paths': mixed_test_paths[19..22]
		}
	]
	
	for route_type in route_types {
		start_time := time.now()
		mut matches := 0
		
		for _ in 0 .. iterations {
			for path in route_type['paths'].split(',') {
				if path.len > 0 {
					if _ := app.fast_router.match_route('GET', path) {
						matches++
					}
				}
			}
		}
		
		test_time := time.since(start_time)
		avg_time := if matches > 0 { f64(test_time.microseconds()) / f64(matches) } else { 0.0 }
		
		println('    ${route_type['name']}: ${matches}次匹配, 平均${avg_time:.3f}μs')
	}
	
	// 整体混合测试
	println('\n  整体混合性能测试:')
	
	start_time := time.now()
	mut total_matches := 0
	
	for _ in 0 .. iterations {
		for path in mixed_test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				total_matches++
			}
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(total_matches)
	throughput := f64(total_matches) / total_time.seconds()
	
	println('    总匹配: ${total_matches}')
	println('    平均时间: ${avg_time:.3f}μs')
	println('    吞吐量: ${throughput:.0f} 请求/秒')
}

fn test_route_cache_efficiency() {
	println('\n📊 路由缓存效率测试...')
	
	mut app := hono.Hono.new()
	
	// 添加测试路由
	cache_test_routes := [
		'/cache/users/:id',
		'/cache/posts/:id/comments/:comment_id',
		'/cache/api/:version/resources/:resource_id',
		'/cache/complex/:param1/:param2/:param3/:param4'
	]
	
	for route in cache_test_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('cache test response')
		})
	}
	
	test_paths := [
		'/cache/users/123',
		'/cache/posts/456/comments/789',
		'/cache/api/v1/resources/res101',
		'/cache/complex/a/b/c/d'
	]
	
	iterations := 5000
	
	println('  缓存效率对比测试:')
	
	// 测试1: 无缓存性能
	println('    测试无缓存性能...')
	start_time1 := time.now()
	mut no_cache_matches := 0
	
	for _ in 0 .. iterations {
		app.clear_cache()  // 每次清除缓存
		for path in test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				no_cache_matches++
			}
		}
	}
	
	no_cache_time := time.since(start_time1)
	no_cache_avg := f64(no_cache_time.microseconds()) / f64(no_cache_matches)
	
	// 测试2: 有缓存性能
	println('    测试有缓存性能...')
	app.clear_cache()  // 初始清除
	
	start_time2 := time.now()
	mut with_cache_matches := 0
	
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				with_cache_matches++
			}
		}
	}
	
	with_cache_time := time.since(start_time2)
	with_cache_avg := f64(with_cache_time.microseconds()) / f64(with_cache_matches)
	
	// 测试3: 缓存命中率
	println('    测试缓存命中率...')
	app.clear_cache()
	
	// 预热缓存
	for path in test_paths {
		app.fast_router.match_route('GET', path)
	}
	
	// 测试命中率
	cache_hit_iterations := 1000
	mut cache_hits := 0
	
	for _ in 0 .. cache_hit_iterations {
		for path in test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				cache_hits++
			}
		}
	}
	
	hit_rate := f64(cache_hits) / f64(cache_hit_iterations * test_paths.len) * 100.0
	
	// 结果展示
	cache_improvement := no_cache_avg / with_cache_avg
	
	println('    结果:')
	println('      无缓存平均: ${no_cache_avg:.3f}μs')
	println('      有缓存平均: ${with_cache_avg:.3f}μs')
	println('      性能提升: ${cache_improvement:.2f}x')
	println('      缓存命中率: ${hit_rate:.1f}%')
	
	// 获取缓存统计
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('      路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}

fn test_concurrent_route_matching() {
	println('\n📊 并发路由匹配性能测试...')
	
	mut app := hono.Hono.new()
	
	// 添加并发测试路由
	concurrent_routes := [
		'/concurrent/users/:id',
		'/concurrent/posts/:id/comments/:comment_id',
		'/concurrent/api/:version/resources/:resource_id',
		'/concurrent/complex/:p1/:p2/:p3/:p4/:p5'
	]
	
	for route in concurrent_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('concurrent response')
		})
	}
	
	test_paths := [
		'/concurrent/users/user1',
		'/concurrent/posts/post1/comments/comment1',
		'/concurrent/api/v1/resources/resource1',
		'/concurrent/complex/a/b/c/d/e'
	]
	
	// 模拟不同并发级别
	concurrent_levels := [1, 10, 50, 100, 500, 1000]
	
	println('  并发级别性能测试:')
	
	for level in concurrent_levels {
		start_time := time.now()
		mut total_matches := 0
		
		// 模拟并发请求
		for _ in 0 .. level {
			for path in test_paths {
				if _ := app.fast_router.match_route('GET', path) {
					total_matches++
				}
			}
		}
		
		test_time := time.since(start_time)
		avg_time := f64(test_time.microseconds()) / f64(total_matches)
		throughput := f64(total_matches) / test_time.seconds()
		
		println('    并发${level}: ${total_matches}次匹配, 平均${avg_time:.3f}μs, ${throughput:.0f}请求/秒')
	}
	
	// 压力测试
	println('\n  高压力并发测试:')
	
	stress_level := 10000
	stress_iterations := 100
	
	start_time := time.now()
	mut stress_matches := 0
	
	for _ in 0 .. stress_iterations {
		for _ in 0 .. stress_level {
			path := test_paths[stress_matches % test_paths.len]
			if _ := app.fast_router.match_route('GET', path) {
				stress_matches++
			}
		}
	}
	
	stress_time := time.since(start_time)
	stress_avg := f64(stress_time.microseconds()) / f64(stress_matches)
	stress_throughput := f64(stress_matches) / stress_time.seconds()
	
	println('    压力测试: ${stress_matches}次匹配')
	println('    总时间: ${stress_time}')
	println('    平均时间: ${stress_avg:.3f}μs')
	println('    吞吐量: ${stress_throughput:.0f} 请求/秒')
	
	if stress_avg < 10.0 {
		println('    ✅ 高压力下性能优秀')
	} else if stress_avg < 50.0 {
		println('    ✅ 高压力下性能良好')
	} else {
		println('    ⚠️  高压力下性能需要优化')
	}
}