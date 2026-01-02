import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== 精确路由性能计时 ===')
	
	// 测试1: 多次重复测量第一次匹配
	test_first_match_precision()
	
	// 测试2: 分离各个组件的时间
	test_component_timing()
	
	println('✅ 精确路由性能计时完成')
}

fn test_first_match_precision() {
	println('\n📊 精确测量第一次匹配时间...')
	
	route_path := '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id'
	test_path := '/api/v1/users/123/posts/456/comments/789'
	
	// 进行多次独立测试
	mut first_match_times := []f64{}
	
	for round in 0 .. 10 {
		mut router := hono.ContextHybridRouter.new()
		
		handler := hono.ContextHandler{
			path: route_path
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		
		router.add_route('GET', handler, '')
		
		// 确保缓存为空
		router.clear_regex_cache()
		
		// 测量第一次匹配时间
		start_time := time.now()
		result := router.match_route('GET', test_path)
		first_time := time.since(start_time)
		
		if result != none {
			first_match_times << f64(first_time.microseconds())
			println('  第${round+1}次测试: ${first_time.microseconds()}μs')
		}
	}
	
	// 计算统计数据
	if first_match_times.len > 0 {
		mut total := 0.0
		mut min_time := first_match_times[0]
		mut max_time := first_match_times[0]
		
		for time_us in first_match_times {
			total += time_us
			if time_us < min_time {
				min_time = time_us
			}
			if time_us > max_time {
				max_time = time_us
			}
		}
		
		avg_time := total / f64(first_match_times.len)
		
		println('\n  统计结果:')
		println('    平均时间: ${avg_time:.2f}μs')
		println('    最小时间: ${min_time:.2f}μs')
		println('    最大时间: ${max_time:.2f}μs')
		println('    时间范围: ${max_time - min_time:.2f}μs')
	}
}

fn test_component_timing() {
	println('\n📊 分离组件计时分析...')
	
	route_path := '/api/:version/users/:user_id/posts/:post_id/comments/:comment_id'
	test_path := '/api/v1/users/123/posts/456/comments/789'
	
	mut router := hono.ContextHybridRouter.new()
	
	handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	
	// 1. 测量添加路由的时间
	start_time1 := time.now()
	router.add_route('GET', handler, '')
	add_route_time := time.since(start_time1)
	println('  添加路由时间: ${add_route_time}')
	
	// 2. 测量静态路由检查时间
	start_time2 := time.now()
	for _ in 0 .. 10000 {
		router.match_static_route('GET', test_path)
	}
	static_check_time := time.since(start_time2)
	avg_static_check := f64(static_check_time.microseconds()) / 10000.0
	println('  平均静态路由检查: ${avg_static_check:.3f}μs')
	
	// 3. 测量缓存检查时间
	cache_key := 'GET:${test_path}'
	start_time3 := time.now()
	for _ in 0 .. 10000 {
		router.cache.get(cache_key)
	}
	cache_check_time := time.since(start_time3)
	avg_cache_check := f64(cache_check_time.microseconds()) / 10000.0
	println('  平均缓存检查: ${avg_cache_check:.3f}μs')
	
	// 4. 清空缓存，测量完整的第一次匹配
	router.clear_cache()
	router.clear_regex_cache()
	
	start_time4 := time.now()
	result := router.match_route('GET', test_path)
	full_match_time := time.since(start_time4)
	println('  完整第一次匹配: ${full_match_time}')
	
	if result != none {
		println('  ✅ 匹配成功')
		
		// 5. 测量后续缓存匹配
		start_time5 := time.now()
		for _ in 0 .. 10000 {
			router.match_route('GET', test_path)
		}
		cached_matches_time := time.since(start_time5)
		avg_cached_match := f64(cached_matches_time.microseconds()) / 10000.0
		println('  平均缓存匹配: ${avg_cached_match:.3f}μs')
		
		// 6. 分析缓存状态
		cache_size, cache_capacity := router.get_cache_stats()
		regex_total, regex_compiled := router.get_regex_cache_stats()
		println('  路由缓存: ${cache_size}/${cache_capacity}')
		println('  正则缓存: ${regex_compiled}/${regex_total}')
		
		// 7. 测量纯正则匹配（如果可以访问）
		if cached_regex := router.regex_cache[route_path] {
			if cached_regex.compiled {
				start_time6 := time.now()
				for _ in 0 .. 10000 {
					cached_regex.regex.matches_string(test_path)
				}
				pure_regex_time := time.since(start_time6)
				avg_regex_match := f64(pure_regex_time.microseconds()) / 10000.0
				println('  平均纯正则匹配: ${avg_regex_match:.3f}μs')
				
				// 8. 测量参数提取
				start_time7 := time.now()
				for _ in 0 .. 10000 {
					for param_name in cached_regex.param_names {
						cached_regex.regex.get_group_by_name(test_path, param_name)
					}
				}
				param_extract_time := time.since(start_time7)
				avg_param_extract := f64(param_extract_time.microseconds()) / 10000.0
				println('  平均参数提取: ${avg_param_extract:.3f}μs')
				println('  参数数量: ${cached_regex.param_names.len}')
			}
		}
	}
	
	// 9. 测量字符串操作开销
	println('\n  字符串操作性能:')
	
	start_time8 := time.now()
	for _ in 0 .. 10000 {
		_ := 'GET:${test_path}'
	}
	string_concat_time := time.since(start_time8)
	avg_string_concat := f64(string_concat_time.microseconds()) / 10000.0
	println('    平均字符串拼接: ${avg_string_concat:.3f}μs')
	
	start_time9 := time.now()
	for _ in 0 .. 10000 {
		_ := route_path.contains(':')
	}
	string_contains_time := time.since(start_time9)
	avg_string_contains := f64(string_contains_time.microseconds()) / 10000.0
	println('    平均字符串包含检查: ${avg_string_contains:.3f}μs')
	
	start_time10 := time.now()
	for _ in 0 .. 10000 {
		_ := route_path.count(':')
	}
	string_count_time := time.since(start_time10)
	avg_string_count := f64(string_count_time.microseconds()) / 10000.0
	println('    平均字符串计数: ${avg_string_count:.3f}μs')
}