import hono
import time
import net.http
import regex

// 模拟没有缓存的路由器（用于对比）
struct NoCacheRouter {
mut:
	static_routes  map[string]hono.IHandler
	dynamic_routes []hono.IHandler
}

fn NoCacheRouter.new() NoCacheRouter {
	return NoCacheRouter{
		static_routes: map[string]hono.IHandler{}
		dynamic_routes: []hono.IHandler{}
	}
}

fn (mut router NoCacheRouter) add_route(method string, handler hono.IHandler, base_path string) {
	full_path := handler.path
	if !full_path.contains(':') && !full_path.contains('*') {
		router.static_routes['${method}:${full_path}'] = handler
	} else {
		router.dynamic_routes << handler
	}
}

// 每次都重新编译正则表达式（无缓存）
fn (router NoCacheRouter) match_route_no_cache(method string, path string) ?hono.ContextRouteMatch {
	// 静态路由匹配
	key := '${method}:${path}'
	if key in router.static_routes {
		return hono.ContextRouteMatch{
			handler: router.static_routes[key]
			params: map[string]string{}
			path: path
			base_path: ''
		}
	}
	
	// 动态路由匹配（每次重新编译正则表达式）
	for handler in router.dynamic_routes {
		if handler.path.contains(':') {
			// 每次都重新编译正则表达式
			mut replaced_path := handler.path
			mut param_names := []string{}
			
			// 转义特殊字符
			replaced_path = replaced_path.replace('?', r'\?')
			replaced_path = replaced_path.replace('+', r'\+')
			replaced_path = replaced_path.replace('.', r'\.')
			replaced_path = replaced_path.replace('(', r'\(')
			replaced_path = replaced_path.replace(')', r'\)')
			replaced_path = replaced_path.replace('[', r'\[')
			replaced_path = replaced_path.replace(']', r'\]')
			replaced_path = replaced_path.replace('{', r'\{')
			replaced_path = replaced_path.replace('}', r'\}')
			replaced_path = replaced_path.replace('^', r'\^')
			replaced_path = replaced_path.replace(r'$', r'\$')
			replaced_path = replaced_path.replace('|', r'\|')
			
			// 提取参数名并替换为命名捕获组
			mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { continue }
			replaced_path = param_reg.replace_by_fn(replaced_path, fn [mut param_names] (re regex.RE, in_txt string, start int, end int) string {
				param_name := in_txt[start+1..end]
				param_names << param_name
				return '(?P<${param_name}>[^/]+)'
			})
			
			replaced_path = '^${replaced_path}' + r'$'
			
			// 每次都重新编译正则表达式（这是性能瓶颈）
			mut reg := regex.regex_opt(replaced_path) or { continue }
			
			if reg.matches_string(path) {
				mut param_map := map[string]string{}
				for param_name in param_names {
					group := reg.get_group_by_name(path, param_name)
					param_map[param_name] = group
				}
				
				return hono.ContextRouteMatch{
					handler: handler
					params: param_map
					path: handler.path
					base_path: ''
				}
			}
		}
	}
	return none
}

fn main() {
	println('=== 路由性能对比测试 (缓存 vs 无缓存) ===')
	
	// 测试1: 小规模路由性能对比
	test_small_scale_performance()
	
	// 测试2: 大规模路由性能对比
	test_large_scale_performance()
	
	// 测试3: 复杂路由模式性能对比
	test_complex_patterns_performance()
	
	// 测试4: 缓存命中率测试
	test_cache_hit_rate()
	
	println('\n🎯 性能测试总结完成')
}

fn test_small_scale_performance() {
	println('\n📊 小规模路由性能对比 (10个动态路由)...')
	
	// 创建有缓存的路由器
	mut cached_router := hono.ContextHybridRouter.new()
	
	// 创建无缓存的路由器
	mut no_cache_router := NoCacheRouter.new()
	
	// 添加相同的动态路由
	dynamic_routes := [
		'/users/:id',
		'/posts/:post_id/comments/:comment_id',
		'/api/v1/users/:user_id/posts/:post_id',
		'/files/:category/:filename',
		'/search/:query',
		'/admin/users/:id/settings',
		'/api/v2/projects/:project_id/tasks/:task_id',
		'/shop/products/:id/reviews/:review_id',
		'/blog/:year/:month/:slug',
		'/docs/:section/:page'
	]
	
	for route in dynamic_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		cached_router.add_route('GET', handler, '')
		no_cache_router.add_route('GET', handler, '')
	}
	
	// 测试路径
	test_paths := [
		'/users/123',
		'/posts/456/comments/789',
		'/api/v1/users/101/posts/202',
		'/files/images/photo.jpg',
		'/search/test-query',
		'/admin/users/555/settings',
		'/api/v2/projects/777/tasks/888',
		'/shop/products/999/reviews/111',
		'/blog/2023/12/hello-world',
		'/docs/api/authentication'
	]
	
	iterations := 5000
	
	// 测试有缓存的路由器
	start_time1 := time.now()
	mut cached_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := cached_router.match_route('GET', path) {
				cached_matches++
			}
		}
	}
	cached_time := time.since(start_time1)
	
	// 测试无缓存的路由器
	start_time2 := time.now()
	mut no_cache_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := no_cache_router.match_route_no_cache('GET', path) {
				no_cache_matches++
			}
		}
	}
	no_cache_time := time.since(start_time2)
	
	println('  有缓存路由器 (${iterations}次 × ${test_paths.len}路径): ${cached_time}')
	println('  无缓存路由器 (${iterations}次 × ${test_paths.len}路径): ${no_cache_time}')
	println('  有缓存匹配: ${cached_matches}')
	println('  无缓存匹配: ${no_cache_matches}')
	
	if no_cache_time.milliseconds() > 0 && cached_time.milliseconds() > 0 {
		improvement := f64(no_cache_time.milliseconds()) / f64(cached_time.milliseconds())
		println('  🚀 缓存性能提升: ${improvement:.2f}x')
		
		if improvement > 1.5 {
			println('  ✅ 缓存优化效果显著')
		} else {
			println('  ⚠️  缓存优化效果不明显')
		}
	}
}

fn test_large_scale_performance() {
	println('\n📊 大规模路由性能对比 (100个动态路由)...')
	
	mut cached_router := hono.ContextHybridRouter.new()
	mut no_cache_router := NoCacheRouter.new()
	
	// 添加大量动态路由
	for i in 0 .. 100 {
		route := '/api/v${i}/resources/:id/items/:item_id'
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		cached_router.add_route('GET', handler, '')
		no_cache_router.add_route('GET', handler, '')
	}
	
	// 测试路径（匹配不同的路由）
	test_paths := [
		'/api/v1/resources/123/items/456',
		'/api/v25/resources/789/items/101',
		'/api/v50/resources/111/items/222',
		'/api/v75/resources/333/items/444',
		'/api/v99/resources/555/items/666'
	]
	
	iterations := 2000
	
	// 测试有缓存的路由器
	start_time1 := time.now()
	mut cached_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := cached_router.match_route('GET', path) {
				cached_matches++
			}
		}
	}
	cached_time := time.since(start_time1)
	
	// 测试无缓存的路由器
	start_time2 := time.now()
	mut no_cache_matches := 0
	for _ in 0 .. iterations {
		for path in test_paths {
			if _ := no_cache_router.match_route_no_cache('GET', path) {
				no_cache_matches++
			}
		}
	}
	no_cache_time := time.since(start_time2)
	
	println('  有缓存路由器 (${iterations}次 × ${test_paths.len}路径): ${cached_time}')
	println('  无缓存路由器 (${iterations}次 × ${test_paths.len}路径): ${no_cache_time}')
	
	if no_cache_time.milliseconds() > 0 && cached_time.milliseconds() > 0 {
		improvement := f64(no_cache_time.milliseconds()) / f64(cached_time.milliseconds())
		println('  🚀 大规模缓存性能提升: ${improvement:.2f}x')
		
		if improvement > 2.0 {
			println('  ✅ 大规模场景下缓存优化效果显著')
		} else {
			println('  ⚠️  大规模场景下缓存优化效果有限')
		}
	}
}

fn test_complex_patterns_performance() {
	println('\n📊 复杂路由模式性能对比...')
	
	mut cached_router := hono.ContextHybridRouter.new()
	mut no_cache_router := NoCacheRouter.new()
	
	// 添加复杂的动态路由
	complex_routes := [
		'/api/:version/users/:user_id/posts/:post_id/comments/:comment_id',
		'/shop/:category/:subcategory/products/:product_id/reviews/:review_id',
		'/admin/:module/:action/:resource_type/:resource_id',
		'/files/:year/:month/:day/:category/:filename',
		'/docs/:language/:version/:section/:subsection/:page'
	]
	
	for route in complex_routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		cached_router.add_route('GET', handler, '')
		no_cache_router.add_route('GET', handler, '')
	}
	
	// 复杂测试路径
	test_paths := [
		'/api/v1/users/123/posts/456/comments/789',
		'/shop/electronics/phones/products/999/reviews/111',
		'/admin/users/edit/profile/555',
		'/files/2023/12/26/images/photo.jpg',
		'/docs/en/v2/api/authentication/oauth'
	]
	
	iterations := 3000
	
	// 测试有缓存的路由器
	start_time1 := time.now()
	for _ in 0 .. iterations {
		for path in test_paths {
			cached_router.match_route('GET', path)
		}
	}
	cached_time := time.since(start_time1)
	
	// 测试无缓存的路由器
	start_time2 := time.now()
	for _ in 0 .. iterations {
		for path in test_paths {
			no_cache_router.match_route_no_cache('GET', path)
		}
	}
	no_cache_time := time.since(start_time2)
	
	println('  复杂模式有缓存 (${iterations}次 × ${test_paths.len}路径): ${cached_time}')
	println('  复杂模式无缓存 (${iterations}次 × ${test_paths.len}路径): ${no_cache_time}')
	
	if no_cache_time.milliseconds() > 0 && cached_time.milliseconds() > 0 {
		improvement := f64(no_cache_time.milliseconds()) / f64(cached_time.milliseconds())
		println('  🚀 复杂模式缓存性能提升: ${improvement:.2f}x')
		
		if improvement > 3.0 {
			println('  ✅ 复杂路由模式下缓存优化效果非常显著')
		} else if improvement > 2.0 {
			println('  ✅ 复杂路由模式下缓存优化效果显著')
		} else {
			println('  ⚠️  复杂路由模式下缓存优化效果有限')
		}
	}
}

fn test_cache_hit_rate() {
	println('\n📊 缓存命中率测试...')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加一些路由
	routes := ['/users/:id', '/posts/:id', '/files/:name']
	for route in routes {
		handler := hono.ContextHandler{
			path: route
			handler: fn (mut c hono.Context) http.Response {
				return c.text('test')
			}
		}
		router.add_route('GET', handler, '')
	}
	
	// 重复访问相同的路径（应该命中缓存）
	repeated_paths := ['/users/123', '/posts/456', '/files/test.txt']
	
	// 执行多次匹配
	for _ in 0 .. 1000 {
		for path in repeated_paths {
			router.match_route('GET', path)
		}
	}
	
	// 显示缓存统计
	cache_size, cache_capacity := router.get_cache_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	
	println('  路由缓存: ${cache_size}/${cache_capacity}')
	println('  正则缓存: ${regex_compiled}/${regex_total} 已编译')
	
	if regex_compiled > 0 {
		println('  ✅ 正则表达式缓存正常工作')
	} else {
		println('  ❌ 正则表达式缓存未生效')
	}
	
	// 显示性能分析
	router.analyze_router_performance()
}
