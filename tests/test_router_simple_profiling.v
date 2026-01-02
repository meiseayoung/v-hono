import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 简化路由性能分析 ===')
	
	// 测试不同复杂度路由的编译时间
	test_compilation_time()
	
	// 测试路由排序效果
	test_route_sorting_effect()
	
	println('✅ 简化路由性能分析完成')
}

fn test_compilation_time() {
	println('\n📊 不同复杂度路由编译时间对比...')
	
	test_cases := [
		{
			'name': '简单路由 (1个参数)'
			'route': '/users/:id'
			'path': '/users/123'
		},
		{
			'name': '中等路由 (2个参数)'
			'route': '/users/:id/posts/:post_id'
			'path': '/users/123/posts/456'
		},
		{
			'name': '复杂路由 (3个参数)'
			'route': '/api/:version/users/:user_id/posts/:post_id'
			'path': '/api/v1/users/123/posts/456'
		},
		{
			'name': '很复杂路由 (5个参数)'
			'route': '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id/replies/:reply_id'
			'path': '/api/v1/users/123/posts/456/comments/789/replies/101'
		}
	]
	
	for test_case in test_cases {
		println('\n  ${test_case['name']}:')
		
		mut router := hono.ContextHybridRouter.new()
		
		handler := hono.ContextHandler{
			path: test_case['route']
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		
		// 添加路由
		router.add_route('GET', handler, '')
		
		// 清空缓存确保需要编译
		router.clear_regex_cache()
		
		// 测试编译时间（第一次匹配）
		start_time := time.now()
		result := router.match_route('GET', test_case['path'])
		compile_time := time.since(start_time)
		
		if result != none {
			println('    编译+匹配时间: ${compile_time}')
		} else {
			println('    ❌ 匹配失败')
			continue
		}
		
		// 测试缓存匹配时间
		iterations := 10000
		start_time2 := time.now()
		mut cache_matches := 0
		for _ in 0 .. iterations {
			if _ := router.match_route('GET', test_case['path']) {
				cache_matches++
			}
		}
		cache_time := time.since(start_time2)
		
		if cache_matches > 0 {
			avg_cache_time := f64(cache_time.microseconds()) / f64(cache_matches)
			println('    平均缓存匹配: ${avg_cache_time:.3f}μs')
		}
		
		// 分析路由特征
		param_count := test_case['route'].count(':')
		segment_count := test_case['route'].split('/').len
		println('    参数数量: ${param_count}')
		println('    路径段数: ${segment_count}')
		
		// 检查缓存状态
		regex_total, regex_compiled := router.get_regex_cache_stats()
		println('    正则缓存: ${regex_compiled}/${regex_total}')
	}
}

fn test_route_sorting_effect() {
	println('\n📊 测试路由排序效果...')
	
	// 创建两个路由器：一个使用排序，一个不使用
	mut sorted_router := hono.ContextHybridRouter.new()
	mut unsorted_router := hono.ContextHybridRouter.new()
	
	// 定义路由（按复杂度递减顺序）
	routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id/replies/:reply_id',  // 最复杂
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',                   // 很复杂
		'/api/:version/users/:user_id/posts/:post_id',                                        // 中等复杂
		'/users/:id/posts/:post_id',                                                          // 较简单
		'/users/:id'                                                                          // 最简单
	]
	
	// 添加到排序路由器（会自动排序）
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		sorted_router.add_route('GET', handler, '')
	}
	
	// 手动添加到未排序路由器（保持原顺序）
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		unsorted_router.dynamic_routes << handler
	}
	
	// 测试匹配最简单的路由
	simple_path := '/users/123'
	iterations := 50000
	
	println('  测试路径: ${simple_path}')
	println('  测试次数: ${iterations}')
	
	// 测试排序路由器
	start_time1 := time.now()
	mut sorted_matches := 0
	for _ in 0 .. iterations {
		if _ := sorted_router.match_route('GET', simple_path) {
			sorted_matches++
		}
	}
	sorted_time := time.since(start_time1)
	
	// 测试未排序路由器
	start_time2 := time.now()
	mut unsorted_matches := 0
	for _ in 0 .. iterations {
		if _ := unsorted_router.match_route('GET', simple_path) {
			unsorted_matches++
		}
	}
	unsorted_time := time.since(start_time2)
	
	println('\n  结果对比:')
	if sorted_matches > 0 {
		avg_sorted := f64(sorted_time.microseconds()) / f64(sorted_matches)
		println('    排序路由器平均时间: ${avg_sorted:.3f}μs')
	}
	
	if unsorted_matches > 0 {
		avg_unsorted := f64(unsorted_time.microseconds()) / f64(unsorted_matches)
		println('    未排序路由器平均时间: ${avg_unsorted:.3f}μs')
		
		if sorted_matches > 0 {
			avg_sorted := f64(sorted_time.microseconds()) / f64(sorted_matches)
			if avg_unsorted > avg_sorted {
				improvement := avg_unsorted / avg_sorted
				println('    排序优化效果: ${improvement:.2f}x 提升')
			} else {
				println('    排序没有带来明显优化')
			}
		}
	}
	
	// 显示路由顺序
	_, sorted_paths := sorted_router.get_all_routes()
	println('\n  排序后的路由顺序:')
	for i, path in sorted_paths {
		param_count := path.count(':')
		println('    ${i+1}. ${path} (${param_count}个参数)')
	}
	
	println('\n  原始路由顺序:')
	for i, handler in unsorted_router.dynamic_routes {
		param_count := handler.path.count(':')
		println('    ${i+1}. ${handler.path} (${param_count}个参数)')
	}
}