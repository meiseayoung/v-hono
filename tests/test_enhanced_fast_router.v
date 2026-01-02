import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 增强版 FastRouter 功能测试 ===')
	
	// 测试1: 基本功能测试
	test_basic_functionality()
	
	// 测试2: LRU 缓存功能测试
	test_lru_cache_functionality()
	
	// 测试3: 路由复杂度排序测试
	test_route_complexity_sorting()
	
	// 测试4: 高级缓存管理测试
	test_advanced_cache_management()
	
	// 测试5: 性能对比测试
	test_performance_comparison()
	
	// 测试6: 健康检查测试
	test_health_check()
	
	// 测试7: 智能预热测试
	test_smart_warmup()
	
	println('\n🎯 增强版 FastRouter 测试完成')
}

fn test_basic_functionality() {
	println('\n📊 基本功能测试...')
	
	mut router := hono.FastRouter.new()
	
	// 添加静态路由
	static_handler := hono.ContextHandler{
		path: '/static'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('static')
		}
	}
	router.add_route('GET', static_handler, '') or {
		println('  ❌ 添加静态路由失败: ${err}')
		return
	}
	
	// 添加动态路由
	dynamic_handler := hono.ContextHandler{
		path: '/users/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('dynamic')
		}
	}
	router.add_route('GET', dynamic_handler, '') or {
		println('  ❌ 添加动态路由失败: ${err}')
		return
	}
	
	// 测试静态路由匹配
	if _ := router.match_route('GET', '/static') {
		println('  ✅ 静态路由匹配成功')
	} else {
		println('  ❌ 静态路由匹配失败')
	}
	
	// 测试动态路由匹配
	if match_result := router.match_route('GET', '/users/123') {
		println('  ✅ 动态路由匹配成功')
		if match_result.params['id'] == '123' {
			println('  ✅ 参数提取正确: id=${match_result.params['id']}')
		} else {
			println('  ❌ 参数提取错误')
		}
	} else {
		println('  ❌ 动态路由匹配失败')
	}
	
	// 显示基本统计
	static_count, dynamic_count, cache_count := router.get_stats()
	println('  📈 统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}

fn test_lru_cache_functionality() {
	println('\n📊 LRU 缓存功能测试...')
	
	// 创建小缓存容量的路由器
	mut router := hono.FastRouter.new_with_cache_size(3)
	
	// 添加测试路由
	for i in 0 .. 5 {
		handler := hono.ContextHandler{
			path: '/test${i}/:id'
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	// 测试缓存填充
	test_paths := ['/test0/123', '/test1/456', '/test2/789', '/test3/101', '/test4/202']
	
	for path in test_paths {
		router.match_route('GET', path)
	}
	
	cache_size, cache_capacity := router.get_cache_stats()
	println('  📈 缓存状态: ${cache_size}/${cache_capacity}')
	
	if cache_size <= 3 {
		println('  ✅ LRU 缓存容量限制正常工作')
	} else {
		println('  ❌ LRU 缓存容量限制失效')
	}
	
	// 测试缓存命中
	start_time := time.now()
	for _ in 0 .. 1000 {
		router.match_route('GET', '/test4/202')  // 应该命中缓存
	}
	cache_hit_time := time.since(start_time)
	
	// 清理缓存后测试
	router.clear_cache()
	start_time2 := time.now()
	for _ in 0 .. 1000 {
		router.match_route('GET', '/test4/202')  // 不会命中缓存
	}
	no_cache_time := time.since(start_time2)
	
	println('  ⏱️  缓存命中时间: ${cache_hit_time}')
	println('  ⏱️  无缓存时间: ${no_cache_time}')
	
	if cache_hit_time < no_cache_time {
		improvement := f64(no_cache_time.microseconds()) / f64(cache_hit_time.microseconds())
		println('  🚀 缓存性能提升: ${improvement:.2f}x')
	}
}

fn test_route_complexity_sorting() {
	println('\n📊 路由复杂度排序测试...')
	
	mut router := hono.FastRouter.new()
	
	// 添加不同复杂度的路由
	routes := [
		'/simple/:id',                                    // 简单路由
		'/complex/:category/:subcategory/:id',           // 复杂路由
		'/very/complex/:a/:b/:c/:d/:e',                  // 非常复杂
		'/static/path',                                   // 静态路由
		'/medium/:type/:id'                              // 中等复杂度
	]
	
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	// 获取路由按复杂度分组
	simple_routes, complex_routes := router.get_routes_by_complexity()
	
	println('  📊 路由复杂度分布:')
	println('    简单路由 (≤30): ${simple_routes.len}')
	for route in simple_routes {
		println('      ${route.pattern} (复杂度: ${route.complexity})')
	}
	
	println('    复杂路由 (>30): ${complex_routes.len}')
	for route in complex_routes {
		println('      ${route.pattern} (复杂度: ${route.complexity})')
	}
	
	// 验证排序是否正确
	mut is_sorted := true
	for i in 1 .. router.precompiled_routes.len {
		if router.precompiled_routes[i-1].complexity > router.precompiled_routes[i].complexity {
			is_sorted = false
			break
		}
	}
	
	if is_sorted {
		println('  ✅ 路由按复杂度正确排序')
	} else {
		println('  ❌ 路由排序有误')
	}
}

fn test_advanced_cache_management() {
	println('\n📊 高级缓存管理测试...')
	
	mut router := hono.FastRouter.new()
	
	// 添加测试路由
	handler := hono.ContextHandler{
		path: '/test/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	router.add_route('GET', handler, '') or {
		println('  ❌ 添加路由失败')
		return
	}
	
	// 设置短 TTL 进行测试
	router.set_cache_ttl(1)  // 1秒 TTL
	
	// 填充缓存
	router.match_route('GET', '/test/123')
	
	cache_size1, _ := router.get_cache_stats()
	println('  📈 缓存填充后: ${cache_size1} 条目')
	
	// 等待 TTL 过期
	time.sleep(1100 * time.millisecond)
	
	// 强制清理过期条目
	router.force_cleanup_expired()
	
	cache_size2, _ := router.get_cache_stats()
	println('  📈 TTL 清理后: ${cache_size2} 条目')
	
	if cache_size2 < cache_size1 {
		println('  ✅ TTL 过期清理正常工作')
	} else {
		println('  ⚠️  TTL 过期清理可能未生效')
	}
	
	// 测试缓存健康检查
	if router.is_healthy() {
		println('  ✅ 缓存健康状态正常')
	} else {
		println('  ❌ 缓存健康状态异常')
	}
	
	// 测试详细统计
	detailed_stats := router.get_detailed_stats()
	println('  📊 详细统计:')
	for key, value in detailed_stats {
		println('    ${key}: ${value}')
	}
}

fn test_performance_comparison() {
	println('\n📊 性能对比测试...')
	
	// 创建增强版 FastRouter
	mut enhanced_router := hono.FastRouter.new()
	
	// 创建原始 HybridRouter 进行对比
	mut hybrid_router := hono.ContextHybridRouter.new()
	
	// 添加相同的路由
	test_routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/api/:version/users/:user_id',
		'/files/:category/:filename',
		'/admin/:module/:action/:id'
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
		
		hybrid_handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('hybrid')
			}
		}
		hybrid_router.add_route('GET', hybrid_handler, '')
	}
	
	// 测试路径
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/api/v1/users/101',
		'/files/images/photo.jpg',
		'/admin/users/edit/555'
	]
	
	iterations := 5000
	
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
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := hybrid_router.match_route('GET', path) {
				hybrid_matches++
			}
		}
	}
	hybrid_time := time.since(start_time2)
	
	println('  ⏱️  增强版 FastRouter: ${enhanced_time} (${enhanced_matches} 匹配)')
	println('  ⏱️  原始 HybridRouter: ${hybrid_time} (${hybrid_matches} 匹配)')
	
	if enhanced_matches > 0 && hybrid_matches > 0 {
		enhanced_avg := f64(enhanced_time.microseconds()) / f64(enhanced_matches)
		hybrid_avg := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		
		if hybrid_avg > enhanced_avg {
			improvement := hybrid_avg / enhanced_avg
			println('  🚀 增强版性能提升: ${improvement:.2f}x')
		} else {
			println('  ⚠️  性能提升不明显')
		}
	}
}

fn test_health_check() {
	println('\n📊 健康检查测试...')
	
	mut router := hono.FastRouter.new()
	
	// 添加一些路由
	for i in 0 .. 10 {
		handler := hono.ContextHandler{
			path: '/test${i}/:id'
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	// 填充缓存
	for i in 0 .. 10 {
		router.match_route('GET', '/test${i}/123')
	}
	
	// 检查健康状态
	if router.is_healthy() {
		println('  ✅ 路由器健康状态正常')
	} else {
		println('  ❌ 路由器健康状态异常')
	}
	
	// 显示完整性能分析
	router.analyze_performance()
}

fn test_smart_warmup() {
	println('\n📊 智能预热测试...')
	
	mut router := hono.FastRouter.new()
	
	// 添加不同复杂度的路由
	routes := [
		'/simple/:id',
		'/complex/:a/:b/:c',
		'/very/complex/:w/:x/:y/:z',
		'/medium/:type/:id'
	]
	
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '') or {
			continue
		}
	}
	
	// 准备样本路径
	sample_paths := [
		'/simple/123',
		'/complex/a/b/c',
		'/very/complex/w/x/y/z',
		'/medium/type1/456'
	]
	
	// 执行智能预热
	router.smart_warmup(sample_paths)
	
	// 检查预热效果
	cache_size, _ := router.get_cache_stats()
	println('  📈 预热后缓存大小: ${cache_size}')
	
	if cache_size > 0 {
		println('  ✅ 智能预热成功')
	} else {
		println('  ⚠️  智能预热效果不明显')
	}
	
	// 测试预热后的性能
	start_time := time.now()
	for _ in 0 .. 1000 {
		for path in sample_paths {
			router.match_route('GET', path)
		}
	}
	warmed_time := time.since(start_time)
	
	println('  ⏱️  预热后性能: ${warmed_time}')
}