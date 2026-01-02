import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 动态路由性能压力测试 ===')
	
	// 测试1: 大规模动态路由性能
	test_large_scale_performance()
	
	// 测试2: 高频访问路由性能
	test_high_frequency_performance()
	
	// 测试3: 混合路由类型性能
	test_mixed_route_performance()
	
	// 测试4: 并发性能模拟
	test_concurrent_performance()
	
	println('✅ 动态路由性能压力测试完成')
}

fn test_large_scale_performance() {
	println('\n📊 大规模动态路由性能测试...')
	
	mut app := hono.Hono.new()
	
	// 创建大量动态路由
	route_count := 1000
	println('  创建 ${route_count} 个动态路由...')
	
	for i in 0 .. route_count {
		// 生成不同复杂度的路由
		complexity := i % 4
		mut route := ''
		
		match complexity {
			0 { route = '/simple/:id${i}' }
			1 { route = '/api/v${i % 3}/users/:id${i}' }
			2 { route = '/api/v${i % 3}/users/:user_id/posts/:post_id${i}' }
			3 { route = '/complex/:region/:city/stores/:store_id/products/:category/:product_id${i}' }
			else { route = '/default/:id${i}' }
		}
		
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
	}
	
	println('  路由创建完成，开始性能测试...')
	
	// 生成测试路径
	mut test_paths := []string{}
	for i in 0 .. 100 {
		complexity := i % 4
		mut path := ''
		
		match complexity {
			0 { path = '/simple/id${i}' }
			1 { path = '/api/v${i % 3}/users/user${i}' }
			2 { path = '/api/v${i % 3}/users/user${i}/posts/post${i}' }
			3 { path = '/complex/region${i}/city${i}/stores/store${i}/products/cat${i}/prod${i}' }
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
	success_rate := f64(match_count) / f64(total_matches) * 100.0
	
	println('  大规模路由性能结果:')
	println('    路由数量: ${route_count}')
	println('    测试路径: ${test_paths.len}')
	println('    总匹配次数: ${total_matches}')
	println('    成功匹配: ${match_count}')
	println('    成功率: ${success_rate:.1f}%')
	println('    总时间: ${total_time}')
	println('    平均时间: ${avg_time:.3f}μs')
	println('    吞吐量: ${throughput:.0f} 请求/秒')
	
	if avg_time < 10.0 {
		println('    🏆 性能等级: 优秀 (< 10μs)')
	} else if avg_time < 50.0 {
		println('    ✅ 性能等级: 良好 (< 50μs)')
	} else {
		println('    ⚠️  性能等级: 一般 (>= 50μs)')
	}
}

fn test_high_frequency_performance() {
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
	mut weighted_paths := []string{}
	
	// 最高频路由 (40%)
	for _ in 0 .. 200 {
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
	
	iterations := 500
	
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
	println('\n  缓存效果对比:')
	
	// 清除缓存后的性能
	app.clear_cache()
	start_time_no_cache := time.now()
	mut no_cache_matches := 0
	
	for _ in 0 .. 100 {
		app.clear_cache()
		for i in 0 .. 10 {
			path := weighted_paths[i]
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
		for i in 0 .. 10 {
			path := weighted_paths[i]
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

fn test_mixed_route_performance() {
	println('\n📊 混合路由类型性能测试...')
	
	mut app := hono.Hono.new()
	
	// 混合不同类型的路由
	static_routes := [
		'/static/home',
		'/static/about',
		'/static/contact',
		'/static/help',
		'/static/terms'
	]
	
	simple_dynamic_routes := [
		'/users/:id',
		'/posts/:id',
		'/products/:id',
		'/orders/:id',
		'/files/:id'
	]
	
	complex_dynamic_routes := [
		'/api/:version/users/:id',
		'/api/:version/posts/:id/comments',
		'/users/:id/posts/:post_id',
		'/users/:id/settings/:section',
		'/projects/:id/files/:file_id'
	]
	
	// 添加所有路由
	for route in static_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('static response')
		})
	}
	
	for route in simple_dynamic_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('simple dynamic response')
		})
	}
	
	for route in complex_dynamic_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('complex dynamic response')
		})
	}
	
	// 对应的测试路径
	static_test_paths := [
		'/static/home',
		'/static/about',
		'/static/contact',
		'/static/help',
		'/static/terms'
	]
	
	simple_test_paths := [
		'/users/123',
		'/posts/456',
		'/products/789',
		'/orders/101',
		'/files/202'
	]
	
	complex_test_paths := [
		'/api/v1/users/606',
		'/api/v2/posts/707/comments',
		'/users/808/posts/909',
		'/users/111/settings/privacy',
		'/projects/222/files/333'
	]
	
	iterations := 2000
	
	println('  混合路由类型性能测试:')
	
	// 测试静态路由
	start_time1 := time.now()
	mut static_matches := 0
	
	for _ in 0 .. iterations {
		for path in static_test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				static_matches++
			}
		}
	}
	
	static_time := time.since(start_time1)
	static_avg := f64(static_time.microseconds()) / f64(static_matches)
	
	// 测试简单动态路由
	start_time2 := time.now()
	mut simple_matches := 0
	
	for _ in 0 .. iterations {
		for path in simple_test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				simple_matches++
			}
		}
	}
	
	simple_time := time.since(start_time2)
	simple_avg := f64(simple_time.microseconds()) / f64(simple_matches)
	
	// 测试复杂动态路由
	start_time3 := time.now()
	mut complex_matches := 0
	
	for _ in 0 .. iterations {
		for path in complex_test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				complex_matches++
			}
		}
	}
	
	complex_time := time.since(start_time3)
	complex_avg := f64(complex_time.microseconds()) / f64(complex_matches)
	
	println('    静态路由: ${static_matches}次匹配, 平均${static_avg:.3f}μs')
	println('    简单动态路由: ${simple_matches}次匹配, 平均${simple_avg:.3f}μs')
	println('    复杂动态路由: ${complex_matches}次匹配, 平均${complex_avg:.3f}μs')
	
	// 整体混合测试
	println('\n  整体混合性能测试:')
	
	mut all_test_paths := []string{}
	all_test_paths << static_test_paths
	all_test_paths << simple_test_paths
	all_test_paths << complex_test_paths
	
	start_time := time.now()
	mut total_matches := 0
	
	for _ in 0 .. iterations {
		for path in all_test_paths {
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

fn test_concurrent_performance() {
	println('\n📊 并发性能模拟测试...')
	
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
	
	stress_level := 5000
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
	
	if stress_avg < 5.0 {
		println('    🏆 高压力下性能卓越 (< 5μs)')
	} else if stress_avg < 10.0 {
		println('    ✅ 高压力下性能优秀 (< 10μs)')
	} else if stress_avg < 50.0 {
		println('    ✅ 高压力下性能良好 (< 50μs)')
	} else {
		println('    ⚠️  高压力下性能需要优化 (>= 50μs)')
	}
	
	// 显示最终统计
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('    最终路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}