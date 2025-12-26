import hono
import time
import net.http

fn main() {
	println('=== 增强版 FastRouter vs 原始 Router 性能对比 ===')
	
	// 测试1: 小规模路由性能对比
	test_small_scale_comparison()
	
	// 测试2: 大规模路由性能对比
	test_large_scale_comparison()
	
	// 测试3: 复杂路由模式对比
	test_complex_patterns_comparison()
	
	// 测试4: 缓存效率对比
	test_cache_efficiency_comparison()
	
	// 测试5: 内存使用对比
	test_memory_usage_comparison()
	
	println('\n🎯 性能对比测试完成')
}

fn test_small_scale_comparison() {
	println('\n📊 小规模路由性能对比 (10个路由)...')
	
	// 创建增强版 FastRouter
	mut enhanced_router := hono.FastRouter.new()
	
	// 创建原始 HybridRouter
	mut original_router := hono.ContextHybridRouter.new()
	
	// 添加相同的路由
	test_routes := [
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
	
	for route in test_routes {
		enhanced_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
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
	
	iterations := 5000
	
	// 测试增强版 FastRouter（冷启动）
	enhanced_router.clear_cache()
	start_time1 := time.now()
	mut enhanced_cold_matches := 0
	for _ in 0 .. iterations {
		enhanced_router.clear_cache()
		for path in test_paths {
			if _ := enhanced_router.match_route('GET', path) {
				enhanced_cold_matches++
			}
		}
	}
	enhanced_cold_time := time.since(start_time1)
	
	// 测试原始 HybridRouter（冷启动）
	original_router.clear_cache()
	original_router.clear_regex_cache()
	start_time2 := time.now()
	mut original_cold_matches := 0
	for _ in 0 .. iterations {
		original_router.clear_cache()
		original_router.clear_regex_cache()
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_cold_matches++
			}
		}
	}
	original_cold_time := time.since(start_time2)
	
	println('  冷启动性能 (${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_cold_matches > 0 {
		enhanced_avg := f64(enhanced_cold_time.microseconds()) / f64(enhanced_cold_matches)
		println('    增强版 FastRouter: ${enhanced_cold_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_cold_matches > 0 {
		original_avg := f64(original_cold_time.microseconds()) / f64(original_cold_matches)
		println('    原始 HybridRouter: ${original_cold_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_cold_matches > 0 {
			enhanced_avg := f64(enhanced_cold_time.microseconds()) / f64(enhanced_cold_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版冷启动提升: ${improvement:.2f}x')
			}
		}
	}
	
	// 测试热缓存性能
	start_time3 := time.now()
	mut enhanced_hot_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := enhanced_router.match_route('GET', path) {
				enhanced_hot_matches++
			}
		}
	}
	enhanced_hot_time := time.since(start_time3)
	
	start_time4 := time.now()
	mut original_hot_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_hot_matches++
			}
		}
	}
	original_hot_time := time.since(start_time4)
	
	println('\n  热缓存性能 (${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_hot_matches > 0 {
		enhanced_avg := f64(enhanced_hot_time.microseconds()) / f64(enhanced_hot_matches)
		println('    增强版 FastRouter: ${enhanced_hot_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_hot_matches > 0 {
		original_avg := f64(original_hot_time.microseconds()) / f64(original_hot_matches)
		println('    原始 HybridRouter: ${original_hot_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_hot_matches > 0 {
			enhanced_avg := f64(enhanced_hot_time.microseconds()) / f64(enhanced_hot_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版热缓存提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_large_scale_comparison() {
	println('\n📊 大规模路由性能对比 (100个路由)...')
	
	mut enhanced_router := hono.FastRouter.new()
	mut original_router := hono.ContextHybridRouter.new()
	
	// 添加大量路由
	for i in 0 .. 100 {
		route := '/api/v${i}/resources/:id/items/:item_id'
		
		enhanced_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	// 测试路径（匹配不同位置的路由）
	test_paths := [
		'/api/v1/resources/123/items/456',    // 早期匹配
		'/api/v25/resources/789/items/101',   // 中期匹配
		'/api/v50/resources/111/items/222',   // 中期匹配
		'/api/v75/resources/333/items/444',   // 后期匹配
		'/api/v99/resources/555/items/666'    // 最后匹配
	]
	
	iterations := 2000
	
	// 测试增强版 FastRouter
	start_time1 := time.now()
	mut enhanced_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := enhanced_router.match_route('GET', path) {
				enhanced_matches++
			}
		}
	}
	enhanced_time := time.since(start_time1)
	
	// 测试原始 HybridRouter
	start_time2 := time.now()
	mut original_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_matches++
			}
		}
	}
	original_time := time.since(start_time2)
	
	println('  大规模路由匹配 (100路由, ${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_matches > 0 {
		enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
		println('    增强版 FastRouter: ${enhanced_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_matches > 0 {
		original_avg := f64(original_time.microseconds()) / f64(original_matches)
		println('    原始 HybridRouter: ${original_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_matches > 0 {
			enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版大规模提升: ${improvement:.2f}x')
			}
		}
	}
	
	// 显示路由分布统计
	enhanced_simple, enhanced_complex := enhanced_router.get_routes_by_complexity()
	println('\n  增强版路由复杂度分布:')
	println('    简单路由: ${enhanced_simple.len}')
	println('    复杂路由: ${enhanced_complex.len}')
}

fn test_complex_patterns_comparison() {
	println('\n📊 复杂路由模式性能对比...')
	
	mut enhanced_router := hono.FastRouter.new()
	mut original_router := hono.ContextHybridRouter.new()
	
	// 添加复杂的动态路由
	complex_routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',
		'/shop/:category/:subcategory/products/:product_id/reviews/:review_id',
		'/admin/:module/:action/:resource_type/:resource_id',
		'/files/:year/:month/:day/:category/:filename',
		'/docs/:language/:version/:section/:subsection/:page'
	]
	
	for route in complex_routes {
		enhanced_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	// 复杂测试路径
	test_paths := [
		'/api/v1/users/123/posts/456/comments/789',
		'/shop/electronics/phones/products/999/reviews/111',
		'/admin/users/edit/profile/555',
		'/files/2023/12/26/images/photo.jpg',
		'/docs/en/v2/api/authentication/oauth'
	]
	
	iterations := 3000
	
	// 测试增强版 FastRouter
	start_time1 := time.now()
	mut enhanced_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := enhanced_router.match_route('GET', path) {
				enhanced_matches++
			}
		}
	}
	enhanced_time := time.since(start_time1)
	
	// 测试原始 HybridRouter
	start_time2 := time.now()
	mut original_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := original_router.match_route('GET', path) {
				original_matches++
			}
		}
	}
	original_time := time.since(start_time2)
	
	println('  复杂模式匹配 (${iterations}轮 × ${test_paths.len}路径):')
	if enhanced_matches > 0 {
		enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
		println('    增强版 FastRouter: ${enhanced_time} (平均 ${enhanced_avg:.3f}μs)')
	}
	
	if original_matches > 0 {
		original_avg := f64(original_time.microseconds()) / f64(original_matches)
		println('    原始 HybridRouter: ${original_time} (平均 ${original_avg:.3f}μs)')
		
		if enhanced_matches > 0 {
			enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
			if original_avg > enhanced_avg {
				improvement := original_avg / enhanced_avg
				println('    🚀 增强版复杂模式提升: ${improvement:.2f}x')
			}
		}
	}
}

fn test_cache_efficiency_comparison() {
	println('\n📊 缓存效率对比...')
	
	mut enhanced_router := hono.FastRouter.new_with_cache_size(100)
	mut original_router := hono.ContextHybridRouter.new()
	
	// 添加测试路由
	for i in 0 .. 20 {
		route := '/test${i}/:id'
		
		enhanced_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	// 重复访问相同路径（测试缓存命中率）
	mut repeated_paths := []string{}
	for i in 0 .. 10 {
		repeated_paths << '/test${i}/123'
	}
	
	// 执行多次匹配以填充缓存
	for _ in 0 .. 100 {
		for path in repeated_paths {
			enhanced_router.match_route('GET', path)
			original_router.match_route('GET', path)
		}
	}
	
	// 测试缓存命中性能
	iterations := 5000
	
	start_time1 := time.now()
	for _ in 0 .. iterations {
		for path in repeated_paths {
			enhanced_router.match_route('GET', path)
		}
	}
	enhanced_cache_time := time.since(start_time1)
	
	start_time2 := time.now()
	for _ in 0 .. iterations {
		for path in repeated_paths {
			original_router.match_route('GET', path)
		}
	}
	original_cache_time := time.since(start_time2)
	
	println('  缓存命中性能 (${iterations}轮 × ${repeated_paths.len}路径):')
	println('    增强版 FastRouter: ${enhanced_cache_time}')
	println('    原始 HybridRouter: ${original_cache_time}')
	
	if original_cache_time.microseconds() > enhanced_cache_time.microseconds() {
		improvement := f64(original_cache_time.microseconds()) / f64(enhanced_cache_time.microseconds())
		println('    🚀 增强版缓存提升: ${improvement:.2f}x')
	}
	
	// 显示缓存统计
	enhanced_cache_size, enhanced_cache_capacity := enhanced_router.get_cache_stats()
	original_cache_size, original_cache_capacity := original_router.get_cache_stats()
	
	println('\n  缓存统计:')
	println('    增强版: ${enhanced_cache_size}/${enhanced_cache_capacity} (LRU)')
	println('    原始版: ${original_cache_size}/${original_cache_capacity} (LRU)')
	
	// 显示详细统计
	enhanced_stats := enhanced_router.get_detailed_stats()
	println('\n  增强版详细统计:')
	for key, value in enhanced_stats {
		if key.starts_with('lru_') {
			println('    ${key}: ${value}')
		}
	}
}

fn test_memory_usage_comparison() {
	println('\n📊 内存使用对比...')
	
	mut enhanced_router := hono.FastRouter.new()
	mut original_router := hono.ContextHybridRouter.new()
	
	// 添加大量路由来测试内存使用
	route_count := 200
	
	for i in 0 .. route_count {
		route := '/api/v${i}/category/:cat/items/:id/details/:detail_id'
		
		enhanced_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('enhanced')
			}
		}
		enhanced_router.add_route('GET', enhanced_handler, '') or {
			continue
		}
		
		original_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('original')
			}
		}
		original_router.add_route('GET', original_handler, '')
	}
	
	// 填充缓存
	for i in 0 .. 50 {
		path := '/api/v${i}/category/electronics/items/123/details/456'
		enhanced_router.match_route('GET', path)
		original_router.match_route('GET', path)
	}
	
	// 获取统计信息
	enhanced_static, enhanced_dynamic, enhanced_cache := enhanced_router.get_stats()
	original_static, original_dynamic := original_router.get_all_routes()
	original_cache_size, _ := original_router.get_cache_stats()
	original_regex_total, original_regex_compiled := original_router.get_regex_cache_stats()
	
	println('  路由统计对比:')
	println('    增强版 - 静态: ${enhanced_static}, 动态: ${enhanced_dynamic}, 缓存: ${enhanced_cache}')
	println('    原始版 - 静态: ${original_static.len}, 动态: ${original_dynamic.len}, 缓存: ${original_cache_size}')
	println('    原始版 - 正则缓存: ${original_regex_compiled}/${original_regex_total}')
	
	// 估算内存使用
	enhanced_stats := enhanced_router.get_detailed_stats()
	if memory_estimate := enhanced_stats['lru_memory_usage_estimate'] {
		println('  增强版内存估算: ${memory_estimate} 字节')
	}
	
	// 显示健康状态
	if enhanced_router.is_healthy() {
		println('  增强版健康状态: ✅ 正常')
	} else {
		println('  增强版健康状态: ❌ 异常')
	}
	
	println('\n  🎯 内存使用总结:')
	println('    - 增强版使用 LRU 缓存，自动管理内存')
	println('    - 原始版使用简单 map + 正则缓存')
	println('    - 增强版具有 TTL 和健康检查功能')
}