import hono
import time
import net.http

fn main() {
	println('=== 动态路由功能展示测试 ===')
	
	// 测试1: 复杂嵌套路由
	test_complex_nested_routes()
	
	// 测试2: RESTful API 路由
	test_restful_api_routes()
	
	// 测试3: 多参数路由
	test_multi_parameter_routes()
	
	// 测试4: 真实应用场景
	test_real_application_scenarios()
	
	// 测试5: 性能压力测试
	test_performance_stress()
	
	println('✅ 动态路由功能展示测试完成')
}

fn test_complex_nested_routes() {
	println('\n📊 复杂嵌套路由测试...')
	
	mut app := hono.Hono.new()
	
	// 添加复杂嵌套路由
	complex_routes := [
		'/api/:version/orgs/:org_id/projects/:project_id/tasks/:task_id',
		'/shop/:region/:city/stores/:store_id/products/:category/:product_id',
		'/social/:platform/users/:user_id/posts/:post_id/comments/:comment_id',
		'/enterprise/:tenant/departments/:dept_id/teams/:team_id/members/:member_id',
		'/media/:type/:year/:month/:day/:filename'
	]
	
	for route in complex_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('Complex nested response')
		})
	}
	
	// 测试复杂路径
	test_paths := [
		'/api/v1/orgs/org123/projects/proj456/tasks/task789',
		'/shop/asia/beijing/stores/store001/products/electronics/phone999',
		'/social/twitter/users/john_doe/posts/post123/comments/comment456',
		'/enterprise/company1/departments/engineering/teams/backend/members/dev001',
		'/media/video/2023/12/26/presentation.mp4'
	]
	
	mut success_count := 0
	for i, path in test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			// 验证参数提取
			param_count := match_result.params.len
			
			// 根据路由复杂度验证参数数量
			expected_params := match i {
				0 { 4 }  // version, org_id, project_id, task_id
				1 { 6 }  // region, city, store_id, category, product_id
				2 { 5 }  // platform, user_id, post_id, comment_id
				3 { 5 }  // tenant, dept_id, team_id, member_id
				4 { 5 }  // type, year, month, day, filename
				else { 0 }
			}
			
			if param_count >= expected_params {
				success_count++
				println('  ✅ ${path} - 参数提取成功 (${param_count}个参数)')
			} else {
				println('  ❌ ${path} - 参数提取不完整 (${param_count}/${expected_params})')
			}
		} else {
			println('  ❌ ${path} - 路由匹配失败')
		}
	}
	
	println('  复杂嵌套路由测试: ${success_count}/${test_paths.len} 通过')
}

fn test_restful_api_routes() {
	println('\n📊 RESTful API 路由测试...')
	
	mut app := hono.Hono.new()
	
	// RESTful 路由模式
	restful_routes := [
		'/api/users',
		'/api/users/:id',
		'/api/users/:user_id/posts',
		'/api/users/:user_id/posts/:post_id',
		'/api/users/:user_id/posts/:post_id/comments',
		'/api/users/:user_id/posts/:post_id/comments/:comment_id',
		'/api/search/:query',
		'/api/filter/:category/:tag'
	]
	
	// 添加所有HTTP方法
	for route in restful_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('GET response')
		})
		app.post(route, fn (mut c hono.Context) http.Response {
			return c.text('POST response')
		})
		app.put(route, fn (mut c hono.Context) http.Response {
			return c.text('PUT response')
		})
		app.delete(route, fn (mut c hono.Context) http.Response {
			return c.text('DELETE response')
		})
	}
	
	// 测试不同HTTP方法
	http_methods := ['GET', 'POST', 'PUT', 'DELETE']
	test_paths := [
		'/api/users/123',
		'/api/users/456/posts/789',
		'/api/users/111/posts/222/comments/333',
		'/api/search/machine learning',
		'/api/filter/tech/javascript'
	]
	
	mut total_tests := 0
	mut successful_tests := 0
	
	for method in http_methods {
		for path in test_paths {
			total_tests++
			if _ := app.fast_router.match_route(method, path) {
				successful_tests++
			}
		}
	}
	
	println('  RESTful API测试: ${successful_tests}/${total_tests} 通过')
	println('  支持的HTTP方法: ${http_methods.len}')
	println('  测试路径数量: ${test_paths.len}')
}

fn test_multi_parameter_routes() {
	println('\n📊 多参数路由测试...')
	
	mut app := hono.Hono.new()
	
	// 不同参数数量的路由
	param_routes := [
		'/single/:param1',                                    // 1个参数
		'/double/:param1/:param2',                           // 2个参数
		'/triple/:param1/:param2/:param3',                   // 3个参数
		'/quad/:param1/:param2/:param3/:param4',             // 4个参数
		'/penta/:param1/:param2/:param3/:param4/:param5',    // 5个参数
		'/hexa/:p1/:p2/:p3/:p4/:p5/:p6',                     // 6个参数
		'/septa/:p1/:p2/:p3/:p4/:p5/:p6/:p7',                // 7个参数
		'/octa/:p1/:p2/:p3/:p4/:p5/:p6/:p7/:p8',             // 8个参数
		'/nona/:p1/:p2/:p3/:p4/:p5/:p6/:p7/:p8/:p9',         // 9个参数
		'/deca/:p1/:p2/:p3/:p4/:p5/:p6/:p7/:p8/:p9/:p10'     // 10个参数
	]
	
	for route in param_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('Multi-param response')
		})
	}
	
	// 对应的测试路径
	param_test_paths := [
		'/single/value1',
		'/double/value1/value2',
		'/triple/value1/value2/value3',
		'/quad/value1/value2/value3/value4',
		'/penta/value1/value2/value3/value4/value5',
		'/hexa/v1/v2/v3/v4/v5/v6',
		'/septa/v1/v2/v3/v4/v5/v6/v7',
		'/octa/v1/v2/v3/v4/v5/v6/v7/v8',
		'/nona/v1/v2/v3/v4/v5/v6/v7/v8/v9',
		'/deca/v1/v2/v3/v4/v5/v6/v7/v8/v9/v10'
	]
	
	println('  测试不同参数数量的路由:')
	
	for i, path in param_test_paths {
		expected_param_count := i + 1
		
		if match_result := app.fast_router.match_route('GET', path) {
			actual_param_count := match_result.params.len
			
			if actual_param_count == expected_param_count {
				println('    ✅ ${expected_param_count}个参数: ${path}')
			} else {
				println('    ❌ ${expected_param_count}个参数: ${path} (实际${actual_param_count}个)')
			}
		} else {
			println('    ❌ ${expected_param_count}个参数: ${path} (匹配失败)')
		}
	}
}

fn test_real_application_scenarios() {
	println('\n📊 真实应用场景测试...')
	
	mut app := hono.Hono.new()
	
	// 电商平台路由
	ecommerce_routes := [
		'/products/:product_id',
		'/products/:product_id/reviews/:review_id',
		'/users/:user_id/orders/:order_id',
		'/categories/:category_id/products',
		'/search/:query/filters/:filter'
	]
	
	// 社交媒体路由
	social_routes := [
		'/users/:user_id/profile',
		'/users/:user_id/posts/:post_id',
		'/posts/:post_id/comments/:comment_id',
		'/groups/:group_id/members/:member_id',
		'/messages/:conversation_id/:message_id'
	]
	
	// 企业应用路由
	enterprise_routes := [
		'/orgs/:org_id/teams/:team_id',
		'/projects/:project_id/tasks/:task_id',
		'/reports/:report_id/data/:date_range',
		'/workflows/:workflow_id/steps/:step_id',
		'/integrations/:integration_id/webhooks/:webhook_id'
	]
	
	// 添加所有路由
	mut all_routes := [][]string{}
	all_routes << ecommerce_routes
	all_routes << social_routes
	all_routes << enterprise_routes
	
	mut total_routes := 0
	for route_group in all_routes {
		for route in route_group {
			app.get(route, fn (mut c hono.Context) http.Response {
				return c.text('Real app response')
			})
			total_routes++
		}
	}
	
	// 测试真实场景路径
	real_test_paths := [
		// 电商场景
		'/products/phone123/reviews/review456',
		'/users/customer789/orders/order101',
		'/search/laptop/filters/price',
		
		// 社交场景
		'/users/john_doe/posts/post123',
		'/posts/viral_post/comments/comment456',
		'/groups/tech_group/members/member789',
		
		// 企业场景
		'/orgs/company1/teams/backend',
		'/projects/website_redesign/tasks/task001',
		'/reports/sales_report/data/2023-Q4'
	]
	
	println('  真实应用场景路由测试:')
	println('    总路由数: ${total_routes}')
	
	mut scenario_success := 0
	for path in real_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			scenario_success++
			param_count := match_result.params.len
			println('    ✅ ${path} (${param_count}个参数)')
		} else {
			println('    ❌ ${path} (匹配失败)')
		}
	}
	
	println('  真实场景测试: ${scenario_success}/${real_test_paths.len} 通过')
}

fn test_performance_stress() {
	println('\n📊 性能压力测试...')
	
	mut app := hono.Hono.new()
	
	// 创建大量动态路由
	route_count := 500
	println('  创建 ${route_count} 个动态路由...')
	
	for i in 0 .. route_count {
		route_pattern := '/stress/api/v${i % 3}/resources/:resource_id/items/:item_id${i}'
		app.get(route_pattern, fn (mut c hono.Context) http.Response {
			return c.text('stress response')
		})
	}
	
	// 生成测试路径
	mut test_paths := []string{}
	for i in 0 .. 50 {
		test_path := '/stress/api/v${i % 3}/resources/resource${i}/items/item${i}'
		test_paths << test_path
	}
	
	// 性能测试
	iterations := 2000
	
	println('  开始性能压力测试...')
	println('    路由数量: ${route_count}')
	println('    测试路径: ${test_paths.len}')
	println('    迭代次数: ${iterations}')
	
	start_time := time.now()
	mut total_matches := 0
	mut successful_matches := 0
	
	for _ in 0 .. iterations {
		for path in test_paths {
			total_matches++
			if _ := app.fast_router.match_route('GET', path) {
				successful_matches++
			}
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(total_matches)
	throughput := f64(total_matches) / total_time.seconds()
	success_rate := f64(successful_matches) / f64(total_matches) * 100.0
	
	println('  性能压力测试结果:')
	println('    总匹配次数: ${total_matches}')
	println('    成功匹配: ${successful_matches}')
	println('    成功率: ${success_rate:.1f}%')
	println('    总时间: ${total_time}')
	println('    平均时间: ${avg_time:.3f}μs')
	println('    吞吐量: ${throughput:.0f} 请求/秒')
	
	// 性能评级
	if avg_time < 10.0 {
		println('    🏆 性能等级: 优秀 (< 10μs)')
	} else if avg_time < 50.0 {
		println('    ✅ 性能等级: 良好 (< 50μs)')
	} else if avg_time < 100.0 {
		println('    ⚠️  性能等级: 一般 (< 100μs)')
	} else {
		println('    ❌ 性能等级: 需要优化 (>= 100μs)')
	}
	
	// 缓存效果测试
	println('\n  缓存效果测试:')
	
	// 清除缓存测试
	app.clear_cache()
	start_time_no_cache := time.now()
	mut no_cache_matches := 0
	
	for _ in 0 .. 100 {
		app.clear_cache()
		for path in test_paths[0..5] {
			if _ := app.fast_router.match_route('GET', path) {
				no_cache_matches++
			}
		}
	}
	
	no_cache_time := time.since(start_time_no_cache)
	no_cache_avg := f64(no_cache_time.microseconds()) / f64(no_cache_matches)
	
	// 有缓存测试
	start_time_with_cache := time.now()
	mut with_cache_matches := 0
	
	for _ in 0 .. 100 {
		for path in test_paths[0..5] {
			if _ := app.fast_router.match_route('GET', path) {
				with_cache_matches++
			}
		}
	}
	
	with_cache_time := time.since(start_time_with_cache)
	with_cache_avg := f64(with_cache_time.microseconds()) / f64(with_cache_matches)
	
	cache_improvement := no_cache_avg / with_cache_avg
	
	println('    无缓存平均: ${no_cache_avg:.3f}μs')
	println('    有缓存平均: ${with_cache_avg:.3f}μs')
	println('    缓存提升: ${cache_improvement:.2f}x')
	
	// 显示路由统计
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('    路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}