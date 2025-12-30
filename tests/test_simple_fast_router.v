import hono
import time
import net.http

fn main() {
	println('=== 简化FastRouter性能测试 ===')
	
	// 测试FastRouter vs HybridRouter的基本性能
	test_basic_performance()
	
	println('✅ 简化FastRouter性能测试完成')
}

fn test_basic_performance() {
	println('\n📊 基本性能对比...')
	
	route_path := '/api/:version/users/:user_id/posts/:post_id'
	test_path := '/api/v1/users/123/posts/456'
	
	// 创建FastRouter
	mut fast_router := hono.FastRouter.new()
	fast_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('fast response')
		}
	}
	fast_router.add_route('GET', fast_handler, '') or {
		println('  ❌ FastRouter添加路由失败')
		return
	}
	
	// 创建HybridRouter
	mut hybrid_router := hono.ContextHybridRouter.new()
	hybrid_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('hybrid response')
		}
	}
	hybrid_router.add_route('GET', hybrid_handler, '')
	
	iterations := 10000
	
	// 测试FastRouter（第一次匹配）
	fast_router.clear_cache()
	
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		fast_router.clear_cache()
		if _ := fast_router.match_route('GET', test_path) {
			fast_matches++
		}
	}
	fast_time := time.since(start_time1)
	
	// 测试HybridRouter（第一次匹配）
	hybrid_router.clear_cache()
	hybrid_router.clear_regex_cache()
	
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		hybrid_router.clear_cache()
		hybrid_router.clear_regex_cache()
		if _ := hybrid_router.match_route('GET', test_path) {
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
		if _ := fast_router.match_route('GET', test_path) {
			fast_cache_matches++
		}
	}
	fast_cache_time := time.since(start_time3)
	
	start_time4 := time.now()
	mut hybrid_cache_matches := 0
	for _ in 0 .. iterations {
		if _ := hybrid_router.match_route('GET', test_path) {
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
	
	// 显示统计信息
	fast_static, fast_dynamic, fast_cache := fast_router.get_stats()
	hybrid_static, hybrid_dynamic := hybrid_router.get_all_routes()
	hybrid_cache_size, _ := hybrid_router.get_cache_stats()
	
	println('\n  路由统计:')
	println('    FastRouter - 静态: ${fast_static}, 动态: ${fast_dynamic}, 缓存: ${fast_cache}')
	println('    HybridRouter - 静态: ${hybrid_static.len}, 动态: ${hybrid_dynamic.len}, 缓存: ${hybrid_cache_size}')
	
	// 性能分析
	println('\n  性能分析:')
	fast_router.analyze_performance()
	hybrid_router.analyze_router_performance()
}