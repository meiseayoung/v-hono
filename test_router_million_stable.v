import hono
import time
import net.http
import regex

// 模拟没有缓存的路由器（用于对比修复前的性能）
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

// 每次都重新编译正则表达式（模拟修复前的行为）
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
			// 每次都重新编译正则表达式（这是性能瓶颈）
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
			replaced_path = replaced_path.replace('$', r'\$')
			replaced_path = replaced_path.replace('|', r'\|')
			
			// 提取参数名并替换为命名捕获组
			mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { continue }
			replaced_path = param_reg.replace_by_fn(replaced_path, fn [mut param_names] (re regex.RE, in_txt string, start int, end int) string {
				param_name := in_txt[start+1..end]
				param_names << param_name
				return '(?P<${param_name}>[^/]+)'
			})
			
			replaced_path = '^${replaced_path}$'
			
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
	println('=== 路由性能百万级基准测试 (修复前 vs 修复后) ===')
	
	// 测试1: 百万次路由匹配 - 小规模路由
	test_million_matches_small_scale()
	
	// 测试2: 百万次路由匹配 - 中等规模路由 (减少规模避免内存问题)
	test_million_matches_medium_scale()
	
	// 测试3: 百万次复杂路由匹配
	test_million_complex_routes()
	
	println('\n🎯 百万级基准测试完成')
}

fn test_million_matches_small_scale() {
	println('\n📊 百万次路由匹配 - 小规模 (10个动态路由)...')
	
	// 创建有缓存的路由器（修复后）
	mut cached_router := hono.ContextHybridRouter.new()
	
	// 创建无缓存的路由器（修复前）
	mut no_cache_router := NoCacheRouter.new()
	
	// 添加10个动态路由
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
	
	iterations := 100000  // 100万次 = 100000 * 10路径
	
	println('  准备进行 ${iterations * test_paths.len} 次路由匹配测试...')
	
	// 测试修复后的路由器（有缓存）
	println('  🚀 测试修复后路由器 (有正则缓存)...')
	start_time1 := time.now()
	mut cached_matches := 0
	for i in 0 .. iterations {
		for path in test_paths {
			if _ := cached_router.match_route('GET', path) {
				cached_matches++
			}
		}
		if i % 10000 == 0 {
			print('.')
		}
	}
	cached_time := time.since(start_time1)
	println('')
	
	// 测试修复前的路由器（无缓存）
	println('  🐌 测试修复前路由器 (无正则缓存)...')
	start_time2 := time.now()
	mut no_cache_matches := 0
	for i in 0 .. iterations {
		for path in test_paths {
			if _ := no_cache_router.match_route_no_cache('GET', path) {
				no_cache_matches++
			}
		}
		if i % 10000 == 0 {
			print('.')
		}
	}
	no_cache_time := time.since(start_time2)
	println('')
	
	println('  📊 小规模路由性能对比结果:')
	println('    修复后 (有缓存): ${cached_time} - 匹配成功: ${cached_matches}')
	println('    修复前 (无缓存): ${no_cache_time} - 匹配成功: ${no_cache_matches}')
	
	if no_cache_time.milliseconds() > 0 && cached_time.milliseconds() > 0 {
		improvement := f64(no_cache_time.milliseconds()) / f64(cached_time.milliseconds())
		println('    🎯 性能提升: ${improvement:.2f}x')
		
		avg_cached := f64(cached_time.microseconds()) / f64(cached_matches)
		avg_no_cache := f64(no_cache_time.microseconds()) / f64(no_cache_matches)
		println('    平均每次匹配 - 修复后: ${avg_cached:.2f}μs')
		println('    平均每次匹配 - 修复前: ${avg_no_cache:.2f}μs')
	}
}

fn test_million_matches_medium_scale() {
	println('\n📊 百万次路由匹配 - 中等规模 (20个动态路由)...')
	
	mut cached_router := hono.ContextHybridRouter.new()
	mut no_cache_router := NoCacheRouter.new()
	
	// 添加20个动态路由（减少数量避免内存问题）
	for i in 0 .. 20 {
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
		'/api/v5/resources/789/items/101',
		'/api/v10/resources/111/items/222',
		'/api/v15/resources/333/items/444',
		'/api/v19/resources/555/items/666'
	]
	
	iterations := 200000  // 100万次 = 200000 * 5路径
	
	println('  准备进行 ${iterations * test_paths.len} 次路由匹配测试...')
	
	// 测试修复后的路由器
	println('  🚀 测试修复后路由器...')
	start_time1 := time.now()
	mut cached_matches := 0
	for i in 0 .. iterations {
		for path in test_paths {
			if _ := cached_router.match_route('GET', path) {
				cached_matches++
			}
		}
		if i % 20000 == 0 {
			print('.')
		}
	}
	cached_time := time.since(start_time1)
	println('')
	
	// 测试修复前的路由器（分批测试避免内存问题）
	println('  🐌 测试修复前路由器 (分批测试)...')
	start_time2 := time.now()
	mut no_cache_matches := 0
	batch_size := 10000  // 分批处理
	
	for batch in 0 .. (iterations / batch_size) {
		for i in 0 .. batch_size {
			for path in test_paths {
				if _ := no_cache_router.match_route_no_cache('GET', path) {
					no_cache_matches++
				}
			}
		}
		print('.')
	}
	no_cache_time := time.since(start_time2)
	println('')
	
	println('  📊 中等规模路由性能对比结果:')
	println('    修复后 (有缓存): ${cached_time} - 匹配成功: ${cached_matches}')
	println('    修复前 (无缓存): ${no_cache_time} - 匹配成功: ${no_cache_matches}')
	
	if no_cache_time.milliseconds() > 0 && cached_time.milliseconds() > 0 {
		improvement := f64(no_cache_time.milliseconds()) / f64(cached_time.milliseconds())
		println('    🎯 性能提升: ${improvement:.2f}x')
	}
}

fn test_million_complex_routes() {
	println('\n📊 百万次复杂路由匹配测试...')
	
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
	
	iterations := 200000  // 100万次 = 200000 * 5路径
	
	println('  准备进行 ${iterations * test_paths.len} 次复杂路由匹配测试...')
	
	// 测试修复后的路由器
	println('  🚀 测试修复后路由器...')
	start_time1 := time.now()
	mut cached_matches := 0
	for i in 0 .. iterations {
		for path in test_paths {
			if _ := cached_router.match_route('GET', path) {
				cached_matches++
			}
		}
		if i % 20000 == 0 {
			print('.')
		}
	}
	cached_time := time.since(start_time1)
	println('')
	
	// 测试修复前的路由器（分批测试）
	println('  🐌 测试修复前路由器 (分批测试)...')
	start_time2 := time.now()
	mut no_cache_matches := 0
	batch_size := 20000  // 分批处理
	
	for batch in 0 .. (iterations / batch_size) {
		for i in 0 .. batch_size {
			for path in test_paths {
				if _ := no_cache_router.match_route_no_cache('GET', path) {
					no_cache_matches++
				}
			}
		}
		print('.')
	}
	no_cache_time := time.since(start_time2)
	println('')
	
	println('  📊 复杂路由性能对比结果:')
	println('    修复后 (有缓存): ${cached_time} - 匹配成功: ${cached_matches}')
	println('    修复前 (无缓存): ${no_cache_time} - 匹配成功: ${no_cache_matches}')
	
	if no_cache_time.milliseconds() > 0 && cached_time.milliseconds() > 0 {
		improvement := f64(no_cache_time.milliseconds()) / f64(cached_time.milliseconds())
		println('    🎯 性能提升: ${improvement:.2f}x')
	}
	
	// 显示缓存统计
	println('\n  📈 缓存统计信息:')
	cache_size, cache_capacity := cached_router.get_cache_stats()
	regex_total, regex_compiled := cached_router.get_regex_cache_stats()
	
	println('    路由缓存: ${cache_size}/${cache_capacity}')
	println('    正则缓存: ${regex_compiled}/${regex_total} 已编译')
	
	cached_router.analyze_router_performance()
}