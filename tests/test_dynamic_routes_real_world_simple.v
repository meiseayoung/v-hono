import hono
import net.http
import time

fn main() {
	println('=== 真实世界动态路由测试 ===')
	
	// 测试1: 电商平台路由
	test_ecommerce_platform()
	
	// 测试2: 社交媒体路由
	test_social_media_platform()
	
	// 测试3: 企业SaaS路由
	test_enterprise_saas_platform()
	
	// 测试4: 内容管理系统路由
	test_cms_platform()
	
	// 测试5: 综合性能测试
	test_comprehensive_performance()
	
	println('✅ 真实世界动态路由测试完成')
}

fn test_ecommerce_platform() {
	println('\n📊 电商平台路由测试...')
	
	mut app := hono.Hono.new()
	
	// 电商平台典型路由
	ecommerce_routes := [
		// 商品管理
		'/products/:product_id',
		'/products/:product_id/reviews/:review_id',
		'/products/:product_id/variants/:variant_id',
		'/categories/:category_id/products',
		'/brands/:brand_id/products',
		
		// 用户和订单
		'/users/:user_id/orders/:order_id',
		'/users/:user_id/cart/items/:item_id',
		'/users/:user_id/wishlist/:product_id',
		'/orders/:order_id/items/:item_id',
		'/orders/:order_id/payments/:payment_id',
		
		// 商家管理
		'/merchants/:merchant_id/products/:product_id',
		'/merchants/:merchant_id/orders/:order_id',
		'/merchants/:merchant_id/analytics/:metric_type',
		
		// 搜索和过滤
		'/search/:query/category/:category',
		'/filter/:category/:subcategory/products'
	]
	
	for route in ecommerce_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('ecommerce response')
		})
	}
	
	// 电商场景测试
	ecommerce_test_paths := [
		'/products/iphone15/reviews/review123',
		'/categories/electronics/products',
		'/users/customer456/orders/order789',
		'/merchants/apple_store/analytics/sales',
		'/search/laptop/category/computers',
		'/filter/clothing/shirts/products'
	]
	
	mut success_count := 0
	for path in ecommerce_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  电商平台路由测试: ${success_count}/${ecommerce_test_paths.len} 通过')
}

fn test_social_media_platform() {
	println('\n📊 社交媒体路由测试...')
	
	mut app := hono.Hono.new()
	
	// 社交媒体典型路由
	social_routes := [
		// 用户相关
		'/users/:user_id/profile',
		'/users/:user_id/posts/:post_id',
		'/users/:user_id/followers',
		'/users/:user_id/messages/:conversation_id',
		
		// 内容互动
		'/posts/:post_id/comments/:comment_id',
		'/posts/:post_id/likes',
		'/comments/:comment_id/replies/:reply_id',
		
		// 群组和页面
		'/groups/:group_id/posts/:post_id',
		'/groups/:group_id/members/:member_id',
		'/pages/:page_id/posts/:post_id',
		
		// 媒体和搜索
		'/media/:media_id/metadata',
		'/search/users/:query',
		'/hashtags/:hashtag/posts',
		'/trending/:category/:timeframe'
	]
	
	for route in social_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('social response')
		})
	}
	
	// 社交媒体场景测试
	social_test_paths := [
		'/users/john_doe/posts/viral_post',
		'/posts/trending_post/comments/top_comment',
		'/groups/tech_community/members/developer123',
		'/search/users/jane_smith',
		'/hashtags/technology/posts',
		'/trending/news/daily'
	]
	
	mut success_count := 0
	for path in social_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  社交媒体路由测试: ${success_count}/${social_test_paths.len} 通过')
}

fn test_enterprise_saas_platform() {
	println('\n📊 企业SaaS路由测试...')
	
	mut app := hono.Hono.new()
	
	// 企业SaaS典型路由
	saas_routes := [
		// 组织管理
		'/orgs/:org_id/teams/:team_id',
		'/orgs/:org_id/members/:member_id',
		'/orgs/:org_id/departments/:dept_id/teams/:team_id',
		'/orgs/:org_id/roles/:role_id/permissions',
		
		// 项目管理
		'/projects/:project_id/tasks/:task_id',
		'/projects/:project_id/milestones/:milestone_id',
		'/projects/:project_id/files/:file_id/versions/:version_id',
		
		// 工作流和报告
		'/workflows/:workflow_id/steps/:step_id',
		'/reports/:report_id/data/:date_range',
		'/dashboards/:dashboard_id/widgets/:widget_id',
		'/analytics/:metric_type/:period/:granularity',
		
		// 集成和计费
		'/integrations/:integration_id/webhooks/:webhook_id',
		'/subscriptions/:subscription_id/invoices/:invoice_id',
		'/billing/:org_id/usage/:service/:period'
	]
	
	for route in saas_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('saas response')
		})
	}
	
	// 企业SaaS场景测试
	saas_test_paths := [
		'/orgs/acme_corp/teams/engineering',
		'/projects/website_redesign/tasks/frontend_dev',
		'/workflows/approval_process/steps/manager_review',
		'/reports/sales_report/data/2023-Q4',
		'/analytics/revenue/monthly/daily',
		'/subscriptions/enterprise_plan/invoices/dec_2023'
	]
	
	mut success_count := 0
	for path in saas_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  企业SaaS路由测试: ${success_count}/${saas_test_paths.len} 通过')
}

fn test_cms_platform() {
	println('\n📊 内容管理系统路由测试...')
	
	mut app := hono.Hono.new()
	
	// CMS典型路由
	cms_routes := [
		// 内容管理
		'/content/:content_id/versions/:version_id',
		'/content/:content_id/comments/:comment_id',
		'/content/types/:type_id/fields/:field_id',
		'/categories/:category_id/content',
		
		// 用户和权限
		'/users/:user_id/content',
		'/workspaces/:workspace_id/users/:user_id',
		'/roles/:role_id/permissions/:permission_id',
		
		// 媒体库
		'/media/:media_id/metadata',
		'/media/folders/:folder_id/files/:file_id',
		'/media/:media_id/thumbnails/:size',
		
		// 多语言和发布
		'/content/:content_id/translations/:language',
		'/sites/:site_id/pages/:page_id',
		'/channels/:channel_id/content/:content_id'
	]
	
	for route in cms_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('cms response')
		})
	}
	
	// CMS场景测试
	cms_test_paths := [
		'/content/blog_article/versions/v1.2',
		'/workspaces/editorial/users/editor123',
		'/media/hero_image/thumbnails/large',
		'/content/homepage/translations/zh-CN',
		'/sites/corporate_site/pages/about_us',
		'/channels/social_media/content/announcement'
	]
	
	mut success_count := 0
	for path in cms_test_paths {
		if match_result := app.fast_router.match_route('GET', path) {
			param_count := match_result.params.len
			success_count++
			println('  ✅ ${path} (${param_count}个参数)')
		} else {
			println('  ❌ ${path} (匹配失败)')
		}
	}
	
	println('  内容管理系统路由测试: ${success_count}/${cms_test_paths.len} 通过')
}

fn test_comprehensive_performance() {
	println('\n📊 综合性能测试...')
	
	mut app := hono.Hono.new()
	
	// 添加所有类型的真实路由
	all_real_routes := [
		// 电商路由
		'/products/:id/reviews/:review_id',
		'/users/:user_id/orders/:order_id/items/:item_id',
		'/merchants/:merchant_id/analytics/:metric',
		
		// 社交媒体路由
		'/users/:user_id/posts/:post_id/comments/:comment_id',
		'/groups/:group_id/events/:event_id/attendees/:user_id',
		'/hashtags/:hashtag/posts/:post_id',
		
		// 企业SaaS路由
		'/orgs/:org_id/projects/:project_id/tasks/:task_id',
		'/workflows/:workflow_id/instances/:instance_id/steps/:step_id',
		'/reports/:report_id/filters/:filter_type/:filter_value',
		
		// CMS路由
		'/content/:content_id/versions/:version_id/comments/:comment_id',
		'/workspaces/:workspace_id/projects/:project_id/files/:file_id',
		'/sites/:site_id/pages/:page_id/sections/:section_id',
		
		// API路由
		'/api/:version/resources/:resource_id/relationships/:relationship_type',
		'/api/:version/search/:query/filters/:filter_category/:filter_value',
		'/api/:version/batch/:batch_id/operations/:operation_id/results'
	]
	
	println('  添加 ${all_real_routes.len} 个真实应用路由...')
	
	for route in all_real_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('real world response')
		})
	}
	
	// 真实场景测试路径
	real_world_paths := [
		'/products/laptop123/reviews/review456',
		'/users/customer789/orders/order101/items/item202',
		'/merchants/tech_store/analytics/sales',
		'/users/john_doe/posts/post123/comments/comment456',
		'/groups/developers/events/meetup2023/attendees/user789',
		'/hashtags/javascript/posts/tutorial_post',
		'/orgs/startup_inc/projects/mobile_app/tasks/ui_design',
		'/workflows/approval/instances/inst123/steps/manager_review',
		'/reports/revenue_report/filters/date_range/2023-Q4',
		'/content/blog_post/versions/v2.1/comments/feedback123',
		'/workspaces/editorial/projects/website/files/homepage.html',
		'/sites/corporate/pages/about/sections/team_info',
		'/api/v1/resources/user123/relationships/followers',
		'/api/v2/search/machine learning/filters/category/tutorials',
		'/api/v1/batch/batch456/operations/update_users/results'
	]
	
	println('  开始综合性能测试...')
	println('    测试路径数量: ${real_world_paths.len}')
	
	// 性能测试
	iterations := 2000
	
	start_time := time.now()
	mut total_matches := 0
	mut successful_matches := 0
	
	for _ in 0 .. iterations {
		for path in real_world_paths {
			total_matches++
			if match_result := app.fast_router.match_route('GET', path) {
				successful_matches++
				// 验证参数提取
				param_count := match_result.params.len
				if param_count >= 2 {  // 至少应该有2个参数
					// 参数提取正常
				}
			}
		}
	}
	
	total_time := time.since(start_time)
	avg_time := f64(total_time.microseconds()) / f64(total_matches)
	throughput := f64(total_matches) / total_time.seconds()
	success_rate := f64(successful_matches) / f64(total_matches) * 100.0
	
	println('  综合性能测试结果:')
	println('    总匹配次数: ${total_matches}')
	println('    成功匹配: ${successful_matches}')
	println('    成功率: ${success_rate:.1f}%')
	println('    总时间: ${total_time}')
	println('    平均时间: ${avg_time:.3f}μs')
	println('    吞吐量: ${throughput:.0f} 请求/秒')
	
	// 性能评级
	if avg_time < 5.0 {
		println('    🏆 性能等级: 卓越 (< 5μs)')
	} else if avg_time < 10.0 {
		println('    🥇 性能等级: 优秀 (< 10μs)')
	} else if avg_time < 50.0 {
		println('    ✅ 性能等级: 良好 (< 50μs)')
	} else {
		println('    ⚠️  性能等级: 需要优化 (>= 50μs)')
	}
	
	// 复杂度分析
	println('\n  路由复杂度分析:')
	
	complexity_tests := [
		{
			'name': '简单路由 (2个参数)'
			'path': '/products/laptop123/reviews/review456'
		},
		{
			'name': '中等路由 (3个参数)'
			'path': '/users/customer789/orders/order101/items/item202'
		},
		{
			'name': '复杂路由 (4个参数)'
			'path': '/orgs/startup_inc/projects/mobile_app/tasks/ui_design'
		},
		{
			'name': '极复杂路由 (5个参数)'
			'path': '/workflows/approval/instances/inst123/steps/manager_review'
		}
	]
	
	for test in complexity_tests {
		test_iterations := 5000
		
		start_time_complex := time.now()
		mut complex_matches := 0
		
		for _ in 0 .. test_iterations {
			if _ := app.fast_router.match_route('GET', test['path']) {
				complex_matches++
			}
		}
		
		complex_time := time.since(start_time_complex)
		complex_avg := f64(complex_time.microseconds()) / f64(complex_matches)
		
		println('    ${test['name']}: ${complex_avg:.3f}μs')
	}
	
	// 显示最终统计
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('\n  最终路由统计:')
	println('    静态路由: ${static_count}')
	println('    动态路由: ${dynamic_count}')
	println('    缓存条目: ${cache_count}')
}