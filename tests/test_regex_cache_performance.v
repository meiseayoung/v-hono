import hono
import time
import net.http

fn main() {
	println('=== 正则表达式缓存性能测试 ===')
	
	// 测试1: 大规模重复匹配测试
	test_large_scale_repeated_matching()
	
	// 测试2: 多路由缓存效果测试
	test_multi_route_cache_effect()
	
	println('✅ 正则表达式缓存性能测试完成')
}

fn test_large_scale_repeated_matching() {
	println('\n📊 大规模重复匹配测试...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加一个复杂的动态路由
	handler := hono.ContextHandler{
		path: '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id/replies/:reply_id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	router.add_route('GET', handler, '')
	
	test_path := '/api/v1/users/123/posts/456/comments/789/replies/101'
	
	// 清空缓存
	router.clear_regex_cache()
	
	// 第一次匹配（需要编译正则表达式）
	println('  第一次匹配 (编译正则表达式)...')
	start_time1 := time.now()
	result1 := router.match_route('GET', test_path)
	first_match_time := time.since(start_time1)
	
	if result1 != none {
		println('  ✅ 第一次匹配成功')
	}
	
	// 检查缓存状态
	regex_total, regex_compiled := router.get_regex_cache_stats()
	println('  缓存状态: ${regex_compiled}/${regex_total} 已编译')
	
	// 大量重复匹配（使用缓存）
	iterations := 100000
	println('  执行 ${iterations} 次重复匹配 (使用缓存)...')
	
	start_time2 := time.now()
	mut successful_matches := 0
	for i in 0 .. iterations {
		if _ := router.match_route('GET', test_path) {
			successful_matches++
		}
		if i % 10000 == 0 {
			print('.')
		}
	}
	repeated_matches_time := time.since(start_time2)
	println('')
	
	println('  第一次匹配时间: ${first_match_time}')
	println('  ${iterations}次重复匹配时间: ${repeated_matches_time}')
	println('  成功匹配次数: ${successful_matches}')
	
	if successful_matches > 0 {
		avg_time := f64(repeated_matches_time.microseconds()) / f64(successful_matches)
		println('  平均每次匹配时间: ${avg_time:.3f}μs')
	}
	
	// 验证缓存没有增长（说明使用了缓存）
	_, regex_compiled_after := router.get_regex_cache_stats()
	if regex_compiled_after == regex_compiled {
		println('  ✅ 缓存使用正常 - 没有额外的编译')
	} else {
		println('  ❌ 缓存异常 - 发生了额外的编译')
	}
}

fn test_multi_route_cache_effect() {
	println('\n📊 多路由缓存效果测试...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加多个复杂的动态路由
	routes_and_paths := [
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
		},
		{
			'route': '/admin/:module/:action/:resource_id'
			'path': '/admin/users/edit/555'
		},
		{
			'route': '/docs/:language/:version/:section/:page'
			'path': '/docs/en/v2/api/authentication'
		}
	]
	
	// 添加路由
	for item in routes_and_paths {
		handler := hono.ContextHandler{
			path: item['route']
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	// 清空缓存
	router.clear_regex_cache()
	
	// 第一轮匹配（编译所有正则表达式）
	println('  第一轮匹配 - 编译阶段...')
	start_time1 := time.now()
	mut first_round_matches := 0
	for item in routes_and_paths {
		if _ := router.match_route('GET', item['path']) {
			first_round_matches++
		}
	}
	first_round_time := time.since(start_time1)
	
	regex_total_after_first, regex_compiled_after_first := router.get_regex_cache_stats()
	println('  第一轮后缓存: ${regex_compiled_after_first}/${regex_total_after_first} 已编译')
	println('  第一轮匹配时间: ${first_round_time}')
	println('  第一轮成功匹配: ${first_round_matches}')
	
	// 多轮重复匹配（使用缓存）
	rounds := 10000
	println('  执行 ${rounds} 轮重复匹配 (使用缓存)...')
	
	start_time2 := time.now()
	mut total_cached_matches := 0
	for round in 0 .. rounds {
		for item in routes_and_paths {
			if _ := router.match_route('GET', item['path']) {
				total_cached_matches++
			}
		}
		if round % 1000 == 0 {
			print('.')
		}
	}
	cached_rounds_time := time.since(start_time2)
	println('')
	
	println('  ${rounds}轮重复匹配时间: ${cached_rounds_time}')
	println('  总成功匹配次数: ${total_cached_matches}')
	
	// 计算性能对比
	if first_round_matches > 0 && total_cached_matches > 0 {
		avg_first_round := f64(first_round_time.microseconds()) / f64(first_round_matches)
		avg_cached := f64(cached_rounds_time.microseconds()) / f64(total_cached_matches)
		
		println('  平均第一轮匹配时间: ${avg_first_round:.3f}μs')
		println('  平均缓存匹配时间: ${avg_cached:.3f}μs')
		
		if avg_first_round > avg_cached {
			improvement := avg_first_round / avg_cached
			println('  🚀 缓存性能提升: ${improvement:.2f}x')
		}
	}
	
	// 验证缓存状态
	_, regex_compiled_final := router.get_regex_cache_stats()
	if regex_compiled_final == regex_compiled_after_first {
		println('  ✅ 缓存工作正常 - 没有额外编译')
	} else {
		println('  ❌ 缓存异常 - 发生了 ${regex_compiled_final - regex_compiled_after_first} 次额外编译')
	}
	
	// 显示详细统计
	router.analyze_router_performance()
}