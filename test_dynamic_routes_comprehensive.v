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

fn test_restful_api_routes() {
	println('\n📊 RESTful API 路由测试...')
	
	mut app := hono.Hono.new()
	
	// 用户资源路由
	restful_routes := [
		// 用户管理
		'GET:/users',                    // 获取用户列表
		'POST:/users',                   // 创建用户
		'GET:/users/:id',               // 获取单个用户
		'PUT:/users/:id',               // 更新用户
		'DELETE:/users/:id',            // 删除用户
		'PATCH:/users/:id',             // 部分更新用户
		
		// 用户资料
		'GET:/users/:id/profile',       // 获取用户资料
		'PUT:/users/:id/profile',       // 更新用户资料
		'GET:/users/:id/avatar',        // 获取用户头像
		'POST:/users/:id/avatar',       // 上传用户头像
		
		// 用户设置
		'GET:/users/:id/settings',      // 获取用户设置
		'PUT:/users/:id/settings',      // 更新用户设置
		'GET:/users/:id/preferences',   // 获取用户偏好
		'PUT:/users/:id/preferences',   // 更新用户偏好
	]
	
	// 添加路由
	for route_def in restful_routes {
		parts := route_def.split(':')
		method := parts[0]
		path := parts[1]
		
		match method {
			'GET' { app.get(path, fn (mut c hono.Context) http.Response { return c.text('GET response') }) }
			'POST' { app.post(path, fn (mut c hono.Context) http.Response { return c.text('POST response') }) }
			'PUT' { app.put(path, fn (mut c hono.Context) http.Response { return c.text('PUT response') }) }
			'DELETE' { app.delete(path, fn (mut c hono.Context) http.Response { return c.text('DELETE response') }) }
			'PATCH' { app.patch(path, fn (mut c hono.Context) http.Response { return c.text('PATCH response') }) }
			else {}
		}
	}
	
	// 测试路径
	test_cases := [
		{ 'method': 'GET', 'path': '/users', 'expect': true },
		{ 'method': 'GET', 'path': '/users/123', 'expect': true },
		{ 'method': 'PUT', 'path': '/users/456/profile', 'expect': true },
		{ 'method': 'POST', 'path': '/users/789/avatar', 'expect': true },
		{ 'method': 'GET', 'path': '/users/abc/settings', 'expect': true },
		{ 'method': 'DELETE', 'path': '/users/xyz', 'expect': true },
		{ 'method': 'GET', 'path': '/nonexistent', 'expect': false },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for test_case in test_cases {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route(test_case['method'], test_case['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			
			if test_case['expect'] == 'true' {
				success_count++
				println('  ✅ ${test_case['method']} ${test_case['path']} - 匹配成功 (${match_time})')
			} else {
				println('  ❌ ${test_case['method']} ${test_case['path']} - 意外匹配')
			}
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			
			if test_case['expect'] == 'false' {
				success_count++
				println('  ✅ ${test_case['method']} ${test_case['path']} - 正确未匹配 (${match_time})')
			} else {
				println('  ❌ ${test_case['method']} ${test_case['path']} - 匹配失败')
			}
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_cases.len)
	println('  📈 RESTful路由测试: ${success_count}/${test_cases.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_nested_resource_routes() {
	println('\n📊 嵌套资源路由测试...')
	
	mut app := hono.Hono.new()
	
	// 嵌套资源路由
	nested_routes := [
		// 博客系统
		'/blogs/:blog_id/posts/:post_id',
		'/blogs/:blog_id/posts/:post_id/comments/:comment_id',
		'/blogs/:blog_id/posts/:post_id/comments/:comment_id/replies/:reply_id',
		
		// 组织架构
		'/organizations/:org_id/departments/:dept_id',
		'/organizations/:org_id/departments/:dept_id/teams/:team_id',
		'/organizations/:org_id/departments/:dept_id/teams/:team_id/members/:member_id',
		
		// 项目管理
		'/projects/:project_id/milestones/:milestone_id',
		'/projects/:project_id/milestones/:milestone_id/tasks/:task_id',
		'/projects/:project_id/milestones/:milestone_id/tasks/:task_id/subtasks/:subtask_id',
		
		// 地理位置
		'/countries/:country_id/states/:state_id/cities/:city_id',
		'/countries/:country_id/states/:state_id/cities/:city_id/districts/:district_id',
	]
	
	for route in nested_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('nested response')
		})
	}
	
	// 测试嵌套路径
	test_paths := [
		'/blogs/tech-blog/posts/hello-world',
		'/blogs/personal/posts/my-journey/comments/great-post',
		'/blogs/dev/posts/v-lang-tips/comments/helpful/replies/thanks',
		'/organizations/acme-corp/departments/engineering',
		'/organizations/startup/departments/marketing/teams/growth',
		'/organizations/bigco/departments/sales/teams/enterprise/members/john-doe',
		'/projects/website-redesign/milestones/phase-1',
		'/projects/mobile-app/milestones/mvp/tasks/user-auth',
		'/projects/api-v2/milestones/beta/tasks/testing/subtasks/unit-tests',
		'/countries/usa/states/california/cities/san-francisco',
		'/countries/china/states/guangdong/cities/shenzhen/districts/nanshan',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			
			// 验证参数提取
			params := match_result.params
			param_count := params.len
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
	
	// 文件系统路由
	fs_routes := [
		'/files/:year/:month/:day/:filename',
		'/files/:category/:subcategory/:filename',
		'/uploads/:user_id/:folder/:filename',
		'/media/:type/:resolution/:filename',
		'/documents/:department/:project/:version/:filename',
		'/backups/:date/:time/:database/:filename',
		'/logs/:service/:level/:date/:filename',
		'/assets/:version/:type/:name',
	]
	
	for route in fs_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('file response')
		})
	}
	
	// 测试文件路径
	test_file_paths := [
		'/files/2023/12/26/document.pdf',
		'/files/images/avatars/user123.jpg',
		'/uploads/user456/photos/vacation.png',
		'/media/video/1080p/movie.mp4',
		'/documents/engineering/website/v2.1/spec.docx',
		'/backups/2023-12-26/14-30-00/userdb/backup.sql',
		'/logs/api-server/error/2023-12-26/error.log',
		'/assets/v1.2.3/css/main.css',
		'/files/2024/01/01/newyear.txt',
		'/media/audio/320kbps/song.mp3',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_file_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			
			// 验证文件名参数
			params := match_result.params
			filename := params['filename'] or { 'unknown' }
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
	
	// 多版本API路由
	api_versions := ['v1', 'v2', 'v3', 'beta', 'alpha']
	resources := ['users', 'posts', 'comments', 'files', 'settings']
	
	for version in api_versions {
		for resource in resources {
			// 基础CRUD路由
			app.get('/api/${version}/${resource}', fn (mut c hono.Context) http.Response {
				return c.text('list response')
			})
			app.get('/api/${version}/${resource}/:id', fn (mut c hono.Context) http.Response {
				return c.text('get response')
			})
			app.post('/api/${version}/${resource}', fn (mut c hono.Context) http.Response {
				return c.text('create response')
			})
			app.put('/api/${version}/${resource}/:id', fn (mut c hono.Context) http.Response {
				return c.text('update response')
			})
			app.delete('/api/${version}/${resource}/:id', fn (mut c hono.Context) http.Response {
				return c.text('delete response')
			})
		}
	}
	
	// 测试不同版本的API调用
	test_api_calls := [
		{ 'method': 'GET', 'path': '/api/v1/users' },
		{ 'method': 'GET', 'path': '/api/v2/users/123' },
		{ 'method': 'POST', 'path': '/api/v3/posts' },
		{ 'method': 'PUT', 'path': '/api/beta/comments/456' },
		{ 'method': 'DELETE', 'path': '/api/alpha/files/789' },
		{ 'method': 'GET', 'path': '/api/v1/settings' },
		{ 'method': 'GET', 'path': '/api/v2/posts/abc' },
		{ 'method': 'PUT', 'path': '/api/v3/users/xyz' },
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for api_call in test_api_calls {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route(api_call['method'], api_call['path']) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			println('  ✅ ${api_call['method']} ${api_call['path']} - 匹配成功 (${match_time})')
		} else {
			match_time := time.since(start_time)
			total_time += match_time
			println('  ❌ ${api_call['method']} ${api_call['path']} - 匹配失败 (${match_time})')
		}
	}
	
	avg_time := f64(total_time.microseconds()) / f64(test_api_calls.len)
	println('  📈 版本化API测试: ${success_count}/${test_api_calls.len} 通过, 平均耗时: ${avg_time:.3f}μs')
}

fn test_ecommerce_routes() {
	println('\n📊 电商平台路由测试...')
	
	mut app := hono.Hono.new()
	
	// 电商路由
	ecommerce_routes := [
		// 商品管理
		'/products/:product_id',
		'/products/:product_id/variants/:variant_id',
		'/products/:product_id/reviews/:review_id',
		'/products/:product_id/images/:image_id',
		
		// 分类管理
		'/categories/:category_id',
		'/categories/:category_id/subcategories/:subcategory_id',
		'/categories/:category_id/products',
		
		// 购物车和订单
		'/cart/:user_id',
		'/cart/:user_id/items/:item_id',
		'/orders/:order_id',
		'/orders/:order_id/items/:item_id',
		'/orders/:order_id/shipping/:shipping_id',
		'/orders/:order_id/payments/:payment_id',
		
		// 用户和地址
		'/customers/:customer_id',
		'/customers/:customer_id/addresses/:address_id',
		'/customers/:customer_id/orders',
		'/customers/:customer_id/wishlist/:item_id',
		
		// 商家管理
		'/merchants/:merchant_id',
		'/merchants/:merchant_id/products',
		'/merchants/:merchant_id/orders',
		'/merchants/:merchant_id/analytics/:report_id',
	]
	
	for route in ecommerce_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('ecommerce response')
		})
	}
	
	// 测试电商路径
	test_ecommerce_paths := [
		'/products/smartphone-x1',
		'/products/laptop-pro/variants/16gb-512gb',
		'/products/headphones/reviews/5-stars',
		'/categories/electronics/subcategories/phones',
		'/cart/user123/items/item456',
		'/orders/order789/shipping/express',
		'/customers/cust001/addresses/home',
		'/merchants/shop123/analytics/sales-report',
		'/products/tablet/images/front-view',
		'/orders/order456/payments/credit-card',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_ecommerce_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
			match_time := time.since(start_time)
			total_time += match_time
			success_count++
			
			// 提取关键参数
			params := match_result.params
			key_params := []string{}
			for key, value in params {
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
	
	// CMS路由
	cms_routes := [
		// 内容管理
		'/admin/content/:content_type/:content_id',
		'/admin/content/:content_type/:content_id/revisions/:revision_id',
		'/admin/content/:content_type/:content_id/comments/:comment_id',
		
		// 用户管理
		'/admin/users/:user_id',
		'/admin/users/:user_id/roles/:role_id',
		'/admin/users/:user_id/permissions/:permission_id',
		
		// 媒体管理
		'/admin/media/:media_type/:media_id',
		'/admin/media/:media_type/:media_id/metadata',
		'/admin/media/:media_type/:media_id/thumbnails/:size',
		
		// 系统管理
		'/admin/system/settings/:category/:setting_id',
		'/admin/system/logs/:service/:date/:log_id',
		'/admin/system/backups/:backup_type/:backup_id',
		
		// 前端路由
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
	
	// 测试CMS路径
	test_cms_paths := [
		'/admin/content/articles/how-to-code',
		'/admin/content/pages/about-us/revisions/v2',
		'/admin/users/editor123/roles/content-editor',
		'/admin/media/images/hero-banner/thumbnails/medium',
		'/admin/system/settings/general/site-title',
		'/admin/system/logs/web-server/2023-12-26/access-log',
		'/content/introduction-to-vlang',
		'/category/programming/1',
		'/author/john-doe/tutorials',
		'/tag/web-development',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_cms_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
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
	
	// 社交媒体路由
	social_routes := [
		// 用户资料
		'/users/:username',
		'/users/:username/posts',
		'/users/:username/followers',
		'/users/:username/following',
		
		// 帖子管理
		'/posts/:post_id',
		'/posts/:post_id/comments/:comment_id',
		'/posts/:post_id/likes',
		'/posts/:post_id/shares',
		'/posts/:post_id/comments/:comment_id/replies/:reply_id',
		
		// 群组和社区
		'/groups/:group_id',
		'/groups/:group_id/members/:member_id',
		'/groups/:group_id/posts/:post_id',
		'/groups/:group_id/events/:event_id',
		
		// 消息系统
		'/messages/:conversation_id',
		'/messages/:conversation_id/messages/:message_id',
		'/notifications/:notification_id',
		
		// 活动和事件
		'/events/:event_id',
		'/events/:event_id/attendees/:attendee_id',
		'/events/:event_id/photos/:photo_id',
	]
	
	for route in social_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('social response')
		})
	}
	
	// 测试社交媒体路径
	test_social_paths := [
		'/users/john_doe',
		'/users/jane_smith/posts',
		'/users/developer123/followers',
		'/posts/funny-meme-123/comments/great-post',
		'/posts/tech-news/comments/insightful/replies/thanks',
		'/groups/javascript-developers/members/newbie',
		'/groups/photographers/events/photo-walk',
		'/messages/chat-with-friend/messages/hello',
		'/notifications/friend-request-456',
		'/events/tech-conference/attendees/speaker123',
	]
	
	mut success_count := 0
	mut total_time := time.Duration(0)
	
	for path in test_social_paths {
		start_time := time.now()
		
		if match_result := app.fast_router.match_route('GET', path) {
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
	
	// 复杂参数路由
	complex_routes := [
		// 数字ID
		'/api/v:version/users/:user_id/posts/:post_id',
		'/products/:product_id/variants/:variant_id/inventory/:warehouse_id',
		
		// 字符串标识符
		'/blogs/:blog_slug/posts/:post_slug',
		'/categories/:category_slug/products/:product_slug',
		
		// 混合参数
		'/users/:username/projects/:project_name/branches/:branch_name',
		'/organizations/:org_slug/repositories/:repo_name/issues/:issue_number',
		
		// 日期参数
		'/reports/:year/:month/:day/:report_type',
		'/logs/:service/:year/:month/:day/:hour/:minute',
		
		// UUID参数
		'/sessions/:session_uuid/activities/:activity_uuid',
		'/transactions/:transaction_uuid/receipts/:receipt_uuid',
	]
	
	for route in complex_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('complex response')
		})
	}
	
	// 测试复杂参数路径
	test_complex_paths := [
		'/api/v2/users/12345/posts/67890',
		'/products/laptop-pro/variants/16gb-512gb/inventory/warehouse-west',
		'/blogs/tech-insights/posts/introduction-to-vlang',
		'/categories/electronics/products/smartphone-x1',
		'/users/developer/projects/awesome-app/branches/feature-auth',
		'/organizations/acme-corp/repositories/web-app/issues/42',
		'/reports/2023/12/26/sales',
		'/logs/api-server/2023/12/26/14/30',
		'/sessions/550e8400-e29b-41d4-a716-446655440000/activities/login-attempt',
		'/transactions/123e4567-e89b-12d3-a456-426614174000/receipts/payment-confirmation',
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
			
			// 统计参数数量
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
	avg_params := f64(total_params) / f64(success_count)
	println('  📈 复杂参数路由测试: ${success_count}/${test_complex_paths.len} 通过')
	println('  📊 平均耗时: ${avg_time:.3f}μs, 平均参数数: ${avg_params:.1f}个')
}

fn test_wildcard_routes() {
	println('\n📊 通配符路由测试...')
	
	mut app := hono.Hono.new()
	
	// 通配符路由 (注意：当前实现可能不支持*通配符，这里测试参数路由的边界情况)
	wildcard_routes := [
		'/static/:path',                    // 单级通配
		'/files/:category/:path',           // 分类文件
		'/proxy/:service/:path',            // 代理服务
		'/cdn/:version/:resource',          // CDN资源
		'/assets/:type/:name',              // 静态资源
	]
	
	for route in wildcard_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('wildcard response')
		})
	}
	
	// 测试通配符路径
	test_wildcard_paths := [
		'/static/css/main.css',
		'/static/js/app.min.js',
		'/static/images/logo.png',
		'/files/documents/report.pdf',
		'/files/images/photo.jpg',
		'/proxy/api-service/v1/users',
		'/proxy/auth-service/login',
		'/cdn/v1.2.3/bootstrap.css',
		'/cdn/latest/jquery.js',
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
			
			// 显示匹配的路径参数
			params := match_result.params
			path_param := params['path'] or { params['resource'] or { params['name'] or { 'unknown' } } }
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
	
	// 创建大量动态路由
	route_count := 500
	println('  创建 ${route_count} 个动态路由...')
	
	for i in 0 .. route_count {
		// 不同复杂度的路由
		simple_route := '/simple/:id${i}'
		medium_route := '/medium/:category${i}/:id${i}'
		complex_route := '/complex/:service${i}/:version${i}/:resource${i}/:id${i}'
		
		app.get(simple_route, fn (mut c hono.Context) http.Response {
			return c.text('simple response')
		})
		app.get(medium_route, fn (mut c hono.Context) http.Response {
			return c.text('medium response')
		})
		app.get(complex_route, fn (mut c hono.Context) http.Response {
			return c.text('complex response')
		})
	}
	
	// 生成测试路径
	mut test_paths := []string{}
	for i in 0 .. 100 {
		route_idx := i % route_count
		test_paths << '/simple/item${i}'
		test_paths << '/medium/cat${route_idx}/item${i}'
		test_paths << '/complex/svc${route_idx}/v1/res${route_idx}/item${i}'
	}
	
	println('  开始压力测试 (${test_paths.len} 个请求)...')
	
	// 压力测试
	iterations := 1000
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
	
	// 显示路由统计
	static_count, dynamic_count, cache_count := app.fast_router.get_stats()
	println('    路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
}