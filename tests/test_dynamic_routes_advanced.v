import meiseayoung.hono
import net.http

fn main() {
	println('=== 高级动态路由测试用例 ===')
	
	// 测试1: 复杂嵌套参数路由
	test_complex_nested_routes()
	
	// 测试2: RESTful API 路由模式
	test_restful_api_patterns()
	
	// 测试3: 版本化API路由
	test_versioned_api_routes()
	
	// 测试4: 文件路径路由
	test_file_path_routes()
	
	// 测试5: 多语言路由
	test_multilingual_routes()
	
	// 测试6: 子域名路由模拟
	test_subdomain_simulation()
	
	// 测试7: 动态中间件路由
	test_dynamic_middleware_routes()
	
	println('✅ 高级动态路由测试完成')
}

fn test_complex_nested_routes() {
	println('\n📊 复杂嵌套参数路由测试...')
	
	mut app := hono.Hono.new()
	
	// 复杂嵌套路由定义
	complex_routes := [
		// 电商平台路由
		'/shop/:region/:city/stores/:store_id/products/:category/:product_id',
		'/shop/:region/:city/stores/:store_id/orders/:order_id/items/:item_id',
		'/shop/:region/:city/stores/:store_id/reviews/:review_id/replies/:reply_id',
		
		// 社交媒体路由
		'/social/:platform/users/:user_id/posts/:post_id/comments/:comment_id/likes',
		'/social/:platform/groups/:group_id/events/:event_id/attendees/:user_id',
		'/social/:platform/pages/:page_id/posts/:post_id/shares/:share_id',
		
		// 企业管理路由
		'/enterprise/:org_id/departments/:dept_id/teams/:team_id/members/:member_id',
		'/enterprise/:org_id/projects/:project_id/tasks/:task_id/subtasks/:subtask_id',
		'/enterprise/:org_id/budgets/:budget_id/categories/:category_id/items/:item_id'
	]
	
	// 添加路由
	for route in complex_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('Complex route response')
		})
	}
	
	// 测试路径
	test_cases := [
		{
			'route': '/shop/:region/:city/stores/:store_id/products/:category/:product_id'
			'path': '/shop/asia/beijing/stores/store123/products/electronics/phone456'
			'expected_params': 'region:asia,city:beijing,store_id:store123,category:electronics,product_id:phone456'
		},
		{
			'route': '/social/:platform/users/:user_id/posts/:post_id/comments/:comment_id/likes'
			'path': '/social/twitter/users/user789/posts/post101/comments/comment202/likes'
			'expected_params': 'platform:twitter,user_id:user789,post_id:post101,comment_id:comment202'
		},
		{
			'route': '/enterprise/:org_id/departments/:dept_id/teams/:team_id/members/:member_id'
			'path': '/enterprise/org999/departments/dept888/teams/team777/members/member666'
			'expected_params': 'org_id:org999,dept_id:dept888,team_id:team777,member_id:member666'
		}
	]
	
	mut success_count := 0
	for test_case in test_cases {
		if match_result := app.fast_router.match_route('GET', test_case['path']) {
			// 验证参数提取
			mut param_check_passed := true
			expected_params := test_case['expected_params'].split(',')
			
			for expected_param in expected_params {
				parts := expected_param.split(':')
				if parts.len == 2 {
					param_name := parts[0].trim_space()
					expected_value := parts[1].trim_space()
					
					if actual_value := match_result.params[param_name] {
						if actual_value != expected_value {
							param_check_passed = false
							break
						}
					} else {
						param_check_passed = false
						break
					}
				}
			}
			
			if param_check_passed {
				success_count++
				println('  ✅ ${test_case['path']} - 参数提取正确')
			} else {
				println('  ❌ ${test_case['path']} - 参数提取错误')
			}
		} else {
			println('  ❌ ${test_case['path']} - 路由匹配失败')
		}
	}
	
	println('  复杂嵌套路由测试: ${success_count}/${test_cases.len} 通过')
}

fn test_restful_api_patterns() {
	println('\n📊 RESTful API 路由模式测试...')
	
	mut app := hono.Hono.new()
	
	// RESTful 资源路由
	restful_patterns := [
		// 用户资源
		'/api/users',                           // GET: 列表, POST: 创建
		'/api/users/:id',                       // GET: 详情, PUT: 更新, DELETE: 删除
		'/api/users/:id/profile',               // GET: 用户资料
		'/api/users/:id/settings',              // GET/PUT: 用户设置
		
		// 嵌套资源
		'/api/users/:user_id/posts',            // GET: 用户文章列表, POST: 创建文章
		'/api/users/:user_id/posts/:post_id',   // GET: 文章详情, PUT: 更新, DELETE: 删除
		'/api/users/:user_id/posts/:post_id/comments',  // GET: 评论列表, POST: 添加评论
		'/api/users/:user_id/posts/:post_id/comments/:comment_id',  // GET/PUT/DELETE: 评论操作
		
		// 关系资源
		'/api/users/:user_id/followers',        // GET: 关注者列表
		'/api/users/:user_id/following',        // GET: 关注列表
		'/api/users/:user_id/follow/:target_id', // POST: 关注, DELETE: 取消关注
		
		// 搜索和过滤
		'/api/search/users/:query',             // GET: 搜索用户
		'/api/search/posts/:query',             // GET: 搜索文章
		'/api/filter/posts/:category/:tag',     // GET: 按分类和标签过滤
	]
	
	// 添加所有RESTful路由
	for pattern in restful_patterns {
		// 模拟不同HTTP方法
		app.get(pattern, fn (mut c hono.Context) http.Response {
			return c.text('GET response')
		})
		app.post(pattern, fn (mut c hono.Context) http.Response {
			return c.text('POST response')
		})
		app.put(pattern, fn (mut c hono.Context) http.Response {
			return c.text('PUT response')
		})
		app.delete(pattern, fn (mut c hono.Context) http.Response {
			return c.text('DELETE response')
		})
	}
	
	// 测试RESTful操作
	restful_tests := [
		{
			'method': 'GET'
			'path': '/api/users/123'
			'description': '获取用户详情'
		},
		{
			'method': 'POST'
			'path': '/api/users/123/posts'
			'description': '创建用户文章'
		},
		{
			'method': 'PUT'
			'path': '/api/users/123/posts/456'
			'description': '更新文章'
		},
		{
			'method': 'DELETE'
			'path': '/api/users/123/posts/456/comments/789'
			'description': '删除评论'
		},
		{
			'method': 'GET'
			'path': '/api/search/users/john'
			'description': '搜索用户'
		},
		{
			'method': 'GET'
			'path': '/api/filter/posts/tech/javascript'
			'description': '过滤文章'
		}
	]
	
	mut restful_success := 0
	for test in restful_tests {
		if _ := app.fast_router.match_route(test['method'], test['path']) {
			restful_success++
			println('  ✅ ${test['method']} ${test['path']} - ${test['description']}')
		} else {
			println('  ❌ ${test['method']} ${test['path']} - ${test['description']}')
		}
	}
	
	println('  RESTful API测试: ${restful_success}/${restful_tests.len} 通过')
}

fn test_versioned_api_routes() {
	println('\n📊 版本化API路由测试...')
	
	mut app := hono.Hono.new()
	
	// 版本化API路由
	versioned_routes := [
		// 版本1 API
		'/api/v1/users/:id',
		'/api/v1/posts/:id',
		'/api/v1/auth/login',
		
		// 版本2 API (向后兼容)
		'/api/v2/users/:id',
		'/api/v2/users/:id/profile',
		'/api/v2/posts/:id',
		'/api/v2/posts/:id/analytics',
		'/api/v2/auth/oauth/:provider',
		
		// 版本3 API (最新)
		'/api/v3/users/:id',
		'/api/v3/users/:id/preferences',
		'/api/v3/posts/:id',
		'/api/v3/posts/:id/engagement',
		'/api/v3/auth/sso/:provider/:tenant',
		
		// 通用版本路由
		'/api/:version/health',
		'/api/:version/status',
		'/api/:version/metrics/:metric_type'
	]
	
	for route in versioned_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('Versioned API response')
		})
	}
	
	// 版本兼容性测试
	version_tests := [
		{
			'path': '/api/v1/users/123'
			'expected_version': 'v1'
		},
		{
			'path': '/api/v2/users/456/profile'
			'expected_version': 'v2'
		},
		{
			'path': '/api/v3/auth/sso/google/tenant789'
			'expected_version': 'v3'
		},
		{
			'path': '/api/v2/health'
			'expected_version': 'v2'
		},
		{
			'path': '/api/v3/metrics/performance'
			'expected_version': 'v3'
		}
	]
	
	mut version_success := 0
	for test in version_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			// 检查版本参数
			if version := match_result.params['version'] {
				if version == test['expected_version'] {
					version_success++
					println('  ✅ ${test['path']} - 版本${version}')
				} else {
					println('  ❌ ${test['path']} - 版本不匹配: 期望${test['expected_version']}, 实际${version}')
				}
			} else {
				// 固定版本路由
				if test['path'].contains(test['expected_version']) {
					version_success++
					println('  ✅ ${test['path']} - 固定版本${test['expected_version']}')
				}
			}
		} else {
			println('  ❌ ${test['path']} - 路由匹配失败')
		}
	}
	
	println('  版本化API测试: ${version_success}/${version_tests.len} 通过')
}

fn test_file_path_routes() {
	println('\n📊 文件路径路由测试...')
	
	mut app := hono.Hono.new()
	
	// 文件系统路由
	file_routes := [
		// 基础文件路由
		'/files/:filename',
		'/files/:category/:filename',
		'/files/:year/:month/:filename',
		'/files/:year/:month/:day/:filename',
		
		// 用户文件路由
		'/users/:user_id/files/:filename',
		'/users/:user_id/files/:folder/:filename',
		'/users/:user_id/files/:folder/:subfolder/:filename',
		
		// 项目文件路由
		'/projects/:project_id/files/:path/:filename',
		'/projects/:project_id/versions/:version/files/:filename',
		'/projects/:project_id/branches/:branch/files/:path/:filename',
		
		// 媒体文件路由
		'/media/:type/:resolution/:filename',
		'/media/:type/:year/:month/:day/:filename',
		'/media/thumbnails/:size/:filename',
		
		// 文档路由
		'/docs/:language/:category/:filename',
		'/docs/:version/:language/:section/:filename'
	]
	
	for route in file_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('File response')
		})
	}
	
	// 文件路径测试用例
	file_tests := [
		{
			'path': '/files/document.pdf'
			'expected_params': 'filename:document.pdf'
		},
		{
			'path': '/files/images/photo.jpg'
			'expected_params': 'category:images,filename:photo.jpg'
		},
		{
			'path': '/files/2023/12/report.xlsx'
			'expected_params': 'year:2023,month:12,filename:report.xlsx'
		},
		{
			'path': '/users/user123/files/documents/contract.pdf'
			'expected_params': 'user_id:user123,folder:documents,filename:contract.pdf'
		},
		{
			'path': '/projects/proj456/versions/v1.2.3/files/readme.md'
			'expected_params': 'project_id:proj456,version:v1.2.3,filename:readme.md'
		},
		{
			'path': '/media/video/1080p/movie.mp4'
			'expected_params': 'type:video,resolution:1080p,filename:movie.mp4'
		},
		{
			'path': '/docs/en/api/authentication.md'
			'expected_params': 'language:en,category:api,filename:authentication.md'
		}
	]
	
	mut file_success := 0
	for test in file_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			expected_params := test['expected_params'].split(',')
			
			for expected_param in expected_params {
				parts := expected_param.split(':')
				if parts.len == 2 {
					param_name := parts[0]
					expected_value := parts[1]
					
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
			
			if params_correct {
				file_success++
				println('  ✅ ${test['path']} - 参数正确')
			} else {
				println('  ❌ ${test['path']} - 参数错误')
			}
		} else {
			println('  ❌ ${test['path']} - 路由匹配失败')
		}
	}
	
	println('  文件路径路由测试: ${file_success}/${file_tests.len} 通过')
}

fn test_multilingual_routes() {
	println('\n📊 多语言路由测试...')
	
	mut app := hono.Hono.new()
	
	// 多语言路由
	multilingual_routes := [
		// 基础多语言路由
		'/:lang/home',
		'/:lang/about',
		'/:lang/contact',
		
		// 多语言内容路由
		'/:lang/articles/:id',
		'/:lang/articles/:category/:slug',
		'/:lang/products/:id',
		'/:lang/products/:category/:product_id',
		
		// 多语言用户路由
		'/:lang/users/:id/profile',
		'/:lang/users/:id/settings',
		'/:lang/auth/login',
		'/:lang/auth/register',
		
		// 多语言API路由
		'/api/:lang/search/:query',
		'/api/:lang/translate/:from/:to/:text',
		
		// 地区化路由
		'/:country/:lang/stores',
		'/:country/:lang/stores/:store_id',
		'/:country/:lang/checkout/:step'
	]
	
	for route in multilingual_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('Multilingual response')
		})
	}
	
	// 多语言测试用例
	multilingual_tests := [
		{
			'path': '/en/home'
			'expected_lang': 'en'
		},
		{
			'path': '/zh/articles/tech/ai-revolution'
			'expected_lang': 'zh'
			'expected_category': 'tech'
			'expected_slug': 'ai-revolution'
		},
		{
			'path': '/fr/users/123/profile'
			'expected_lang': 'fr'
			'expected_id': '123'
		},
		{
			'path': '/api/es/search/machine learning'
			'expected_lang': 'es'
			'expected_query': 'machine learning'
		},
		{
			'path': '/us/en/stores/store456'
			'expected_country': 'us'
			'expected_lang': 'en'
			'expected_store_id': 'store456'
		},
		{
			'path': '/jp/ja/checkout/payment'
			'expected_country': 'jp'
			'expected_lang': 'ja'
			'expected_step': 'payment'
		}
	]
	
	mut multilingual_success := 0
	for test in multilingual_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			
			// 检查语言参数
			if expected_lang := test['expected_lang'] {
				if actual_lang := match_result.params['lang'] {
					if actual_lang != expected_lang {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			// 检查其他参数
			test_params := ['expected_category', 'expected_slug', 'expected_id', 'expected_query', 'expected_country', 'expected_store_id', 'expected_step']
			param_names := ['category', 'slug', 'id', 'query', 'country', 'store_id', 'step']
			
			for i, test_param in test_params {
				if expected_value := test[test_param] {
					param_name := param_names[i]
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
			
			if params_correct {
				multilingual_success++
				println('  ✅ ${test['path']} - 多语言参数正确')
			} else {
				println('  ❌ ${test['path']} - 多语言参数错误')
			}
		} else {
			println('  ❌ ${test['path']} - 路由匹配失败')
		}
	}
	
	println('  多语言路由测试: ${multilingual_success}/${multilingual_tests.len} 通过')
}

fn test_subdomain_simulation() {
	println('\n📊 子域名路由模拟测试...')
	
	mut app := hono.Hono.new()
	
	// 模拟子域名路由 (通过路径前缀)
	subdomain_routes := [
		// API子域名
		'/api.example.com/v1/users/:id',
		'/api.example.com/v1/posts/:id',
		'/api.example.com/health',
		
		// 管理子域名
		'/admin.example.com/dashboard',
		'/admin.example.com/users/:id',
		'/admin.example.com/settings/:section',
		
		// 用户子域名
		'/:username.example.com/profile',
		'/:username.example.com/posts',
		'/:username.example.com/posts/:post_id',
		
		// 多租户子域名
		'/:tenant.app.com/dashboard',
		'/:tenant.app.com/users/:user_id',
		'/:tenant.app.com/projects/:project_id',
		
		// 地区子域名
		'/:region.shop.com/products',
		'/:region.shop.com/products/:category',
		'/:region.shop.com/stores/:store_id'
	]
	
	for route in subdomain_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('Subdomain response')
		})
	}
	
	// 子域名测试用例
	subdomain_tests := [
		{
			'path': '/api.example.com/v1/users/123'
			'description': 'API子域名用户接口'
		},
		{
			'path': '/admin.example.com/users/456'
			'description': '管理子域名用户管理'
			'expected_id': '456'
		},
		{
			'path': '/john.example.com/posts/789'
			'description': '用户子域名文章'
			'expected_username': 'john'
			'expected_post_id': '789'
		},
		{
			'path': '/company1.app.com/projects/proj123'
			'description': '多租户项目管理'
			'expected_tenant': 'company1'
			'expected_project_id': 'proj123'
		},
		{
			'path': '/us.shop.com/products/electronics'
			'description': '地区商店产品'
			'expected_region': 'us'
			'expected_category': 'electronics'
		}
	]
	
	mut subdomain_success := 0
	for test in subdomain_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			
			// 检查参数
			if expected_id := test['expected_id'] {
				if actual_id := match_result.params['id'] {
					if actual_id != expected_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_username := test['expected_username'] {
				if actual_username := match_result.params['username'] {
					if actual_username != expected_username {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_post_id := test['expected_post_id'] {
				if actual_post_id := match_result.params['post_id'] {
					if actual_post_id != expected_post_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_tenant := test['expected_tenant'] {
				if actual_tenant := match_result.params['tenant'] {
					if actual_tenant != expected_tenant {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_project_id := test['expected_project_id'] {
				if actual_project_id := match_result.params['project_id'] {
					if actual_project_id != expected_project_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_region := test['expected_region'] {
				if actual_region := match_result.params['region'] {
					if actual_region != expected_region {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_category := test['expected_category'] {
				if actual_category := match_result.params['category'] {
					if actual_category != expected_category {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if params_correct {
				subdomain_success++
				println('  ✅ ${test['path']} - ${test['description']}')
			} else {
				println('  ❌ ${test['path']} - ${test['description']} (参数错误)')
			}
		} else {
			println('  ❌ ${test['path']} - ${test['description']} (匹配失败)')
		}
	}
	
	println('  子域名路由测试: ${subdomain_success}/${subdomain_tests.len} 通过')
}

fn test_dynamic_middleware_routes() {
	println('\n📊 动态中间件路由测试...')
	
	mut app := hono.Hono.new()
	
	// 需要不同中间件的路由
	middleware_routes := [
		// 需要认证的路由
		'/auth/profile/:id',
		'/auth/settings/:section',
		'/auth/admin/:action',
		
		// 需要权限检查的路由
		'/protected/users/:id/edit',
		'/protected/posts/:id/delete',
		'/protected/admin/:resource/:action',
		
		// 需要限流的路由
		'/rate-limited/api/:endpoint',
		'/rate-limited/upload/:type',
		'/rate-limited/search/:query',
		
		// 需要缓存的路由
		'/cached/articles/:id',
		'/cached/products/:category/:id',
		'/cached/static/:resource',
		
		// 需要日志记录的路由
		'/logged/transactions/:id',
		'/logged/audit/:action/:resource',
		'/logged/security/:event/:details'
	]
	
	for route in middleware_routes {
		app.get(route, fn (mut c hono.Context) http.Response {
			return c.text('Middleware route response')
		})
	}
	
	// 中间件路由测试
	middleware_tests := [
		{
			'path': '/auth/profile/user123'
			'middleware_type': 'authentication'
			'expected_id': 'user123'
		},
		{
			'path': '/protected/users/456/edit'
			'middleware_type': 'authorization'
			'expected_id': '456'
		},
		{
			'path': '/rate-limited/api/users'
			'middleware_type': 'rate_limiting'
			'expected_endpoint': 'users'
		},
		{
			'path': '/cached/articles/789'
			'middleware_type': 'caching'
			'expected_id': '789'
		},
		{
			'path': '/logged/transactions/txn101'
			'middleware_type': 'logging'
			'expected_id': 'txn101'
		},
		{
			'path': '/logged/audit/delete/user'
			'middleware_type': 'audit_logging'
			'expected_action': 'delete'
			'expected_resource': 'user'
		}
	]
	
	mut middleware_success := 0
	for test in middleware_tests {
		if match_result := app.fast_router.match_route('GET', test['path']) {
			mut params_correct := true
			
			// 验证参数提取
			if expected_id := test['expected_id'] {
				if actual_id := match_result.params['id'] {
					if actual_id != expected_id {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_endpoint := test['expected_endpoint'] {
				if actual_endpoint := match_result.params['endpoint'] {
					if actual_endpoint != expected_endpoint {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_action := test['expected_action'] {
				if actual_action := match_result.params['action'] {
					if actual_action != expected_action {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if expected_resource := test['expected_resource'] {
				if actual_resource := match_result.params['resource'] {
					if actual_resource != expected_resource {
						params_correct = false
					}
				} else {
					params_correct = false
				}
			}
			
			if params_correct {
				middleware_success++
				println('  ✅ ${test['path']} - ${test['middleware_type']} 中间件路由')
			} else {
				println('  ❌ ${test['path']} - ${test['middleware_type']} 中间件路由 (参数错误)')
			}
		} else {
			println('  ❌ ${test['path']} - ${test['middleware_type']} 中间件路由 (匹配失败)')
		}
	}
	
	println('  动态中间件路由测试: ${middleware_success}/${middleware_tests.len} 通过')
}