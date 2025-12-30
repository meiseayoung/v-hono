import hono
import time
import net.http

fn main() {
	println('=== 动态路由综合测试用例 ===')
	
	// 测试1: RESTful API 路由模式
	test_restful_api_routes()
	
	// 测试2: 嵌套资源路由
	test_nested_resource_routes()
	
	// 测试3: 文件系统路由
	test_filesystem_routes()
	
	// 测试4: 多版本API路由
	test_versioned_api_routes()
	
	// 测试5: 电商平台路由
	test_ecommerce_routes()
	
	// 测试6: 内容管理系统路由
	test_cms_routes()
	
	// 测试7: 社交媒体路由
	test_social_media_routes()
	
	// 测试8: 复杂参数路由
	test_complex_parameter_routes()
	
	// 测试9: 通配符路由
	test_wildcard_routes()
	
	// 测试10: 性能压力测试
	test_performance_stress()
	
	println('✅ 动态路由综合测试完成')
}

// 测试用例结构
struct TestCase {
	method string
	path   string
	expect bool
}

fn test_restful_api_routes() {
	println('\n📊 RESTful API 路由测试...')
	
	mut app := hono.Hono.new()
	
	// 用户资源路由
	app.get('/users', fn (mut c hono.Context) http.Response { return c.text('GET response') })
	app.post('/users', fn (mut c hono.Context) http.Response { return c.text('POST response') })
	app.get('/users/:id', fn (mut c hono.Context) http.Response { return c.text('GET response') })
	app.put('/users/:id', fn (mut c hono.Context) http.Response { return c.text('PUT response') })
	app.delete('/users/:id', fn (mut c hono.Context) http.Response { return c.text('DELETE response') })
	app.patch('/users/:id', fn (mut c hono.Context) http.Response { return c.text('PATCH response') })
	app.get('/users/:id/profile', fn (mut c hono.Context) http.Response { return c.text('GET response') })
	app.put('/users/:id/profile', fn (mut c hono.Context) http.Response { return c.text('PUT response') })
	app.get('/users/:id/avatar', fn (mut c hono.Context) http.Response { return c.text('GET response') })
	app.post('/users/:id/avatar', fn (mut c hono.Context) http.Response { return c.text('POST response') })
	app.get('/users/:id/settings', fn (mut c hono.Context) http.Response { return c.text('GET response') })
	app.put('/users/:id/settings', fn (mut c hono.Context) http.Response { return c.text('PUT response') })
	
	test_cases := [
		TestCase{'GET', '/users', true},
		TestCase{'GET', '/users/123', true},
		TestCase{'PUT', '/users/456/profile', true},
		TestCase{'POST', '/users/789/avatar', true},
		TestCase{'GET', '/users/abc/settings', true},
		TestCase{'DELETE', '/users/xyz', true},
		TestCase{'GET', '/nonexistent', false},
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in test_cases {
		start_time := time.now()
		
		if _ := app.fast_router.match_route(test_case.method, test_case.path) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if test_case.expect {
				success_count++
				println('  ✅ ${test_case.method} ${test_case.path} - 匹配成功 (${match_time})')
			} else {
				println('  ❌ ${test_case.method} ${test_case.path} - 意外匹配')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if !test_case.expect {
				success_count++
				println('  ✅ ${test_case.method} ${test_case.path} - 正确未匹配 (${match_time})')
			} else {
				println('  ❌ ${test_case.method} ${test_case.path} - 匹配失败')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_cases.len)
	println('  📈 RESTful路由测试: ${success_count}/${test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_nested_resource_routes() {
	println('\n📊 嵌套资源路由测试...')
	
	mut app := hono.Hono.new()
	
	nested_routes := [
		'/blogs/:blog_id/posts/:post_id',
		'/blogs/:blog_id/posts/:post_id/comments/:comment_id',
		'/blogs/:blog_id/posts/:post_id/comments/:comment_id/replies/:reply_id',
		'/organizations/:org_id/departments/:dept_id',
		'/organizations/:org_id/departments/:dept_id/teams/:team_id',
		'/projects/:project_id/milestones/:milestone_id',
		'/projects/:project_id/milestones/:milestone_id/tasks/:task_id',
		'/countries/:country_id/states/:state_id/cities/:city_id',
	]
	
	for route in nested_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('nested response')
		})
	}
	
	test_paths := [
		'/blogs/tech-blog/posts/hello-world',
		'/blogs/personal/posts/my-journey/comments/great-post',
		'/blogs/dev/posts/v-lang-tips/comments/helpful/replies/thanks',
		'/organizations/acme-corp/departments/engineering',
		'/organizations/startup/departments/marketing/teams/growth',
		'/projects/website-redesign/milestones/phase-1',
		'/projects/mobile-app/milestones/mvp/tasks/user-auth',
		'/countries/usa/states/california/cities/san-francisco',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			param_count := match_result.params.len
			println('  ✅ ${path} - 匹配成功, ${param_count}个参数 (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_paths.len)
	println('  📈 嵌套路由测试: ${success_count}/${test_paths.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_filesystem_routes() {
	println('\n📊 文件系统路由测试...')
	
	mut app := hono.Hono.new()
	
	fs_routes := [
		'/files/:year/:month/:day/:filename',
		'/files/:category/:subcategory/:filename',
		'/uploads/:user_id/:folder/:filename',
		'/media/:type/:resolution/:filename',
		'/documents/:department/:project/:version/:filename',
		'/assets/:version/:type/:name',
	]
	
	for route in fs_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('file response')
		})
	}
	
	test_file_paths := [
		'/files/2023/12/26/document.pdf',
		'/files/images/avatars/user123.jpg',
		'/uploads/user456/photos/vacation.png',
		'/media/video/1080p/movie.mp4',
		'/documents/engineering/website/v2.1/spec.docx',
		'/assets/v1.2.3/css/main.css',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_file_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			filename := match_result.params['filename'] or { match_result.params['name'] or { 'unknown' } }
			println('  ✅ ${path} - 文件: ${filename} (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_file_paths.len)
	println('  📈 文件系统路由测试: ${success_count}/${test_file_paths.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_versioned_api_routes() {
	println('\n📊 多版本API路由测试...')
	
	mut app := hono.Hono.new()
	
	api_versions := ['v1', 'v2', 'v3']
	resources := ['users', 'posts', 'comments']
	
	for version in api_versions {
		for resource in resources {
			app.get('/api/${version}/${resource}', fn (mut c hono.Context) http.Response {
				return c.text('list response')
			})
			app.get('/api/${version}/${resource}/:id', fn (mut c hono.Context) http.Response {
				return c.text('get response')
			})
			app.post('/api/${version}/${resource}', fn (mut c hono.Context) http.Response {
				return c.text('create response')
			})
		}
	}
	
	test_api_calls := [
		TestCase{'GET', '/api/v1/users', true},
		TestCase{'GET', '/api/v2/users/123', true},
		TestCase{'POST', '/api/v3/posts', true},
		TestCase{'GET', '/api/v1/comments/456', true},
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for api_call in test_api_calls {
		start_time := time.now()
		
		if _ := app.fast_router.match_route(api_call.method, api_call.path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			println('  ✅ ${api_call.method} ${api_call.path} - 匹配成功 (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${api_call.method} ${api_call.path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_api_calls.len)
	println('  📈 版本化API测试: ${success_count}/${test_api_calls.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_ecommerce_routes() {
	println('\n📊 电商平台路由测试...')
	
	mut app := hono.Hono.new()
	
	ecommerce_routes := [
		'/products/:product_id',
		'/products/:product_id/variants/:variant_id',
		'/products/:product_id/reviews/:review_id',
		'/categories/:category_id',
		'/categories/:category_id/subcategories/:subcategory_id',
		'/cart/:user_id/items/:item_id',
		'/orders/:order_id',
		'/orders/:order_id/items/:item_id',
		'/customers/:customer_id',
		'/customers/:customer_id/addresses/:address_id',
	]
	
	for route in ecommerce_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('ecommerce response')
		})
	}
	
	test_ecommerce_paths := [
		'/products/smartphone-x1',
		'/products/laptop-pro/variants/16gb-512gb',
		'/products/headphones/reviews/5-stars',
		'/categories/electronics/subcategories/phones',
		'/cart/user123/items/item456',
		'/orders/order789/items/item001',
		'/customers/cust001/addresses/home',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_ecommerce_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			mut key_params := []string{}
			for key, value in match_result.params {
				key_params << '${key}=${value}'
			}
			println('  ✅ ${path} - 参数: [${key_params.join(', ')}] (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_ecommerce_paths.len)
	println('  📈 电商路由测试: ${success_count}/${test_ecommerce_paths.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_cms_routes() {
	println('\n📊 内容管理系统路由测试...')
	
	mut app := hono.Hono.new()
	
	cms_routes := [
		'/admin/content/:content_type/:content_id',
		'/admin/content/:content_type/:content_id/revisions/:revision_id',
		'/admin/users/:user_id',
		'/admin/users/:user_id/roles/:role_id',
		'/admin/media/:media_type/:media_id',
		'/admin/system/settings/:category/:setting_id',
		'/content/:slug',
		'/category/:category_slug/:page',
		'/author/:author_slug/:content_type',
		'/tag/:tag_slug',
	]
	
	for route in cms_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('cms response')
		})
	}
	
	test_cms_paths := [
		'/admin/content/articles/how-to-code',
		'/admin/content/pages/about-us/revisions/v2',
		'/admin/users/editor123/roles/content-editor',
		'/admin/media/images/hero-banner',
		'/admin/system/settings/general/site-title',
		'/content/introduction-to-vlang',
		'/category/programming/1',
		'/author/john-doe/tutorials',
		'/tag/web-development',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_cms_paths {
		start_time := time.now()
		
		if _ := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			println('  ✅ ${path} - 匹配成功 (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_cms_paths.len)
	println('  📈 CMS路由测试: ${success_count}/${test_cms_paths.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_social_media_routes() {
	println('\n📊 社交媒体路由测试...')
	
	mut app := hono.Hono.new()
	
	social_routes := [
		'/users/:username',
		'/users/:username/posts',
		'/users/:username/followers',
		'/posts/:post_id',
		'/posts/:post_id/comments/:comment_id',
		'/posts/:post_id/likes',
		'/groups/:group_id',
		'/groups/:group_id/members/:member_id',
		'/messages/:conversation_id',
		'/events/:event_id',
	]
	
	for route in social_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('social response')
		})
	}
	
	test_social_paths := [
		'/users/john_doe',
		'/users/jane_smith/posts',
		'/users/developer123/followers',
		'/posts/funny-meme-123/comments/great-post',
		'/posts/tech-news/likes',
		'/groups/javascript-developers/members/newbie',
		'/messages/chat-with-friend',
		'/events/tech-conference',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_social_paths {
		start_time := time.now()
		
		if _ := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			println('  ✅ ${path} - 匹配成功 (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_social_paths.len)
	println('  📈 社交媒体路由测试: ${success_count}/${test_social_paths.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_complex_parameter_routes() {
	println('\n📊 复杂参数路由测试...')
	
	mut app := hono.Hono.new()
	
	complex_routes := [
		'/api/v:version/users/:user_id/posts/:post_id',
		'/products/:product_id/variants/:variant_id/inventory/:warehouse_id',
		'/blogs/:blog_slug/posts/:post_slug',
		'/users/:username/projects/:project_name/branches/:branch_name',
		'/reports/:year/:month/:day/:report_type',
	]
	
	for route in complex_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('complex response')
		})
	}
	
	test_complex_paths := [
		'/api/v2/users/12345/posts/67890',
		'/products/laptop-pro/variants/16gb-512gb/inventory/warehouse-west',
		'/blogs/tech-insights/posts/introduction-to-vlang',
		'/users/developer/projects/awesome-app/branches/feature-auth',
		'/reports/2023/12/26/sales',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	mut total_params := 0
	
	for path in test_complex_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			param_count := match_result.params.len
			total_params += param_count
			println('  ✅ ${path} - ${param_count}个参数 (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_complex_paths.len)
	avg_params := if success_count > 0 { f64(total_params) / f64(success_count) } else { 0.0 }
	println('  📈 复杂参数路由测试: ${success_count}/${test_complex_paths.len} 通过')
	println('  📊 平均耗时: ${avg_time:.3f}μs, 平均参数数: ${avg_params:.1f}个')
}

fn test_wildcard_routes() {
	println('\n📊 通配符路由测试...')
	
	mut app := hono.Hono.new()
	
	wildcard_routes := [
		'/static/:path',
		'/files/:category/:path',
		'/proxy/:service/:path',
		'/cdn/:version/:resource',
		'/assets/:type/:name',
	]
	
	for route in wildcard_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('wildcard response')
		})
	}
	
	test_wildcard_paths := [
		'/static/main.css',
		'/files/documents/report.pdf',
		'/proxy/api-service/users',
		'/cdn/v1.2.3/bootstrap.css',
		'/assets/fonts/roboto.woff2',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_wildcard_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			path_param := match_result.params['path'] or { match_result.params['resource'] or { match_result.params['name'] or { 'unknown' } } }
			println('  ✅ ${path} - 路径参数: ${path_param} (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${path} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_wildcard_paths.len)
	println('  📈 通配符路由测试: ${success_count}/${test_wildcard_paths.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_performance_stress() {
	println('\n📊 性能压力测试...')
	
	mut app := hono.Hono.new()
	
	route_count := 100
	println('  创建 ${route_count * 3} 个动态路由...')
	
	for i in 0 .. route_count {
		app.get('/simple${i}/:id', fn (mut c hono.Context) http.Response {
			return c.text('simple response')
		})
		app.get('/medium${i}/:category/:id', fn (mut c hono.Context) http.Response {
			return c.text('medium response')
		})
		app.get('/complex${i}/:service/:version/:resource/:id', fn (mut c hono.Context) http.Response {
			return c.text('complex response')
		})
	}
	
	mut test_paths := []string{}
	for i in 0 .. 50 {
		route_idx := i % route_count
		test_paths << '/simple${route_idx}/item${i}'
		test_paths << '/medium${route_idx}/cat/item${i}'
		test_paths << '/complex${route_idx}/svc/v1/res/item${i}'
	}
	
	println('  开始压力测试 (${test_paths.len} 个路径 × 100 轮)...')
	
	iterations := 100
	start_time := time.now()
	mut total_matches := 0
	
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := app.fast_router.match_route('GET', path) {
				total_matches++
			}
		}
	}
	
	total_time := time.since(start_time)
	total_requests := iterations * test_paths.len
	
	avg_time := f64(total_time.microseconds()) / f64(total_requests)
	requests_per_second := f64(total_requests) / total_time.seconds()
	
	println('  📈 压力测试结果:')
	println('    总请求数: ${total_requests}')
	println('    成功匹配: ${total_matches}')
	println('    总耗时: ${total_time}')
	println('    平均耗时: ${avg_time:.3f}μs')
	println('    QPS: ${requests_per_second:.0f} 请求/秒')
	
	static_count, dynamic_count, cache_count := app.fast_router.get_stats()
	println('    路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}
