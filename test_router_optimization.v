import hono
import time
import net.http

fn main() {
	println('=== 路由匹配性能优化测试 ===')
	
	// 测试1: 正则表达式编译缓存效果
	test_regex_compilation_cache()
	
	// 测试2: 路由匹配性能对比
	test_route_matching_performance()
	
	// 测试3: 缓存预热效果
	test_cache_warmup_effect()
	
	// 测试4: 批量路由添加性能
	test_batch_route_addition()
	
	println('✅ 所有路由优化测试完成')
}

fn test_regex_compilation_cache() {
	println('\n📊 测试正则表达式编译缓存效果...')
	
	mut optimized_router := hono.new_optimized_router()
	
	// 添加一些动态路由
	test_routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/api/v1/users/:user_id/posts/:post_id',
		'/files/:category/:filename',
		'/search/*query'
	]
	
	// 测试路由编译时间
	start_time := time.now()
	for i, route in test_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		optimized_router.add_route('GET', handler, '')
	}
	compilation_time := time.since(start_time)
	
	println('  路由编译时间: ${compilation_time}')
	println('  编译缓存大小: ${optimized_router.compiled_cache.len}')
	
	// 测试匹配性能（使用缓存的编译结果）
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/api/v1/users/101/posts/202',
		'/files/images/photo.jpg',
		'/search/test-query'
	]
	
	start_time2 := time.now()
	mut matches := 0
	for _ in 0 .. 1000 {  // 减少测试次数
		for path in test_paths {
			if handler, params := optimized_router.match_route('GET', path) {
				matches++
			}
		}
	}
	matching_time := time.since(start_time2)
	
	println('  匹配测试 (1000次 × ${test_paths.len}路径): ${matching_time}')
	println('  成功匹配: ${matches}')
	if matching_time.microseconds() > 0 {
		println('  平均每次匹配: ${matching_time.microseconds() / (1000 * test_paths.len)}μs')
	}
}

fn test_route_matching_performance() {
	println('\n📊 测试路由匹配性能对比...')
	
	// 创建优化路由器
	mut optimized_router := hono.new_optimized_router()
	
	// 创建传统路由器（用于对比）
	mut traditional_router := hono.new_context_hybrid_router()
	
	// 添加相同的路由到两个路由器
	test_routes := []string{}
	for i in 0 .. 100 {
		route := '/api/v${i}/users/:id/posts/:post_id'
		test_routes << route
		
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		
		optimized_router.add_route('GET', handler, '')
		traditional_router.add_route('GET', handler, '')
	}
	
	// 测试路径
	test_paths := [
		'/api/v1/users/123/posts/456',
		'/api/v50/users/789/posts/101',
		'/api/v99/users/111/posts/222'
	]
	
	// 测试优化路由器性能
	start_time1 := time.now()
	mut optimized_matches := 0
	for _ in 0 .. 50000 {
		for path in test_paths {
			if handler, params := optimized_router.match_route('GET', path) {
				optimized_matches++
			}
		}
	}
	optimized_time := time.since(start_time1)
	
	// 测试传统路由器性能
	start_time2 := time.now()
	mut traditional_matches := 0
	for _ in 0 .. 50000 {
		for path in test_paths {
			if handler, params := traditional_router.match_route('GET', path) {
				traditional_matches++
			}
		}
	}
	traditional_time := time.since(start_time2)
	
	println('  优化路由器 (50000次 × ${test_paths.len}路径): ${optimized_time}')
	println('  传统路由器 (50000次 × ${test_paths.len}路径): ${traditional_time}')
	
	if traditional_time.milliseconds() > 0 {
		improvement := f64(traditional_time.milliseconds()) / f64(optimized_time.milliseconds())
		println('  性能提升: ${improvement:.2f}x')
	}
	
	println('  优化路由器匹配: ${optimized_matches}')
	println('  传统路由器匹配: ${traditional_matches}')
	
	// 显示缓存统计
	optimized_router.analyze_performance()
}

fn test_cache_warmup_effect() {
	println('\n📊 测试缓存预热效果...')
	
	mut router := hono.new_optimized_router()
	
	// 添加路由
	for i in 0 .. 50 {
		route := '/api/users/:id/items/:item_id'
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	common_paths := [
		'/api/users/123/items/456',
		'/api/users/789/items/101',
		'/api/users/111/items/222'
	]
	
	// 测试预热前的性能
	start_time1 := time.now()
	for _ in 0 .. 10000 {
		for path in common_paths {
			router.match_route('GET', path) or { continue }
		}
	}
	before_warmup := time.since(start_time1)
	
	// 预热缓存
	router.warmup_cache(common_paths)
	
	// 测试预热后的性能
	start_time2 := time.now()
	for _ in 0 .. 10000 {
		for path in common_paths {
			router.match_route('GET', path) or { continue }
		}
	}
	after_warmup := time.since(start_time2)
	
	println('  预热前 (10000次 × ${common_paths.len}路径): ${before_warmup}')
	println('  预热后 (10000次 × ${common_paths.len}路径): ${after_warmup}')
	
	if before_warmup.milliseconds() > 0 {
		improvement := f64(before_warmup.milliseconds()) / f64(after_warmup.milliseconds())
		println('  预热效果: ${improvement:.2f}x 提升')
	}
	
	router.analyze_performance()
}

fn test_batch_route_addition() {
	println('\n📊 测试批量路由添加性能...')
	
	mut router := hono.new_optimized_router()
	
	// 准备大量路由
	mut routes := []hono.RouteDefinition{}
	for i in 0 .. 1000 {
		handler := hono.ContextHandler{
			path: '/api/v1/resource${i}/:id'
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		routes << hono.RouteDefinition{
			method: 'GET'
			handler: handler
			base_path: ''
		}
	}
	
	// 测试批量添加性能
	start_time := time.now()
	router.add_routes_batch(routes)
	batch_time := time.since(start_time)
	
	println('  批量添加1000个路由: ${batch_time}')
	println('  平均每个路由: ${batch_time.microseconds() / 1000}μs')
	println('  编译缓存大小: ${router.compiled_cache.len}')
	
	// 测试健康检查
	if router.health_check() {
		println('  ✅ 路由器健康检查通过')
	} else {
		println('  ❌ 路由器健康检查失败')
	}
}