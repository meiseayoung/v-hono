import hono
import time
import net.http

fn main() {
	println('=== 最终优化性能基准测试 ===')
	
	// 测试1: 单路由性能对比（FastRouter vs HybridRouter）
	test_single_route_comparison()
	
	// 测试2: 多路由性能对比
	test_multiple_routes_comparison()
	
	// 测试3: 大规模路由性能对比
	test_large_scale_comparison()
	
	// 测试4: 实际应用场景性能测试
	test_real_world_scenario()
	
	// 测试5: 内存使用对比
	test_memory_usage_comparison()
	
	println('✅ 最终优化性能基准测试完成')
}

fn test_single_route_comparison() {
	println('\n📊 单路由性能对比 (FastRouter vs HybridRouter)...')
	
	route_path := '/api/:version/users/:user_id/posts/:post_id'
	test_path := '/api/v1/users/123/posts/456'
	
	// 创建使用FastRouter的应用
	mut app_fast := hono.Hono.new()
	app_fast.set_fast_router_enabled(true)
	app_fast.get(route_path, fn (mut c hono.Context) http.Response {
		return c.text('fast router response')
	})
	
	// 创建使用HybridRouter的应用
	mut app_hybrid := hono.Hono.new()
	app_hybrid.set_fast_router_enabled(false)
	app_hybrid.get(route_path, fn (mut c hono.Context) http.Response {
		return c.text('hybrid router response')
	})
	
	iterations := 10000
	
	// 测试FastRouter（第一次匹配）
	app_fast.clear_cache()
	
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		app_fast.clear_cache()
		if _ := app_fast.fast_router.match_route('GET', test_path) {
			fast_matches++
		}
	}
	fast_time := time.since(start_time1)
	
	// 测试HybridRouter（第一次匹配）
	app_hybrid.clear_cache()
	
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		app_hybrid.clear_cache()
		if _ := app_hybrid.context_hybrid_router.match_route('GET', test_path) {
			hybrid_matches++
		}
	}
	hybrid_time := time.since(start_time2)
	
	println('  第一次匹配性能 (${iterations}次):')
	if fast_matches > 0 {
		avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
		println('    FastRouter: ${fast_time} (平均 ${avg_fast:.3f}μs)')
	}
	
	if hybrid_matches > 0 {
		avg_hybrid := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		println('    HybridRouter: ${hybrid_time} (平均 ${avg_hybrid:.3f}μs)')
		
		if fast_matches > 0 {
			avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
			if avg_hybrid > avg_fast {
				improvement := avg_hybrid / avg_fast
				println('    🚀 FastRouter提升: ${improvement:.2f}x')
			}
		}
	}
	
	// 测试缓存匹配性能
	start_time3 := time.now()
	mut fast_cache_matches := 0
	for _ in 0 .. iterations {
		if _ := app_fast.fast_router.match_route('GET', test_path) {
			fast_cache_matches++
		}
	}
	fast_cache_time := time.since(start_time3)
	
	start_time4 := time.now()
	mut hybrid_cache_matches := 0
	for _ in 0 .. iterations {
		if _ := app_hybrid.context_hybrid_router.match_route('GET', test_path) {
			hybrid_cache_matches++
		}
	}
	hybrid_cache_time := time.since(start_time4)
	
	println('\n  缓存匹配性能 (${iterations}次):')
	if fast_cache_matches > 0 {
		avg_fast_cache := f64(fast_cache_time.microseconds()) / f64(fast_cache_matches)
		println('    FastRouter: ${fast_cache_time} (平均 ${avg_fast_cache:.3f}μs)')
	}
	
	if hybrid_cache_matches > 0 {
		avg_hybrid_cache := f64(hybrid_cache_time.microseconds()) / f64(hybrid_cache_matches)
		println('    HybridRouter: ${hybrid_cache_time} (平均 ${avg_hybrid_cache:.3f}μs)')
		
		if fast_cache_matches > 0 {
			avg_fast_cache := f64(fast_cache_time.microseconds()) / f64(fast_cache_matches)
			if avg_hybrid_cache > avg_fast_cache {
				improvement := avg_hybrid_cache / avg_fast_cache
				println('    🚀 FastRouter提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_multiple_routes_comparison() {
	println('\n📊 多路由性能对比...')
	
	// 定义测试路由
	test_routes := [
		{
			'route': '/users/:id'
			'path': '/users/123'
		},
		{
			'route': '/users/:id/posts/:post_id'
			'path': '/users/123/posts/456'
		},
		{
			'route': '/api/:version/users/:user_id/posts/:post_id'
			'path': '/api/v1/users/123/posts/456'
		},
		{
			'route': '/shop/:category/:subcategory/products/:product_id'
			'path': '/shop/electronics/phones/products/999'
		},
		{
			'route': '/files/:year/:month/:day/:filename'
			'path': '/files/2023/12/26/document.pdf'
		}
	]
	
	// 创建FastRouter应用
	mut app_fast := hono.Hono.new()
	app_fast.set_fast_router_enabled(true)
	for route_info in test_routes {
		app_fast.get(route_info['route'], fn (mut c hono.Context) http.Response {
			return c.text('fast response')
		})
	}
	
	// 创建HybridRouter应用
	mut app_hybrid := hono.Hono.new()
	app_hybrid.set_fast_router_enabled(false)
	for route_info in test_routes {
		app_hybrid.get(route_info['route'], fn (mut c hono.Context) http.Response {
			return c.text('hybrid response')
		})
	}
	
	iterations := 5000
	
	// 测试FastRouter
	app_fast.clear_cache()
	
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		for route_info in test_routes {
			if _ := app_fast.fast_router.match_route('GET', route_info['path']) {
				fast_matches++
			}
		}
	}
	fast_time := time.since(start_time1)
	
	// 测试HybridRouter
	app_hybrid.clear_cache()
	
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		for route_info in test_routes {
			if _ := app_hybrid.context_hybrid_router.match_route('GET', route_info['path']) {
				hybrid_matches++
			}
		}
	}
	hybrid_time := time.since(start_time2)
	
	println('  多路由匹配性能 (${iterations}轮 × ${test_routes.len}路由):')
	if fast_matches > 0 {
		avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
		println('    FastRouter: ${fast_time} (平均 ${avg_fast:.3f}μs)')
	}
	
	if hybrid_matches > 0 {
		avg_hybrid := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		println('    HybridRouter: ${hybrid_time} (平均 ${avg_hybrid:.3f}μs)')
		
		if fast_matches > 0 {
			avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
			if avg_hybrid > avg_fast {
				improvement := avg_hybrid / avg_fast
				println('    🚀 FastRouter提升: ${improvement:.2f}x')
			}
		}
	}
	
	// 显示统计信息
	println('\n  路由统计:')
	fast_static, fast_dynamic, fast_cache, _ := app_fast.get_router_stats()
	hybrid_static, hybrid_dynamic, hybrid_cache, _ := app_hybrid.get_router_stats()
	
	println('    FastRouter - 静态: ${fast_static}, 动态: ${fast_dynamic}, 缓存: ${fast_cache}')
	println('    HybridRouter - 静态: ${hybrid_static}, 动态: ${hybrid_dynamic}, 缓存: ${hybrid_cache}')
}

fn test_large_scale_comparison() {
	println('\n📊 大规模路由性能对比...')
	
	// 创建大量路由
	mut app_fast := hono.Hono.new()
	app_fast.set_fast_router_enabled(true)
	
	mut app_hybrid := hono.Hono.new()
	app_hybrid.set_fast_router_enabled(false)
	
	route_count := 100
	
	for i in 0 .. route_count {
		route_path := '/api/v${i}/resources/:id/items/:item_id'
		
		app_fast.get(route_path, fn (mut c hono.Context) http.Response {
			return c.text('fast response')
		})
		
		app_hybrid.get(route_path, fn (mut c hono.Context) http.Response {
			return c.text('hybrid response')
		})
	}
	
	// 测试路径
	test_paths := [
		'/api/v1/resources/123/items/456',
		'/api/v25/resources/789/items/101',
		'/api/v50/resources/111/items/222',
		'/api/v75/resources/333/items/444',
		'/api/v99/resources/555/items/666'
	]
	
	iterations := 2000
	
	// 测试FastRouter
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := app_fast.fast_router.match_route('GET', path) {
				fast_matches++
			}
		}
	}
	fast_time := time.since(start_time1)
	
	// 测试HybridRouter
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := app_hybrid.context_hybrid_router.match_route('GET', path) {
				hybrid_matches++
			}
		}
	}
	hybrid_time := time.since(start_time2)
	
	println('  大规模路由匹配 (${route_count}个路由, ${iterations}轮 × ${test_paths.len}路径):')
	if fast_matches > 0 {
		avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
		println('    FastRouter: ${fast_time} (平均 ${avg_fast:.3f}μs)')
	}
	
	if hybrid_matches > 0 {
		avg_hybrid := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		println('    HybridRouter: ${hybrid_time} (平均 ${avg_hybrid:.3f}μs)')
		
		if fast_matches > 0 {
			avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
			if avg_hybrid > avg_fast {
				improvement := avg_hybrid / avg_fast
				println('    🚀 FastRouter提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_real_world_scenario() {
	println('\n📊 实际应用场景性能测试...')
	
	// 模拟真实的Web应用路由
	mut app_fast := hono.Hono.new()
	app_fast.set_fast_router_enabled(true)
	
	mut app_hybrid := hono.Hono.new()
	app_hybrid.set_fast_router_enabled(false)
	
	// 添加常见的Web应用路由
	real_routes := [
		// 用户管理
		'/users',
		'/users/:id',
		'/users/:id/profile',
		'/users/:id/settings',
		// API路由
		'/api/v1/users',
		'/api/v1/users/:id',
		'/api/v1/users/:id/posts',
		'/api/v1/users/:id/posts/:post_id',
		// 文件管理
		'/files/:category/:filename',
		'/files/:year/:month/:day/:filename',
		// 商店功能
		'/shop/categories/:category',
		'/shop/categories/:category/products',
		'/shop/categories/:category/products/:product_id',
		// 管理后台
		'/admin/dashboard',
		'/admin/users/:id',
		'/admin/reports/:type/:date'
	]
	
	for route in real_routes {
		app_fast.get(route, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
		
		app_hybrid.get(route, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
	}
	
	// 模拟真实的访问模式（某些路由访问频率更高）
	test_scenarios := [
		// 高频访问
		{
			'path': '/api/v1/users/123'
			'weight': '30'
		},
		{
			'path': '/users/456/profile'
			'weight': '25'
		},
		// 中频访问
		{
			'path': '/shop/categories/electronics/products/999'
			'weight': '15'
		},
		{
			'path': '/files/2023/12/26/document.pdf'
			'weight': '10'
		},
		// 低频访问
		{
			'path': '/admin/users/789'
			'weight': '5'
		},
		{
			'path': '/admin/reports/sales/2023-12-26'
			'weight': '3'
		}
	]
	
	// 构建加权测试路径
	mut weighted_paths := []string{}
	for scenario in test_scenarios {
		weight := scenario['weight'].int()
		for _ in 0 .. weight {
			weighted_paths << scenario['path']
		}
	}
	
	iterations := 1000
	
	// 测试FastRouter
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		for path in weighted_paths {
			if _ := app_fast.fast_router.match_route('GET', path) {
				fast_matches++
			}
		}
	}
	fast_time := time.since(start_time1)
	
	// 测试HybridRouter
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		for path in weighted_paths {
			if _ := app_hybrid.context_hybrid_router.match_route('GET', path) {
				hybrid_matches++
			}
		}
	}
	hybrid_time := time.since(start_time2)
	
	println('  真实应用场景 (${real_routes.len}个路由, ${iterations}轮 × ${weighted_paths.len}加权请求):')
	if fast_matches > 0 {
		avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
		println('    FastRouter: ${fast_time} (平均 ${avg_fast:.3f}μs)')
	}
	
	if hybrid_matches > 0 {
		avg_hybrid := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		println('    HybridRouter: ${hybrid_time} (平均 ${avg_hybrid:.3f}μs)')
		
		if fast_matches > 0 {
			avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
			if avg_hybrid > avg_fast {
				improvement := avg_hybrid / avg_fast
				println('    🚀 FastRouter提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_memory_usage_comparison() {
	println('\n📊 内存使用对比...')
	
	// 创建大量路由来测试内存使用
	mut app_fast := hono.Hono.new()
	app_fast.set_fast_router_enabled(true)
	
	mut app_hybrid := hono.Hono.new()
	app_hybrid.set_fast_router_enabled(false)
	
	route_count := 1000
	
	println('  创建 ${route_count} 个路由...')
	
	for i in 0 .. route_count {
		route_path := '/api/v${i % 10}/category${i % 20}/resource${i % 50}/:id/item/:item_id'
		
		app_fast.get(route_path, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
		
		app_hybrid.get(route_path, fn (mut c hono.Context) http.Response {
			return c.text('response')
		})
	}
	
	// 显示路由统计
	fast_static, fast_dynamic, fast_cache, _ := app_fast.get_router_stats()
	hybrid_static, hybrid_dynamic, hybrid_cache, _ := app_hybrid.get_router_stats()
	
	println('  路由统计:')
	println('    FastRouter - 静态: ${fast_static}, 动态: ${fast_dynamic}, 缓存: ${fast_cache}')
	println('    HybridRouter - 静态: ${hybrid_static}, 动态: ${hybrid_dynamic}, 缓存: ${hybrid_cache}')
	
	// 测试缓存增长
	test_paths := [
		'/api/v1/category5/resource10/123/item/456',
		'/api/v2/category8/resource25/789/item/101',
		'/api/v3/category12/resource30/111/item/222'
	]
	
	println('\n  测试缓存增长...')
	
	for i, path in test_paths {
		app_fast.fast_router.match_route('GET', path)
		app_hybrid.context_hybrid_router.match_route('GET', path)
		
		_, _, fast_c, _ := app_fast.get_router_stats()
		_, _, hybrid_c, _ := app_hybrid.get_router_stats()
		
		println('    第${i+1}次匹配后:')
		println('      FastRouter缓存: ${fast_c}')
		println('      HybridRouter缓存: ${hybrid_c}')
	}
}