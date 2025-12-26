import hono
import time
import net.http

fn main() {
	println('=== 真实世界动态路由测试用例 ===')
	
	// 测试1: 电商平台路由
	test_ecommerce_routes()
	
	// 测试2: 社交媒体路由
	test_social_media_routes()
	
	// 测试3: 企业SaaS路由
	test_enterprise_saas_routes()
	
	// 测试4: 内容管理系统路由
	test_cms_routes()
	
	// 测试5: 金融服务路由
	test_financial_services_routes()
	
	// 测试6: 物联网平台路由
	test_iot_platform_routes()
	
	// 测试7: 教育平台路由
	test_education_platform_routes()
	
	println('✅ 真实世界动态路由测试完成')
}

fn test_ecommerce_routes() {
	println('\n📊 电商平台路由测试...')
	
	mut app := hono.Hono.new()
	
	// 电商平台典型路由
	ecommerce_routes := [
		// 商品管理
		'/products/:product_id',
		'/products/:product_id/reviews',
		'/products/:product_id/reviews/:review_id',
		'/products/:product_id/variants/:variant_id',
		'/products/:product_id/images/:image_id',
		
		// 分类和搜索
		'/categories/:category_id',
		'/categories/:category_id/subcategories/:subcategory_id',
		'/search/:query/filters/:filter_type/:filter_value',
		'/brands/:brand_id/products',
		
		// 用户和订单
		'/users/:user_id/orders',
		'/users/:user_id/orders/:order_id',
		'/users/:user_id/orders/:order_id/items/:item_id',
		'/users/:user_id/cart/items/:item_id',
		'/users/:user_id/wishlist/:product_id',
		'/users/:user_id/addresses/:address_id',
		
		// 支付和物流
		'/orders/:order_id/payments/:payment_id',
		'/orders/:order_id/shipments/:shipment_id',
		'/orders/:order_id/shipments/:shipment_id/tracking',
		'/payments/:payment_id/refunds/:refund_id',
		
		// 商家管理
		'/merchants/:merchant_id/products',
		'/merchants/:merchant_id/orders/:order_id',
		'/merchants/:merchant_id/analytics/:metric_type/:period',
		'/merchants/:merchant_id/inventory/:product_id',
		
		// 促销和优惠
		'/promotions/:promotion_id',
		'/coupons/:coupon_code/validate',
		'/discounts/:discount_id/products',
		'/flash-sales/:sale_id/products/:product_id'
	]
	
	for route in ecommerce_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('ecommerce response')
		})
	}
	
	// 电商场景测试用例
	ecommerce_tests := [
		{
			'path': '/products/prod123/reviews/rev456'
			'scenario': '查看商品评论'
			'expected_params': ['product_id:prod123', 'review_id:rev456']
		},
		{
			'path': '/categories/electronics/subcategories/smartphones'
			'scenario': '浏览商品分类'
			'expected_params': ['category_id:electronics', 'subcategory_id:smartphones']
		},
		{
			'path': '/users/user789/orders/order101/items/item202'
			'scenario': '查看订单商品详情'
			'expected_params': ['user_id:user789', 'order_id:order101', 'item_id:item202']
		},
		{
			'path': '/search/iphone/filters/price/100-500'
			'scenario': '商品搜索和过滤'
			'expected_params': ['query:iphone', 'filter_type:price', 'filter_value:100-500']
		},
		{
			'path': '/merchants/merchant456/analytics/sales/monthly'
			'scenario': '商家销售分析'
			'expected_params': ['merchant_id:merchant456', 'metric_type:sales', 'period:monthly']
		},
		{
			'path': '/orders/order789/shipments/ship123/tracking'
			'scenario': '订单物流跟踪'
			'expected_params': ['order_id:order789', 'shipment_id:ship123']
		}
	]
	
	test_route_scenarios(app, ecommerce_tests, '电商平台')
}

fn test_social_media_routes() {
	println('\n📊 社交媒体路由测试...')
	
	mut app := hono.Hono.new()
	
	// 社交媒体典型路由
	social_routes := [
		// 用户相关
		'/users/:user_id/profile',
		'/users/:user_id/posts',
		'/users/:user_id/posts/:post_id',
		'/users/:user_id/posts/:post_id/comments/:comment_id',
		'/users/:user_id/posts/:post_id/likes',
		'/users/:user_id/followers',
		'/users/:user_id/following',
		'/users/:user_id/messages/:conversation_id',
		
		// 内容互动
		'/posts/:post_id/comments',
		'/posts/:post_id/shares',
		'/posts/:post_id/reactions/:reaction_type',
		'/comments/:comment_id/replies',
		'/comments/:comment_id/likes',
		
		// 群组和页面
		'/groups/:group_id/posts',
		'/groups/:group_id/members/:member_id',
		'/groups/:group_id/events/:event_id',
		'/pages/:page_id/posts/:post_id',
		'/pages/:page_id/followers',
		
		// 消息和通知
		'/conversations/:conversation_id/messages/:message_id',
		'/notifications/:notification_id',
		'/notifications/types/:type/unread',
		
		// 媒体和文件
		'/media/:media_id/metadata',
		'/albums/:album_id/photos/:photo_id',
		'/videos/:video_id/comments/:comment_id',
		
		// 搜索和发现
		'/search/users/:query',
		'/search/posts/:query/filters/:filter',
		'/trending/:category/:timeframe',
		'/hashtags/:hashtag/posts'
	]
	
	for route in social_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('social response')
		})
	}
	
	// 社交媒体场景测试
	social_tests := [
		{
			'path': '/users/john_doe/posts/post123/comments/comment456'
			'scenario': '查看帖子评论'
			'expected_params': ['user_id:john_doe', 'post_id:post123', 'comment_id:comment456']
		},
		{
			'path': '/groups/tech_group/events/event789'
			'scenario': '查看群组活动'
			'expected_params': ['group_id:tech_group', 'event_id:event789']
		},
		{
			'path': '/conversations/conv101/messages/msg202'
			'scenario': '查看私信消息'
			'expected_params': ['conversation_id:conv101', 'message_id:msg202']
		},
		{
			'path': '/search/posts/artificial intelligence/filters/recent'
			'scenario': '搜索相关帖子'
			'expected_params': ['query:artificial intelligence', 'filter:recent']
		},
		{
			'path': '/hashtags/technology/posts'
			'scenario': '浏览话题标签'
			'expected_params': ['hashtag:technology']
		}
	]
	
	test_route_scenarios(app, social_tests, '社交媒体')
}

fn test_enterprise_saas_routes() {
	println('\n📊 企业SaaS路由测试...')
	
	mut app := hono.Hono.new()
	
	// 企业SaaS典型路由
	saas_routes := [
		// 组织管理
		'/orgs/:org_id/settings',
		'/orgs/:org_id/members/:member_id',
		'/orgs/:org_id/teams/:team_id/members',
		'/orgs/:org_id/departments/:dept_id/teams/:team_id',
		'/orgs/:org_id/roles/:role_id/permissions',
		
		// 项目管理
		'/projects/:project_id/tasks',
		'/projects/:project_id/tasks/:task_id/subtasks/:subtask_id',
		'/projects/:project_id/milestones/:milestone_id',
		'/projects/:project_id/files/:file_id/versions/:version_id',
		'/projects/:project_id/discussions/:discussion_id/replies/:reply_id',
		
		// 工作流和审批
		'/workflows/:workflow_id/steps/:step_id',
		'/approvals/:approval_id/history',
		'/processes/:process_id/instances/:instance_id',
		'/forms/:form_id/submissions/:submission_id',
		
		// 报告和分析
		'/reports/:report_id/data/:date_range',
		'/dashboards/:dashboard_id/widgets/:widget_id',
		'/analytics/:metric_type/:period/:granularity',
		'/kpis/:kpi_id/targets/:target_id',
		
		// 集成和API
		'/integrations/:integration_id/webhooks/:webhook_id',
		'/api-keys/:key_id/usage/:period',
		'/connectors/:connector_id/sync/:sync_id',
		
		// 计费和订阅
		'/subscriptions/:subscription_id/invoices/:invoice_id',
		'/billing/:org_id/usage/:service/:period',
		'/plans/:plan_id/features/:feature_id'
	]
	
	for route in saas_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('saas response')
		})
	}
	
	// 企业SaaS场景测试
	saas_tests := [
		{
			'path': '/orgs/company123/departments/engineering/teams/backend'
			'scenario': '查看部门团队'
			'expected_params': ['org_id:company123', 'dept_id:engineering', 'team_id:backend']
		},
		{
			'path': '/projects/proj456/tasks/task789/subtasks/subtask101'
			'scenario': '查看任务子任务'
			'expected_params': ['project_id:proj456', 'task_id:task789', 'subtask_id:subtask101']
		},
		{
			'path': '/analytics/revenue/quarterly/monthly'
			'scenario': '查看收入分析'
			'expected_params': ['metric_type:revenue', 'period:quarterly', 'granularity:monthly']
		},
		{
			'path': '/subscriptions/sub123/invoices/inv456'
			'scenario': '查看订阅发票'
			'expected_params': ['subscription_id:sub123', 'invoice_id:inv456']
		}
	]
	
	test_route_scenarios(app, saas_tests, '企业SaaS')
}

fn test_cms_routes() {
	println('\n📊 内容管理系统路由测试...')
	
	mut app := hono.Hono.new()
	
	// CMS典型路由
	cms_routes := [
		// 内容管理
		'/content/:content_id',
		'/content/:content_id/versions/:version_id',
		'/content/:content_id/comments/:comment_id',
		'/content/:content_id/attachments/:attachment_id',
		'/content/types/:type_id/fields/:field_id',
		
		// 分类和标签
		'/categories/:category_id/content',
		'/tags/:tag_id/content',
		'/taxonomies/:taxonomy_id/terms/:term_id',
		
		// 用户和权限
		'/users/:user_id/content',
		'/users/:user_id/drafts/:draft_id',
		'/roles/:role_id/permissions/:permission_id',
		'/workspaces/:workspace_id/users/:user_id',
		
		// 媒体库
		'/media/:media_id/metadata',
		'/media/folders/:folder_id/files',
		'/media/:media_id/thumbnails/:size',
		
		// 工作流
		'/workflows/:workflow_id/states/:state_id',
		'/content/:content_id/workflow/:workflow_id/transitions',
		'/approvals/:approval_id/reviewers/:reviewer_id',
		
		// 多语言
		'/content/:content_id/translations/:language',
		'/languages/:language_code/content',
		
		// 发布和分发
		'/sites/:site_id/pages/:page_id',
		'/channels/:channel_id/content/:content_id',
		'/distributions/:distribution_id/targets/:target_id'
	]
	
	for route in cms_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('cms response')
		})
	}
	
	// CMS场景测试
	cms_tests := [
		{
			'path': '/content/article123/versions/v2.1'
			'scenario': '查看内容版本'
			'expected_params': ['content_id:article123', 'version_id:v2.1']
		},
		{
			'path': '/workspaces/workspace456/users/editor789'
			'scenario': '管理工作空间用户'
			'expected_params': ['workspace_id:workspace456', 'user_id:editor789']
		},
		{
			'path': '/content/blog_post/translations/zh-CN'
			'scenario': '查看内容翻译'
			'expected_params': ['content_id:blog_post', 'language:zh-CN']
		}
	]
	
	test_route_scenarios(app, cms_tests, '内容管理系统')
}

fn test_financial_services_routes() {
	println('\n📊 金融服务路由测试...')
	
	mut app := hono.Hono.new()
	
	// 金融服务典型路由
	financial_routes := [
		// 账户管理
		'/accounts/:account_id/balance',
		'/accounts/:account_id/transactions/:transaction_id',
		'/accounts/:account_id/statements/:statement_id',
		'/customers/:customer_id/accounts/:account_id',
		
		// 交易和支付
		'/transactions/:transaction_id/details',
		'/payments/:payment_id/status',
		'/transfers/:transfer_id/tracking',
		'/cards/:card_id/transactions/:transaction_id',
		
		// 投资和理财
		'/portfolios/:portfolio_id/holdings/:holding_id',
		'/investments/:investment_id/performance/:period',
		'/funds/:fund_id/nav/:date',
		'/stocks/:symbol/quotes/:timestamp',
		
		// 贷款和信贷
		'/loans/:loan_id/payments/:payment_id',
		'/credit-cards/:card_id/bills/:bill_id',
		'/mortgages/:mortgage_id/schedule/:schedule_id',
		
		// 风控和合规
		'/risk-assessments/:assessment_id/factors/:factor_id',
		'/compliance/:rule_id/violations/:violation_id',
		'/kyc/:customer_id/documents/:document_id',
		'/aml/:case_id/investigations/:investigation_id',
		
		// 报告和分析
		'/reports/:report_type/:period/:format',
		'/analytics/:metric_type/:customer_segment/:timeframe'
	]
	
	for route in financial_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('financial response')
		})
	}
	
	// 金融服务场景测试
	financial_tests := [
		{
			'path': '/accounts/acc123/transactions/txn456'
			'scenario': '查看账户交易'
			'expected_params': ['account_id:acc123', 'transaction_id:txn456']
		},
		{
			'path': '/portfolios/port789/holdings/hold101'
			'scenario': '查看投资组合持仓'
			'expected_params': ['portfolio_id:port789', 'holding_id:hold101']
		},
		{
			'path': '/reports/profit_loss/quarterly/pdf'
			'scenario': '生成财务报告'
			'expected_params': ['report_type:profit_loss', 'period:quarterly', 'format:pdf']
		}
	]
	
	test_route_scenarios(app, financial_tests, '金融服务')
}

fn test_iot_platform_routes() {
	println('\n📊 物联网平台路由测试...')
	
	mut app := hono.Hono.new()
	
	// IoT平台典型路由
	iot_routes := [
		// 设备管理
		'/devices/:device_id/status',
		'/devices/:device_id/sensors/:sensor_id/data',
		'/devices/:device_id/firmware/:version_id',
		'/device-types/:type_id/templates/:template_id',
		
		// 数据和遥测
		'/telemetry/:device_id/:metric/:timerange',
		'/data-streams/:stream_id/points/:timestamp',
		'/sensors/:sensor_id/readings/:reading_id',
		'/events/:event_id/triggers/:trigger_id',
		
		// 网关和连接
		'/gateways/:gateway_id/devices/:device_id',
		'/networks/:network_id/nodes/:node_id',
		'/protocols/:protocol_id/configurations/:config_id',
		
		// 规则和自动化
		'/rules/:rule_id/conditions/:condition_id',
		'/automations/:automation_id/actions/:action_id',
		'/workflows/:workflow_id/steps/:step_id/triggers',
		
		// 监控和告警
		'/alerts/:alert_id/notifications/:notification_id',
		'/monitoring/:device_id/metrics/:metric_type/:period',
		'/dashboards/:dashboard_id/widgets/:widget_id/data',
		
		// 位置和地理
		'/locations/:location_id/devices',
		'/geofences/:geofence_id/events/:event_id',
		'/maps/:map_id/layers/:layer_id/markers/:marker_id'
	]
	
	for route in iot_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('iot response')
		})
	}
	
	// IoT平台场景测试
	iot_tests := [
		{
			'path': '/devices/sensor001/sensors/temperature/data'
			'scenario': '获取传感器数据'
			'expected_params': ['device_id:sensor001', 'sensor_id:temperature']
		},
		{
			'path': '/telemetry/device123/humidity/last_24h'
			'scenario': '查询设备遥测数据'
			'expected_params': ['device_id:device123', 'metric:humidity', 'timerange:last_24h']
		},
		{
			'path': '/rules/rule456/conditions/condition789'
			'scenario': '查看规则条件'
			'expected_params': ['rule_id:rule456', 'condition_id:condition789']
		}
	]
	
	test_route_scenarios(app, iot_tests, '物联网平台')
}

fn test_education_platform_routes() {
	println('\n📊 教育平台路由测试...')
	
	mut app := hono.Hono.new()
	
	// 教育平台典型路由
	education_routes := [
		// 课程管理
		'/courses/:course_id/lessons/:lesson_id',
		'/courses/:course_id/assignments/:assignment_id/submissions/:submission_id',
		'/courses/:course_id/quizzes/:quiz_id/questions/:question_id',
		'/courses/:course_id/discussions/:discussion_id/posts/:post_id',
		
		// 学生管理
		'/students/:student_id/enrollments/:enrollment_id',
		'/students/:student_id/grades/:grade_id',
		'/students/:student_id/progress/:course_id/:module_id',
		'/students/:student_id/certificates/:certificate_id',
		
		// 教师管理
		'/teachers/:teacher_id/courses/:course_id',
		'/teachers/:teacher_id/classes/:class_id/students',
		'/teachers/:teacher_id/gradebooks/:gradebook_id/entries/:entry_id',
		
		// 内容管理
		'/content/:content_id/versions/:version_id',
		'/libraries/:library_id/resources/:resource_id',
		'/media/:media_id/transcripts/:language',
		
		// 评估和考试
		'/exams/:exam_id/sessions/:session_id/answers/:answer_id',
		'/assessments/:assessment_id/rubrics/:rubric_id',
		'/proctoring/:session_id/recordings/:recording_id',
		
		// 学习分析
		'/analytics/:student_id/learning-paths/:path_id/progress',
		'/reports/:report_type/:class_id/:period',
		'/insights/:metric_type/:cohort_id/:timeframe'
	]
	
	for route in education_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('education response')
		})
	}
	
	// 教育平台场景测试
	education_tests := [
		{
			'path': '/courses/math101/lessons/lesson5'
			'scenario': '查看课程课时'
			'expected_params': ['course_id:math101', 'lesson_id:lesson5']
		},
		{
			'path': '/students/student123/progress/physics201/module3'
			'scenario': '查看学习进度'
			'expected_params': ['student_id:student123', 'course_id:physics201', 'module_id:module3']
		},
		{
			'path': '/exams/final_exam/sessions/session456/answers/answer789'
			'scenario': '查看考试答案'
			'expected_params': ['exam_id:final_exam', 'session_id:session456', 'answer_id:answer789']
		}
	]
	
	test_route_scenarios(app, education_tests, '教育平台')
}

// 通用的路由场景测试函数
fn test_route_scenarios(app hono.Hono, tests []map[string]string, platform_name string) {
	mut success_count := 0
	
	for test in tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			
			if expected_params_str := test['expected_params'] {
				expected_params := expected_params_str.split(',')
				
				for expected_param in expected_params {
					parts := expected_param.split(':')
					if parts.len == 2 {
						param_name := parts[0].trim_space()
						expected_value := parts[1].trim_space()
						
						if actual_value := match_result.params[param_name] {
							if actual_value != expected_value {
								params_correct = false
								break
							}
						} else {
							params_correct = false
							break
						}
					}
				}
			}
			
			if params_correct {
				success_count++
				println('  ✅ ${test['scenario']}: ${test['path']}')
			} else {
				println('  ❌ ${test['scenario']}: ${test['path']} (参数错误)')
			}
		} else {
			println('  ❌ ${test['scenario']}: ${test['path']} (匹配失败)')
		}
	}
	
	println('  ${platform_name}路由测试: ${success_count}/${tests.len} 通过')
}