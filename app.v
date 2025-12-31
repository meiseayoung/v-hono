module hono

import net.urllib
import net.http
import time

// Context 路由器
struct ContextRouter {
mut:
	handlers struct {
	mut:
		get     []IHandler
		post    []IHandler
		put     []IHandler
		delete  []IHandler
		patch   []IHandler
		head    []IHandler
		options []IHandler
	}
}

// NotFound 处理器类型
pub type NotFoundHandler = fn (mut c Context) http.Response

// Error 处理器类型 - 使用简单的错误信息和状态码
pub type ErrorHandler = fn (error_msg string, status_code int, mut c Context) http.Response

pub struct Hono {
mut:
	server http.Server = http.Server{}
	routes map[string] Hono = {}
	base_path string
	not_found_handler ?NotFoundHandler  // 自定义 404 处理器
	error_handler ?ErrorHandler         // 自定义错误处理器
pub mut:
	context_router ContextRouter = ContextRouter{}
	context_hybrid_router ContextHybridRouter
	context_trie_router ContextTrieRouter
	fast_router FastRouter  // 新增：快速路由器
	use_fast_router bool = true  // 新增：是否使用快速路由器
	context_middlewares []ContextMiddleware
	route_middlewares map[string][]ContextMiddleware  // 路由前缀对应的中间件
	// 优化：预排序的中间件前缀列表（启动时计算一次）
	sorted_middleware_prefixes []string
	// 优化：标记是否有中间件（用于零中间件快速路径）
	has_middlewares bool
}

// Context 中间件类型
type ContextMiddleware = fn (mut c Context, next fn (mut Context) http.Response) http.Response

// Context 接口方法
pub fn (mut app Hono) get(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{
		path: path
		handler: handler
	}
	
	// 添加到快速路由器
	if app.use_fast_router {
		app.fast_router.add_route('GET', h, '') or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('GET', h, '')
		}
	} else {
		app.context_hybrid_router.add_route('GET', h, '')
	}
	
	app.context_trie_router.add_route('GET', path, h)
	app.context_router.handlers.get << h
}

pub fn (mut app Hono) post(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{
		path: path
		handler: handler
	}
	
	// 添加到快速路由器
	if app.use_fast_router {
		app.fast_router.add_route('POST', h, '') or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('POST', h, '')
		}
	} else {
		app.context_hybrid_router.add_route('POST', h, '')
	}
	
	app.context_trie_router.add_route('POST', path, h)
	app.context_router.handlers.post << h
}

pub fn (mut app Hono) put(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	
	// 添加到快速路由器
	if app.use_fast_router {
		app.fast_router.add_route('PUT', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('PUT', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('PUT', h, app.base_path)
	}
	
	app.context_router.handlers.put << h
	app.context_trie_router.add_route('PUT', path, h)
}

pub fn (mut app Hono) delete(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	
	// 添加到快速路由器
	if app.use_fast_router {
		app.fast_router.add_route('DELETE', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('DELETE', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('DELETE', h, app.base_path)
	}
	
	app.context_router.handlers.delete << h
	app.context_trie_router.add_route('DELETE', path, h)
}

pub fn (mut app Hono) patch(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	
	// 添加到快速路由器
	if app.use_fast_router {
		app.fast_router.add_route('PATCH', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('PATCH', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('PATCH', h, app.base_path)
	}
	
	app.context_router.handlers.patch << h
	app.context_trie_router.add_route('PATCH', path, h)
}

pub fn (mut app Hono) head(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	
	// 添加到快速路由器
	if app.use_fast_router {
		app.fast_router.add_route('HEAD', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('HEAD', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('HEAD', h, app.base_path)
	}
	
	app.context_router.handlers.head << h
	app.context_trie_router.add_route('HEAD', path, h)
}

pub fn (mut app Hono) options(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	
	// 添加到快速路由器
	if app.use_fast_router {
		app.fast_router.add_route('OPTIONS', h, app.base_path) or {
			println('[WARNING] FastRouter failed to add route ${path}, falling back to hybrid router')
			app.context_hybrid_router.add_route('OPTIONS', h, app.base_path)
		}
	} else {
		app.context_hybrid_router.add_route('OPTIONS', h, app.base_path)
	}
	
	app.context_router.handlers.options << h
	app.context_trie_router.add_route('OPTIONS', path, h)
}

// all() 方法 - 为所有 HTTP 方法注册同一个处理器
pub fn (mut app Hono) all(path string, handler fn (mut Context) http.Response) {
	app.get(path, handler)
	app.post(path, handler)
	app.put(path, handler)
	app.delete(path, handler)
	app.patch(path, handler)
	app.head(path, handler)
	app.options(path, handler)
}

// Context 中间件
pub fn (mut app Hono) use(mw ContextMiddleware) {
	app.context_middlewares << mw
	app.has_middlewares = true
}

// 预计算中间件前缀排序（在服务器启动前调用）
pub fn (mut app Hono) precompute_middleware_prefixes() {
	app.sorted_middleware_prefixes = app.route_middlewares.keys()
	app.sorted_middleware_prefixes.sort(a.len < b.len)
	app.has_middlewares = app.context_middlewares.len > 0 || app.route_middlewares.len > 0
}

// notFound() - 自定义 404 处理器
pub fn (mut app Hono) not_found(handler NotFoundHandler) {
	app.not_found_handler = handler
}

// onError() - 自定义错误处理器
pub fn (mut app Hono) on_error(handler ErrorHandler) {
	app.error_handler = handler
}

struct ServerHanler {
mut:
	app Hono
}

fn server_hanler_new(app Hono) ServerHanler {
	return ServerHanler{
		app: app
	}
}

fn (mut s ServerHanler) handle(req http.Request) http.Response {
	url := urllib.parse(req.url) or {
		urllib.URL{
			path: '/'
		}
	}
	
	// 解析 query
	raw_query := url.query().to_map()
	mut query_map := map[string]string{}
	for key, values in raw_query {
		if values.len > 0 {
			query_map[key] = values[0]
		}
	}
	
	// 尝试 Context 路由
	// 优先使用快速路由器
	if s.app.use_fast_router {
		if route_match := s.app.fast_router.match_route(req.method.str(), url.path) {
			// param 由路由匹配结果提供
			param_map := route_match.params.clone()
			// body
			body := req.data
			// 构造 Context
			mut ctx := Context.new(req, param_map, query_map, body)
			
			// 优化：零中间件快速路径
			if !s.app.has_middlewares {
				return route_match.handler.handle(mut ctx)
			}
			
			// 获取该路径对应的中间件
			middlewares := s.get_middlewares_for_path(url.path)
			// 洋葱模型递归执行中间件
			return s.exec_context_middlewares_with_list(0, middlewares, mut ctx, fn [route_match] (mut c Context) http.Response {
				return route_match.handler.handle(mut c)
		})
		}
		
		// 如果快速路由器没有匹配，回退到混合路由器
		if route_match := s.app.context_hybrid_router.match_route(req.method.str(), url.path) {
			// param 由路由匹配结果提供
			param_map := route_match.params.clone()
			// body
			body := req.data
			// 构造 Context
			mut ctx := Context.new(req, param_map, query_map, body)
			
			// 优化：零中间件快速路径
			if !s.app.has_middlewares {
				return route_match.handler.handle(mut ctx)
			}
			
			// 获取该路径对应的中间件
			middlewares := s.get_middlewares_for_path(url.path)
			// 洋葱模型递归执行中间件
			return s.exec_context_middlewares_with_list(0, middlewares, mut ctx, fn [route_match] (mut c Context) http.Response {
				return route_match.handler.handle(mut c)
			})
		}
	} else {
		if route_match := s.app.context_hybrid_router.match_route(req.method.str(), url.path) {
			// param 由路由匹配结果提供
			param_map := route_match.params.clone()
			// body
			body := req.data
			// 构造 Context
			mut ctx := Context.new(req, param_map, query_map, body)
			
			// 优化：零中间件快速路径
			if !s.app.has_middlewares {
				return route_match.handler.handle(mut ctx)
			}
			
			// 获取该路径对应的中间件
			middlewares := s.get_middlewares_for_path(url.path)
			// 洋葱模型递归执行中间件
			return s.exec_context_middlewares_with_list(0, middlewares, mut ctx, fn [route_match] (mut c Context) http.Response {
				return route_match.handler.handle(mut c)
			})
		}
	}
	
	// 如果没有匹配的路由，使用 notFound 处理器
	param_map := map[string]string{}
	body := req.data
	mut ctx := Context.new(req, param_map, query_map, body)
	
	// 使用自定义 notFound 处理器或默认 404 响应
	if handler := s.app.not_found_handler {
		return s.exec_context_middlewares(0, mut ctx, handler)
	}
	
	// 默认 404 响应
	return s.exec_context_middlewares(0, mut ctx, fn (mut c Context) http.Response {
		c.status(404)
		return c.text('Not Found')
	})
}

// 获取路径对应的所有中间件（全局 + 路由前缀匹配的）- 优化版
fn (s ServerHanler) get_middlewares_for_path(path string) []ContextMiddleware {
	// 优化：只有全局中间件时，直接返回引用（避免克隆）
	if s.app.route_middlewares.len == 0 {
		return s.app.context_middlewares
	}
	
	mut middlewares := s.app.context_middlewares.clone()
	
	// 优化：使用预排序的前缀列表（启动时已排序，不需要每次请求都排序）
	for prefix in s.app.sorted_middleware_prefixes {
		if path.starts_with(prefix) || prefix == '/' {
			if mws := s.app.route_middlewares[prefix] {
				middlewares << mws
			}
		}
	}
	
	return middlewares
}

// 使用指定中间件列表执行
fn (mut s ServerHanler) exec_context_middlewares_with_list(idx int, middlewares []ContextMiddleware, mut ctx Context, handler fn (mut Context) http.Response) http.Response {
	if idx < middlewares.len {
		mw := middlewares[idx]
		return mw(mut ctx, fn [mut s, idx, middlewares, handler] (mut c Context) http.Response {
			return s.exec_context_middlewares_with_list(idx + 1, middlewares, mut c, handler)
		})
	} else {
		return handler(mut ctx)
	}
}

// Context 版本的中间件执行函数
fn (mut s ServerHanler) exec_context_middlewares(idx int, mut ctx Context, handler fn (mut Context) http.Response) http.Response {
	if idx < s.app.context_middlewares.len {
		mw := s.app.context_middlewares[idx]
		return mw(mut ctx, fn [mut s, idx, handler] (mut c Context) http.Response {
			return s.exec_context_middlewares(idx+1, mut c, handler)
		})
	} else {
		return handler(mut ctx)
	}
}

pub fn (mut app Hono) listen(port string) {
	// 解析端口号
	port_num := port.trim(':').int()
	if port_num <= 0 {
		eprintln('[v-hono] Invalid port: ${port}')
		return
	}
	
	// 优化：预计算中间件前缀排序
	app.precompute_middleware_prefixes()
	
	// 使用优化配置的 picoev 高性能服务器（支持高并发）
	app.listen_picoev_with_config(PicoevConfig{
		port: port_num
		timeout_secs: 120         // 高并发场景需要更长超时
		keepalive_timeout: 30     // Keep-Alive 超时 30 秒
		max_keepalive_req: 10000  // 单连接最大请求数
	})
}

// 使用传统 http.Server 启动（保留兼容性）
pub fn (mut app Hono) listen_http(port string) {
	app.server.addr = port
	app.server.handler = server_hanler_new(app)
	// 增加超时配置以支持更好的 Keep-Alive
	app.server.read_timeout = 60 * time.second
	app.server.write_timeout = 60 * time.second
	app.server.listen_and_serve()
}

pub fn (mut app Hono) route(prefix string, mut subapp Hono) {
	// 保存子应用引用
	app.routes[prefix] = subapp
	
	// 合并子应用的中间件到路由前缀
	if subapp.context_middlewares.len > 0 {
		if prefix in app.route_middlewares {
			app.route_middlewares[prefix] << subapp.context_middlewares
		} else {
			app.route_middlewares[prefix] = subapp.context_middlewares.clone()
		}
		app.has_middlewares = true
	}
	
	// 继承子应用的 notFound 和 onError 处理器（如果主应用没有设置）
	if app.not_found_handler == none && subapp.not_found_handler != none {
		// 子应用的 notFound 只对该前缀生效，这里不继承到主应用
		// 如果需要，可以在子应用路由匹配失败时单独处理
	}
	
	// 合并子应用的路由到主应用的所有路由器
	// 使用辅助函数来处理每种 HTTP 方法
	app.merge_routes_for_method('GET', prefix, subapp.context_router.handlers.get)
	app.merge_routes_for_method('POST', prefix, subapp.context_router.handlers.post)
	app.merge_routes_for_method('PUT', prefix, subapp.context_router.handlers.put)
	app.merge_routes_for_method('DELETE', prefix, subapp.context_router.handlers.delete)
	app.merge_routes_for_method('PATCH', prefix, subapp.context_router.handlers.patch)
	app.merge_routes_for_method('HEAD', prefix, subapp.context_router.handlers.head)
	app.merge_routes_for_method('OPTIONS', prefix, subapp.context_router.handlers.options)
}

// 辅助函数：合并指定 HTTP 方法的路由
fn (mut app Hono) merge_routes_for_method(method string, prefix string, handlers []IHandler) {
	for handler in handlers {
		// 创建带前缀的新路径
		mut new_path := ''
		if handler.path == '/' || handler.path == '' {
			// 如果子路由是根路径，直接使用前缀
			new_path = prefix
		} else if handler.path.starts_with('/') {
			new_path = '${prefix}${handler.path}'
		} else {
			new_path = '${prefix}/${handler.path}'
		}
		
		// 创建带新路径的包装 handler（实现 IHandler 接口）
		new_handler := PrefixedHandler{
			path: new_path
			inner: handler
		}
		
		// 为 trie_router 创建 ContextHandler
		trie_handler := ContextHandler{
			path: new_path
			handler: fn [handler] (mut c Context) http.Response {
				return handler.handle(mut c)
			}
		}
		
		// 添加到对应的 handlers 列表
		match method {
			'GET' { app.context_router.handlers.get << new_handler }
			'POST' { app.context_router.handlers.post << new_handler }
			'PUT' { app.context_router.handlers.put << new_handler }
			'DELETE' { app.context_router.handlers.delete << new_handler }
			'PATCH' { app.context_router.handlers.patch << new_handler }
			'HEAD' { app.context_router.handlers.head << new_handler }
			'OPTIONS' { app.context_router.handlers.options << new_handler }
			else {}
		}
		
		// 添加到快速路由器
		if app.use_fast_router {
			app.fast_router.add_route(method, new_handler, '') or {
				app.context_hybrid_router.add_route(method, new_handler, '')
			}
		} else {
			app.context_hybrid_router.add_route(method, new_handler, '')
		}
		app.context_trie_router.add_route(method, new_path, trie_handler)
	}
}

// 带前缀的 Handler 包装器，实现 IHandler 接口
pub struct PrefixedHandler {
pub:
	path  string
	inner IHandler
}

// 实现 IHandler 接口的 handle 方法
pub fn (h PrefixedHandler) handle(mut c Context) http.Response {
	return h.inner.handle(mut c)
}

pub fn (mut app Hono) set_base_path(base_path string) {
	app.base_path = base_path
}

// 路由统计信息
pub fn (app Hono) get_router_stats() (int, int, int, int) {
	if app.use_fast_router {
		static_count, dynamic_count, cache_count := app.fast_router.get_stats()
		return static_count, dynamic_count, cache_count, 0
	} else {
		static_paths, dynamic_paths := app.context_hybrid_router.get_all_routes()
		cache_size, cache_capacity := app.context_hybrid_router.get_cache_stats()
		return static_paths.len, dynamic_paths.len, cache_size, cache_capacity
	}
}

// 清理缓存
pub fn (mut app Hono) clear_cache() {
	if app.use_fast_router {
		app.fast_router.clear_cache()
	} else {
		app.context_hybrid_router.clear_cache()
	}
}

// 启用/禁用快速路由器
pub fn (mut app Hono) set_fast_router_enabled(enabled bool) {
	app.use_fast_router = enabled
	println('[INFO] FastRouter ${if enabled { 'enabled' } else { 'disabled' }}')
}

// 获取路由器性能分析
pub fn (mut app Hono) analyze_router_performance() {
	if app.use_fast_router {
		app.fast_router.analyze_performance()
	} else {
		app.context_hybrid_router.analyze_router_performance()
	}
}

pub fn Hono.new() Hono {
	return Hono{
		server: http.Server{}
		routes: map[string]Hono{}
		base_path: ''
		not_found_handler: none
		error_handler: none
		context_router: ContextRouter{}
		context_hybrid_router: ContextHybridRouter.new()
		context_trie_router: ContextTrieRouter.new()
		fast_router: FastRouter.new()
		use_fast_router: true
		route_middlewares: map[string][]ContextMiddleware{}
		sorted_middleware_prefixes: []string{}
		has_middlewares: false
	}
}
