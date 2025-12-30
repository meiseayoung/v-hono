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
	
	println('\n✅ 所有路由优化测试完成')
}

fn test_regex_compilation_cache() {
	println('\n📊 测试正则表达式编译缓存效果...')
	
	mut fast_router := hono.FastRouter.new()
	
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
	for route in test_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		fast_router.add_route('GET', handler, '') or {
			println('  ⚠️ 添加路由失败: ${route}')
		}
	}
	compilation_time := time.since(start_time)
	
	static_count, dynamic_count, cache_count := fast_router.get_stats()
	println('  路由编译时间: ${compilation_time}')
	println('  静态路由: ${static_count}, 动态路由: ${dynamic_count}, 缓存: ${cache_count}')
	
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
	for _ in 0 .. 1000 {
		for path in test_paths {
			if _ := fast_router.match_route('GET', path) {
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
	
	// 创建 FastRouter
	mut fast_router := hono.FastRouter.new()
	
	// 创建 HybridRouter（用于对比）
	mut hybrid_router := hono.ContextHybridRouter.new()
	
	// 添加相同的路由到两个路由器
	mut test_routes := []string{}
	for i in 0 .. 100 {
		route := '/api/v${i}/users/:id/posts/:post_id'
		test_routes << route
		
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		
		fast_router.add_route('GET', handler, '') or {}
		hybrid_router.add_route('GET', handler, '')
	}
	
	// 测试路径
	test_paths := [
		'/api/v1/users/123/posts/456',
		'/api/v50/users/789/posts/101',
		'/api/v99/users/111/posts/222'
	]
	
	// 测试 FastRouter 性能
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. 50000 {
		for path in test_paths {
			if _ := fast_router.match_route('GET', path) {
				fast_matches++
			}
		}
	}
	fast_time := time.since(start_time1)
	
	// 测试 HybridRouter 性能
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. 50000 {
		for path in test_paths {
			if _ := hybrid_router.match_route('GET', path) {
				hybrid_matches++
			}
		}
	}
	hybrid_time := time.since(start_time2)
	
	println('  FastRouter (50000次 × ${test_paths.len}路径): ${fast_time}')
	println('  HybridRouter (50000次 × ${test_paths.len}路径): ${hybrid_time}')
	
	if hybrid_time.milliseconds() > 0 && fast_time.milliseconds() > 0 {
		improvement := f64(hybrid_time.milliseconds()) / f64(fast_time.milliseconds())
		println('  性能对比: ${improvement:.2f}x')
	}
	
	println('  FastRouter 匹配: ${fast_matches}')
	println('  HybridRouter 匹配: ${hybrid_matches}')
	
	// 显示性能分析
	fast_router.analyze_performance()
}

fn test_cache_warmup_effect() {
	println('\n📊 测试缓存预热效果...')
	
	mut router := hono.FastRouter.new()
	
	// 添加路由
	for _ in 0 .. 50 {
		route := '/api/users/:id/items/:item_id'
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {}
	}
	
	common_paths := [
		'/api/users/123/items/456',
		'/api/users/789/items/101',
		'/api/users/111/items/222'
	]
	
	// 清除缓存，测试预热前的性能
	router.clear_cache()
	
	start_time1 := time.now()
	for _ in 0 .. 10000 {
		for path in common_paths {
			_ := router.match_route('GET', path) or { continue }
		}
	}
	before_warmup := time.since(start_time1)
	
	// 清除缓存并预热
	router.clear_cache()
	router.warmup_cache(common_paths, 'GET')
	
	// 测试预热后的性能
	start_time2 := time.now()
	for _ in 0 .. 10000 {
		for path in common_paths {
			_ := router.match_route('GET', path) or { continue }
		}
	}
	after_warmup := time.since(start_time2)
	
	println('  预热前 (10000次 × ${common_paths.len}路径): ${before_warmup}')
	println('  预热后 (10000次 × ${common_paths.len}路径): ${after_warmup}')
	
	if before_warmup.milliseconds() > 0 && after_warmup.milliseconds() > 0 {
		improvement := f64(before_warmup.milliseconds()) / f64(after_warmup.milliseconds())
		println('  预热效果: ${improvement:.2f}x')
	}
	
	router.analyze_performance()
}

fn test_batch_route_addition() {
	println('\n📊 测试批量路由添加性能...')
	
	mut router := hono.FastRouter.new()
	
	// 测试批量添加性能
	start_time := time.now()
	for i in 0 .. 1000 {
		handler := hono.ContextHandler{
			path: '/api/v1/resource${i}/:id'
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {}
	}
	batch_time := time.since(start_time)
	
	static_count, dynamic_count, cache_count := router.get_stats()
	
	println('  批量添加1000个路由: ${batch_time}')
	println('  平均每个路由: ${batch_time.microseconds() / 1000}μs')
	println('  路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
	
	// 测试健康检查
	if router.is_healthy() {
		println('  ✅ 路由器健康检查通过')
	} else {
		println('  ❌ 路由器健康检查失败')
	}
}
