import meiseayoung.hono
import time
import net.http
import regex

fn main() {
	println('=== 深度路由性能分析 ===')
	
	// 测试1: 逐步分解第一次匹配的每个步骤
	test_step_by_step_breakdown()
	
	// 测试2: 分析正则表达式编译开销
	test_regex_compilation_overhead()
	
	// 测试3: 分析内存分配开销
	test_memory_allocation_overhead()
	
	// 测试4: 对比不同实现方式
	test_implementation_comparison()
	
	println('✅ 深度路由性能分析完成')
}

fn test_step_by_step_breakdown() {
	println('\n📊 逐步分解第一次匹配...')
	
	mut router := hono.ContextHybridRouter.new()
	
	route_path := '/api/:version/users/:user_id/posts/:post_id'
	test_path := '/api/v1/users/123/posts/456'
	
	handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	
	router.add_route('GET', handler, '')
	router.clear_cache()
	router.clear_regex_cache()
	
	println('  开始逐步计时...')
	
	// 步骤1: 静态路由检查
	start_time1 := time.now()
	static_result := router.match_static_route('GET', test_path)
	step1_time := time.since(start_time1)
	println('    步骤1 - 静态路由检查: ${step1_time}')
	
	if static_result != none {
		println('    ❌ 意外匹配到静态路由')
		return
	}
	
	// 步骤2: 缓存检查
	start_time2 := time.now()
	cache_key := 'GET:${test_path}'
	cache_result := router.cache.get(cache_key)
	step2_time := time.since(start_time2)
	println('    步骤2 - 缓存检查: ${step2_time}')
	
	if cache_result != none {
		println('    ❌ 意外命中缓存')
		return
	}
	
	// 步骤3: 动态路由遍历开始
	start_time3 := time.now()
	
	// 模拟动态路由匹配的开始部分
	mut found_handler_path := ''
	for handler_item in router.dynamic_routes {
		if handler_item.path == route_path {
			found_handler_path = handler_item.path
			break
		}
	}
	
	step3_time := time.since(start_time3)
	println('    步骤3 - 找到目标路由: ${step3_time}')
	
	if found_handler_path == '' {
		println('    ❌ 未找到目标路由')
		return
	}
	
	// 步骤4: 正则表达式缓存检查
	start_time4 := time.now()
	_ := router.regex_cache[route_path]
	step4_time := time.since(start_time4)
	println('    步骤4 - 正则缓存检查: ${step4_time}')
	
	// 步骤5: 正则表达式编译（如果需要）
	start_time5 := time.now()
	
	// 模拟正则表达式编译过程
	mut replaced_path := route_path
	mut param_names := []string{}
	
	// 提取参数名
	mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { 
		println('    ❌ 参数正则创建失败')
		return 
	}
	all_params := param_reg.find_all_str(route_path)
	for param in all_params {
		param_names << param[1..]
	}
	
	step5a_time := time.since(start_time5)
	println('    步骤5a - 参数提取: ${step5a_time}')
	
	// 转义特殊字符
	start_time5b := time.now()
	special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '$', '|']
	for ch in special_chars {
		replaced_path = replaced_path.replace(ch, '\\${ch}')
	}
	step5b_time := time.since(start_time5b)
	println('    步骤5b - 字符转义: ${step5b_time}')
	
	// 替换参数为捕获组
	start_time5c := time.now()
	replaced_path = param_reg.replace_by_fn(replaced_path, fn (re regex.RE, in_txt string, start int, end int) string {
		param_name := in_txt[start+1..end]
		return '(?P<${param_name}>[^/]+)'
	})
	replaced_path = '^${replaced_path}$'
	step5c_time := time.since(start_time5c)
	println('    步骤5c - 参数替换: ${step5c_time}')
	
	// 编译最终正则表达式
	start_time5d := time.now()
	mut final_regex := regex.regex_opt(replaced_path) or {
		println('    ❌ 最终正则编译失败')
		return
	}
	step5d_time := time.since(start_time5d)
	println('    步骤5d - 正则编译: ${step5d_time}')
	
	// 步骤6: 正则匹配
	start_time6 := time.now()
	match_result := final_regex.matches_string(test_path)
	step6_time := time.since(start_time6)
	println('    步骤6 - 正则匹配: ${step6_time}')
	
	if !match_result {
		println('    ❌ 正则匹配失败')
		return
	}
	
	// 步骤7: 参数提取
	start_time7 := time.now()
	mut param_map := map[string]string{}
	for param_name in param_names {
		group := final_regex.get_group_by_name(test_path, param_name)
		param_map[param_name] = group
	}
	step7_time := time.since(start_time7)
	println('    步骤7 - 参数提取: ${step7_time}')
	
	// 步骤8: 创建结果对象
	start_time8 := time.now()
	route_match := hono.ContextRouteMatch{
		handler: router.dynamic_routes[0]  // 使用找到的路由
		params: param_map
		path: found_handler_path
		base_path: ''
	}
	step8_time := time.since(start_time8)
	println('    步骤8 - 创建结果: ${step8_time}')
	
	// 步骤9: 缓存结果
	start_time9 := time.now()
	router.cache.put(cache_key, route_match)
	step9_time := time.since(start_time9)
	println('    步骤9 - 缓存结果: ${step9_time}')
	
	// 计算总时间
	total_manual_time := step1_time + step2_time + step3_time + step4_time + 
						 step5a_time + step5b_time + step5c_time + step5d_time + 
						 step6_time + step7_time + step8_time + step9_time
	
	println('\n  手动计算总时间: ${total_manual_time}')
	
	// 对比实际的完整匹配时间
	router.clear_cache()
	router.clear_regex_cache()
	
	start_time_full := time.now()
	actual_result := router.match_route('GET', test_path)
	full_time := time.since(start_time_full)
	
	println('  实际完整匹配时间: ${full_time}')
	
	if actual_result != none {
		println('  ✅ 实际匹配成功')
		
		if full_time > total_manual_time {
			overhead := time.Duration(full_time.nanoseconds() - total_manual_time.nanoseconds())
			println('  🚨 发现隐藏开销: ${overhead}')
		} else {
			println('  ✅ 时间基本一致')
		}
	}
}

fn test_regex_compilation_overhead() {
	println('\n📊 分析正则表达式编译开销...')
	
	test_patterns := [
		{
			'name': '简单模式'
			'pattern': '/users/:id'
			'regex': '^/users/(?P<id>[^/]+)$'
		},
		{
			'name': '中等模式'
			'pattern': '/users/:id/posts/:post_id'
			'regex': '^/users/(?P<id>[^/]+)/posts/(?P<post_id>[^/]+)$'
		},
		{
			'name': '复杂模式'
			'pattern': '/api/:version/users/:user_id/posts/:post_id'
			'regex': '^/api/(?P<version>[^/]+)/users/(?P<user_id>[^/]+)/posts/(?P<post_id>[^/]+)$'
		}
	]
	
	for pattern in test_patterns {
		println('\n  测试: ${pattern['name']}')
		println('    原始模式: ${pattern['pattern']}')
		println('    目标正则: ${pattern['regex']}')
		
		// 测试直接编译预构建的正则表达式
		start_time1 := time.now()
		mut direct_regex := regex.regex_opt(pattern['regex']) or {
			println('    ❌ 直接编译失败')
			continue
		}
		direct_time := time.since(start_time1)
		println('    直接编译时间: ${direct_time}')
		
		// 测试通过路由器编译（包含所有转换步骤）
		mut router := hono.ContextHybridRouter.new()
		router.clear_regex_cache()
		
		start_time2 := time.now()
		_, _, _ := router.match_path_with_regex('/dummy/path', pattern['pattern'])
		router_time := time.since(start_time2)
		println('    路由器编译时间: ${router_time}')
		
		if router_time > direct_time {
			overhead := time.Duration(router_time.nanoseconds() - direct_time.nanoseconds())
			println('    转换开销: ${overhead}')
		}
		
		// 测试编译后的匹配性能
		test_path := match pattern['name'] {
			'简单模式' { '/users/123' }
			'中等模式' { '/users/123/posts/456' }
			'复杂模式' { '/api/v1/users/123/posts/456' }
			else { '/test' }
		}
		
		iterations := 10000
		
		start_time3 := time.now()
		for _ in 0 .. iterations {
			direct_regex.matches_string(test_path)
		}
		direct_match_time := time.since(start_time3)
		avg_direct_match := f64(direct_match_time.microseconds()) / f64(iterations)
		
		if cached_regex := router.regex_cache[pattern['pattern']] {
			start_time4 := time.now()
			for _ in 0 .. iterations {
				cached_regex.regex.matches_string(test_path)
			}
			cached_match_time := time.since(start_time4)
			avg_cached_match := f64(cached_match_time.microseconds()) / f64(iterations)
			
			println('    直接匹配平均: ${avg_direct_match:.3f}μs')
			println('    缓存匹配平均: ${avg_cached_match:.3f}μs')
		}
	}
}

fn test_memory_allocation_overhead() {
	println('\n📊 分析内存分配开销...')
	
	// 测试各种数据结构创建的开销
	iterations := 10000
	
	// 测试map创建
	start_time1 := time.now()
	for _ in 0 .. iterations {
		_ := map[string]string{}
	}
	map_creation_time := time.since(start_time1)
	avg_map_creation := f64(map_creation_time.microseconds()) / f64(iterations)
	println('  平均map创建: ${avg_map_creation:.3f}μs')
	
	// 测试数组创建
	start_time2 := time.now()
	for _ in 0 .. iterations {
		_ := []string{}
	}
	array_creation_time := time.since(start_time2)
	avg_array_creation := f64(array_creation_time.microseconds()) / f64(iterations)
	println('  平均数组创建: ${avg_array_creation:.3f}μs')
	
	// 测试结构体创建
	start_time3 := time.now()
	for _ in 0 .. iterations {
		_ := hono.ContextRouteMatch{
			handler: hono.IHandler(unsafe { nil })
			params: map[string]string{}
			path: '/test'
			base_path: ''
		}
	}
	struct_creation_time := time.since(start_time3)
	avg_struct_creation := f64(struct_creation_time.microseconds()) / f64(iterations)
	println('  平均结构体创建: ${avg_struct_creation:.3f}μs')
	
	// 测试字符串操作
	test_string := '/api/:version/users/:user_id/posts/:post_id'
	
	start_time4 := time.now()
	for _ in 0 .. iterations {
		_ := test_string.replace(':', 'X')
	}
	string_replace_time := time.since(start_time4)
	avg_string_replace := f64(string_replace_time.microseconds()) / f64(iterations)
	println('  平均字符串替换: ${avg_string_replace:.3f}μs')
	
	start_time5 := time.now()
	for _ in 0 .. iterations {
		_ := test_string.split('/')
	}
	string_split_time := time.since(start_time5)
	avg_string_split := f64(string_split_time.microseconds()) / f64(iterations)
	println('  平均字符串分割: ${avg_string_split:.3f}μs')
}

fn test_implementation_comparison() {
	println('\n📊 对比不同实现方式...')
	
	route_path := '/api/:version/users/:user_id/posts/:post_id'
	test_path := '/api/v1/users/123/posts/456'
	
	// 方式1: 当前实现
	mut router1 := hono.ContextHybridRouter.new()
	handler1 := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('test')
		}
	}
	router1.add_route('GET', handler1, '')
	
	start_time1 := time.now()
	for _ in 0 .. 1000 {
		router1.clear_cache()
		router1.clear_regex_cache()
		router1.match_route('GET', test_path)
	}
	current_impl_time := time.since(start_time1)
	avg_current := f64(current_impl_time.microseconds()) / 1000.0
	println('  当前实现平均: ${avg_current:.3f}μs')
	
	// 方式2: 预编译正则表达式
	precompiled_regex := regex.regex_opt('^/api/(?P<version>[^/]+)/users/(?P<user_id>[^/]+)/posts/(?P<post_id>[^/]+)$') or {
		println('  ❌ 预编译失败')
		return
	}
	
	start_time2 := time.now()
	for _ in 0 .. 1000 {
		if precompiled_regex.matches_string(test_path) {
			mut params := map[string]string{}
			params['version'] = precompiled_regex.get_group_by_name(test_path, 'version')
			params['user_id'] = precompiled_regex.get_group_by_name(test_path, 'user_id')
			params['post_id'] = precompiled_regex.get_group_by_name(test_path, 'post_id')
		}
	}
	precompiled_time := time.since(start_time2)
	avg_precompiled := f64(precompiled_time.microseconds()) / 1000.0
	println('  预编译实现平均: ${avg_precompiled:.3f}μs')
	
	if avg_current > avg_precompiled {
		improvement_potential := avg_current / avg_precompiled
		println('  🎯 优化潜力: ${improvement_potential:.2f}x')
	}
}