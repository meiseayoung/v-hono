import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 路由性能百万级基准测试 ===')
	
	// 测试1: 百万次路由匹配 - 小规模路由
	test_million_matches_small_scale()
	
	// 测试2: 百万次路由匹配 - 中等规模路由
	test_million_matches_medium_scale()
	
	// 测试3: 百万次复杂路由匹配
	test_million_complex_routes()
	
	println('\n🎯 百万级基准测试完成')
}

fn test_million_matches_small_scale() {
	println('\n📊 百万次路由匹配 - 小规模 (10个动态路由)...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加10个动态路由
	dynamic_routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/api/v1/users/:user_id/posts/:post_id',
		'/files/:category/:filename',
		'/search/:query',
		'/admin/users/:id/settings',
		'/api/v2/projects/:project_id/tasks/:task_id',
		'/shop/products/:id/reviews/:review_id',
		'/blog/:year/:month/:slug',
		'/docs/:section/:page'
	]
	
	for route in dynamic_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	// 测试路径
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/api/v1/users/101/posts/202',
		'/files/images/photo.jpg',
		'/search/test-query',
		'/admin/users/555/settings',
		'/api/v2/projects/777/tasks/888',
		'/shop/products/999/reviews/111',
		'/blog/2023/12/hello-world',
		'/docs/api/authentication'
	]
	
	iterations := 100000  // 100万次 = 100000 * 10路径
	total_matches := iterations * test_paths.len
	
	println('  准备进行 ${total_matches} 次路由匹配测试...')
	
	start_time := time.now()
	mut matches := 0
	for i in 0 .. iterations {
		for path in test_paths {
			if _ := router.match_route('GET', path) {
				matches++
			}
		}
		if i % 10000 == 0 {
			print('.')
		}
	}
	total_time := time.since(start_time)
	println('')
	
	avg_time := f64(total_time.microseconds()) / f64(matches)
	qps := f64(matches) / (f64(total_time.milliseconds()) / 1000.0)
	
	println('  📊 小规模路由性能结果:')
	println('    总匹配次数: ${matches}')
	println('    总耗时: ${total_time}')
	println('    平均每次匹配: ${avg_time:.2f}μs')
	println('    吞吐量: ${qps:.0f} 请求/秒')
	
	if avg_time < 15.0 {
		println('    ✅ 性能优秀 (< 15μs)')
	} else if avg_time < 50.0 {
		println('    ✅ 性能良好 (< 50μs)')
	} else {
		println('    ⚠️ 性能需要优化 (>= 50μs)')
	}
}

fn test_million_matches_medium_scale() {
	println('\n📊 百万次路由匹配 - 中等规模 (50个动态路由)...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加50个动态路由
	for i in 0 .. 50 {
		route := '/api/v${i}/resources/:id/items/:item_id'
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	// 测试路径
	test_paths := [
		'/api/v1/resources/123/items/456',
		'/api/v10/resources/789/items/101',
		'/api/v25/resources/111/items/222',
		'/api/v35/resources/333/items/444',
		'/api/v49/resources/555/items/666'
	]
	
	iterations := 200000  // 100万次 = 200000 * 5路径
	total_matches := iterations * test_paths.len
	
	println('  准备进行 ${total_matches} 次路由匹配测试...')
	
	start_time := time.now()
	mut matches := 0
	for i in 0 .. iterations {
		for path in test_paths {
			if _ := router.match_route('GET', path) {
				matches++
			}
		}
		if i % 20000 == 0 {
			print('.')
		}
	}
	total_time := time.since(start_time)
	println('')
	
	avg_time := f64(total_time.microseconds()) / f64(matches)
	qps := f64(matches) / (f64(total_time.milliseconds()) / 1000.0)
	
	println('  📊 中等规模路由性能结果:')
	println('    总匹配次数: ${matches}')
	println('    总耗时: ${total_time}')
	println('    平均每次匹配: ${avg_time:.2f}μs')
	println('    吞吐量: ${qps:.0f} 请求/秒')
	
	if avg_time < 15.0 {
		println('    ✅ 性能优秀 (< 15μs)')
	} else if avg_time < 50.0 {
		println('    ✅ 性能良好 (< 50μs)')
	} else {
		println('    ⚠️ 性能需要优化 (>= 50μs)')
	}
}

fn test_million_complex_routes() {
	println('\n📊 百万次复杂路由匹配测试...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加复杂的动态路由
	complex_routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',
		'/shop/:category/:subcategory/products/:product_id/reviews/:review_id',
		'/admin/:module/:action/:resource_type/:resource_id',
		'/files/:year/:month/:day/:category/:filename',
		'/docs/:language/:version/:section/:subsection/:page'
	]
	
	for route in complex_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	// 复杂测试路径
	test_paths := [
		'/api/v1/users/123/posts/456/comments/789',
		'/shop/electronics/phones/products/999/reviews/111',
		'/admin/users/edit/profile/555',
		'/files/2023/12/26/images/photo.jpg',
		'/docs/en/v2/api/authentication/oauth'
	]
	
	iterations := 200000  // 100万次 = 200000 * 5路径
	total_matches := iterations * test_paths.len
	
	println('  准备进行 ${total_matches} 次复杂路由匹配测试...')
	
	start_time := time.now()
	mut matches := 0
	for i in 0 .. iterations {
		for path in test_paths {
			if _ := router.match_route('GET', path) {
				matches++
			}
		}
		if i % 20000 == 0 {
			print('.')
		}
	}
	total_time := time.since(start_time)
	println('')
	
	avg_time := f64(total_time.microseconds()) / f64(matches)
	qps := f64(matches) / (f64(total_time.milliseconds()) / 1000.0)
	
	println('  📊 复杂路由性能结果:')
	println('    总匹配次数: ${matches}')
	println('    总耗时: ${total_time}')
	println('    平均每次匹配: ${avg_time:.2f}μs')
	println('    吞吐量: ${qps:.0f} 请求/秒')
	
	if avg_time < 15.0 {
		println('    ✅ 性能优秀 (< 15μs)')
	} else if avg_time < 50.0 {
		println('    ✅ 性能良好 (< 50μs)')
	} else {
		println('    ⚠️ 性能需要优化 (>= 50μs)')
	}
	
	// 显示缓存统计
	println('\n  📈 缓存统计信息:')
	cache_size, cache_capacity := router.get_cache_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	
	println('    路由缓存: ${cache_size}/${cache_capacity}')
	println('    正则缓存: ${regex_compiled}/${regex_total} 已编译')
	
	router.analyze_router_performance()
}
