import hono
import time
import net.http

fn main() {
	println('=== 快速路由器性能基准测试 ===')
	
	// 测试1: 单路由性能对比
	test_single_route_performance()
	
	// 测试2: 多路由性能对比
	test_multiple_routes_performance()
	
	// 测试3: 大规模路由性能对比
	test_large_scale_performance()
	
	// 测试4: 缓存效果对比
	test_cache_effectiveness()
	
	println('✅ 快速路由器基准测试完成')
}

fn test_single_route_performance() {
	println('\n📊 单路由性能对比...')
	
	route_path := '/api/:version/users/:user_id/posts/:post_id'
	test_path := '/api/v1/users/123/posts/456'
	
	// 创建原始路由器
	mut old_router := hono.ContextHybridRouter.new()
	old_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	old_router.add_route('GET', old_handler, '')
	
	// 创建快速路由器
	mut fast_router := hono.FastRouter.new()
	fast_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	fast_router.add_route('GET', fast_handler, '') or {
		println('  ❌ 快速路由器添加路由失败: ${err}')
		return
	}
	
	iterations := 10000
	
	// 测试原始路由器（第一次匹配）
	old_router.clear_cache()
	old_router.clear_regex_cache()
	
	start_time1 := time.now()
	mut old_first_matches := 0
	for _ in 0 .. iterations {
		old_router.clear_cache()
		old_router.clear_regex_cache()
		if _ := old_router.match_route('GET', test_path) {
			old_first_matches++
		}
	}
	old_first_time := time.since(start_time1)
	
	// 测试快速路由器（第一次匹配）
	fast_router.clear_cache()
	
	start_time2 := time.now()
	mut fast_first_matches := 0
	for _ in 0 .. iterations {
		fast_router.clear_cache()
		if _ := fast_router.match_route('GET', test_path) {
			fast_first_matches++
		}
	}
	fast_first_time := time.since(start_time2)
	
	println('  第一次匹配性能 (${iterations}次):')
	if old_first_matches > 0 {
		avg_old_first := f64(old_first_time.microseconds()) / f64(old_first_matches)
		println('    原始路由器: ${old_first_time} (平均 ${avg_old_first:.3f}μs)')
	}
	
	if fast_first_matches > 0 {
		avg_fast_first := f64(fast_first_time.microseconds()) / f64(fast_first_matches)
		println('    快速路由器: ${fast_first_time} (平均 ${avg_fast_first:.3f}μs)')
		
		if old_first_matches > 0 {
			avg_old_first := f64(old_first_time.microseconds()) / f64(old_first_matches)
			if avg_old_first > avg_fast_first {
				improvement := avg_old_first / avg_fast_first
				println('    🚀 快速路由器提升: ${improvement:.2f}x')
			}
		}
	}
	
	// 测试缓存匹配性能
	start_time3 := time.now()
	mut old_cache_matches := 0
	for _ in 0 .. iterations {
		if _ := old_router.match_route('GET', test_path) {
			old_cache_matches++
		}
	}
	old_cache_time := time.since(start_time3)
	
	start_time4 := time.now()
	mut fast_cache_matches := 0
	for _ in 0 .. iterations {
		if _ := fast_router.match_route('GET', test_path) {
			fast_cache_matches++
		}
	}
	fast_cache_time := time.since(start_time4)
	
	println('\n  缓存匹配性能 (${iterations}次):')
	if old_cache_matches > 0 {
		avg_old_cache := f64(old_cache_time.microseconds()) / f64(old_cache_matches)
		println('    原始路由器: ${old_cache_time} (平均 ${avg_old_cache:.3f}μs)')
	}
	
	if fast_cache_matches > 0 {
		avg_fast_cache := f64(fast_cache_time.microseconds()) / f64(fast_cache_matches)
		println('    快速路由器: ${fast_cache_time} (平均 ${avg_fast_cache:.3f}μs)')
		
		if old_cache_matches > 0 {
			avg_old_cache := f64(old_cache_time.microseconds()) / f64(old_cache_matches)
			if avg_old_cache > avg_fast_cache {
				improvement := avg_old_cache / avg_fast_cache
				println('    🚀 快速路由器提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_multiple_routes_performance() {
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
	
	// 创建原始路由器
	mut old_router := hono.ContextHybridRouter.new()
	for route_info in test_routes {
		handler := hono.ContextHandler{
			path: route_info['route']
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		old_router.add_route('GET', handler, '')
	}
	
	// 创建快速路由器
	mut fast_router := hono.FastRouter.new()
	for route_info in test_routes {
		handler := hono.ContextHandler{
			path: route_info['route']
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		fast_router.add_route('GET', handler, '') or {
			println('  ❌ 快速路由器添加路由失败: ${err}')
			continue
		}
	}
	
	iterations := 5000
	
	// 测试原始路由器
	old_router.clear_cache()
	old_router.clear_regex_cache()
	
	start_time1 := time.now()
	mut old_matches := 0
	for _ in 0 .. iterations {
		for route_info in test_routes {
			if _ := old_router.match_route('GET', route_info['path']) {
				old_matches++
			}
		}
	}
	old_time := time.since(start_time1)
	
	// 测试快速路由器
	fast_router.clear_cache()
	
	start_time2 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		for route_info in test_routes {
			if _ := fast_router.match_route('GET', route_info['path']) {
				fast_matches++
			}
		}
	}
	fast_time := time.since(start_time2)
	
	println('  多路由匹配性能 (${iterations}轮 × ${test_routes.len}路由):')
	if old_matches > 0 {
		avg_old := f64(old_time.microseconds()) / f64(old_matches)
		println('    原始路由器: ${old_time} (平均 ${avg_old:.3f}μs)')
	}
	
	if fast_matches > 0 {
		avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
		println('    快速路由器: ${fast_time} (平均 ${avg_fast:.3f}μs)')
		
		if old_matches > 0 {
			avg_old := f64(old_time.microseconds()) / f64(old_matches)
			if avg_old > avg_fast {
				improvement := avg_old / avg_fast
				println('    🚀 快速路由器提升: ${improvement:.2f}x')
			}
		}
	}
	
	// 显示统计信息
	old_static, old_dynamic := old_router.get_all_routes()
	fast_static, fast_dynamic := fast_router.get_all_routes()
	
	println('\n  路由统计:')
	println('    原始路由器 - 静态: ${old_static.len}, 动态: ${old_dynamic.len}')
	println('    快速路由器 - 静态: ${fast_static.len}, 动态: ${fast_dynamic.len}')
}

fn test_large_scale_performance() {
	println('\n📊 大规模路由性能对比...')
	
	// 创建大量路由
	mut old_router := hono.ContextHybridRouter.new()
	mut fast_router := hono.FastRouter.new()
	
	route_count := 100
	
	for i in 0 .. route_count {
		route_path := '/api/v${i}/resources/:id/items/:item_id'
		
		old_handler := hono.ContextHandler{
			path: route_path
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		old_router.add_route('GET', old_handler, '')
		
		fast_handler := hono.ContextHandler{
			path: route_path
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		fast_router.add_route('GET', fast_handler, '') or {
			continue
		}
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
	
	// 测试原始路由器
	start_time1 := time.now()
	mut old_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := old_router.match_route('GET', path) {
				old_matches++
			}
		}
	}
	old_time := time.since(start_time1)
	
	// 测试快速路由器
	start_time2 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := fast_router.match_route('GET', path) {
				fast_matches++
			}
		}
	}
	fast_time := time.since(start_time2)
	
	println('  大规模路由匹配 (${route_count}个路由, ${iterations}轮 × ${test_paths.len}路径):')
	if old_matches > 0 {
		avg_old := f64(old_time.microseconds()) / f64(old_matches)
		println('    原始路由器: ${old_time} (平均 ${avg_old:.3f}μs)')
	}
	
	if fast_matches > 0 {
		avg_fast := f64(fast_time.microseconds()) / f64(fast_matches)
		println('    快速路由器: ${fast_time} (平均 ${avg_fast:.3f}μs)')
		
		if old_matches > 0 {
			avg_old := f64(old_time.microseconds()) / f64(old_matches)
			if avg_old > avg_fast {
				improvement := avg_old / avg_fast
				println('    🚀 快速路由器提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_cache_effectiveness() {
	println('\n📊 缓存效果对比...')
	
	route_path := '/api/:version/users/:user_id/posts/:post_id'
	test_path := '/api/v1/users/123/posts/456'
	
	// 创建快速路由器
	mut fast_router := hono.FastRouter.new()
	handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	fast_router.add_route('GET', handler, '') or {
		println('  ❌ 添加路由失败')
		return
	}
	
	iterations := 10000
	
	// 测试启用缓存
	fast_router.set_cache_enabled(true)
	fast_router.clear_cache()
	
	start_time1 := time.now()
	mut cache_matches := 0
	for _ in 0 .. iterations {
		if _ := fast_router.match_route('GET', test_path) {
			cache_matches++
		}
	}
	cache_time := time.since(start_time1)
	
	// 测试禁用缓存
	fast_router.set_cache_enabled(false)
	
	start_time2 := time.now()
	mut no_cache_matches := 0
	for _ in 0 .. iterations {
		if _ := fast_router.match_route('GET', test_path) {
			no_cache_matches++
		}
	}
	no_cache_time := time.since(start_time2)
	
	println('  缓存效果测试 (${iterations}次):')
	if cache_matches > 0 {
		avg_cache := f64(cache_time.microseconds()) / f64(cache_matches)
		println('    启用缓存: ${cache_time} (平均 ${avg_cache:.3f}μs)')
	}
	
	if no_cache_matches > 0 {
		avg_no_cache := f64(no_cache_time.microseconds()) / f64(no_cache_matches)
		println('    禁用缓存: ${no_cache_time} (平均 ${avg_no_cache:.3f}μs)')
		
		if cache_matches > 0 {
			avg_cache := f64(cache_time.microseconds()) / f64(cache_matches)
			if avg_no_cache > avg_cache {
				improvement := avg_no_cache / avg_cache
				println('    🚀 缓存提升: ${improvement:.2f}x')
			}
		}
	}
	
	// 显示统计
	fast_router.set_cache_enabled(true)
	fast_router.analyze_performance()
}