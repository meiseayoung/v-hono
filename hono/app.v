module hono

import net.urllib
import net.http

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

pub struct Hono {
mut:
	server http.Server = http.Server{}
	routes map[string] Hono = {}
	base_path string
pub mut:
	context_router ContextRouter = ContextRouter{}
	context_hybrid_router ContextHybridRouter
	context_trie_router ContextTrieRouter
	context_middlewares []ContextMiddleware
}

// Context 中间件类型
type ContextMiddleware = fn (mut c Context, next fn (mut Context) http.Response) http.Response

// Context 接口方法
pub fn (mut app Hono) get(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{
		path: path
		handler: handler
	}
	app.context_hybrid_router.add_route('GET', h, '')
	app.context_trie_router.add_route('GET', path, h)
	app.context_router.handlers.get << h
}

pub fn (mut app Hono) post(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{
		path: path
		handler: handler
	}
	app.context_hybrid_router.add_route('POST', h, '')
	app.context_trie_router.add_route('POST', path, h)
	app.context_router.handlers.post << h
}

pub fn (mut app Hono) put(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	app.context_router.handlers.put << h
	app.context_hybrid_router.add_route('PUT', h, app.base_path)
	app.context_trie_router.add_route('PUT', path, h)
}

pub fn (mut app Hono) delete(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	app.context_router.handlers.delete << h
	app.context_hybrid_router.add_route('DELETE', h, app.base_path)
	app.context_trie_router.add_route('DELETE', path, h)
}

pub fn (mut app Hono) patch(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	app.context_router.handlers.patch << h
	app.context_hybrid_router.add_route('PATCH', h, app.base_path)
	app.context_trie_router.add_route('PATCH', path, h)
}

pub fn (mut app Hono) head(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	app.context_router.handlers.head << h
	app.context_hybrid_router.add_route('HEAD', h, app.base_path)
	app.context_trie_router.add_route('HEAD', path, h)
}

pub fn (mut app Hono) options(path string, handler fn (mut Context) http.Response) {
	h := ContextHandler{path, handler}
	app.context_router.handlers.options << h
	app.context_hybrid_router.add_route('OPTIONS', h, app.base_path)
	app.context_trie_router.add_route('OPTIONS', path, h)
}

// Context 中间件
pub fn (mut app Hono) use(mw ContextMiddleware) {
	app.context_middlewares << mw
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
	mut res := http.Response{
		status_code: 404
		body:        'Not Found'
	}
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
	if route_match := s.app.context_hybrid_router.match_route(req.method.str(), url.path) {
		// param 由路由匹配结果提供
		param_map := route_match.params.clone()
		// body
		body := req.data
		// 构造 Context
		mut ctx := Context.new(req, param_map, query_map, body)
		// 洋葱模型递归执行中间件
		return s.exec_context_middlewares(0, mut ctx, fn [route_match] (mut c Context) http.Response {
			return route_match.handler.handle(mut c)
		})
	} else {
		// 如果没有匹配的路由，也要执行中间件
		param_map := map[string]string{}
		body := req.data
		mut ctx := Context.new(req, param_map, query_map, body)
		return s.exec_context_middlewares(0, mut ctx, fn [res] (mut c Context) http.Response {
			return res
		})
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
	app.server.addr = port
	app.server.handler = server_hanler_new(app)
	app.server.listen_and_serve()
}

pub fn (mut app Hono) route(prefix string, mut subapp Hono) {
	// 简化路由合并，直接添加所有处理器
	app.routes[prefix] = subapp
	
	// 合并 Context 路由
	for handler in subapp.context_router.handlers.get {
		app.context_router.handlers.get << handler
	}
	for handler in subapp.context_router.handlers.post {
		app.context_router.handlers.post << handler
	}
	for handler in subapp.context_router.handlers.put {
		app.context_router.handlers.put << handler
	}
	for handler in subapp.context_router.handlers.delete {
		app.context_router.handlers.delete << handler
	}
	for handler in subapp.context_router.handlers.patch {
		app.context_router.handlers.patch << handler
	}
	for handler in subapp.context_router.handlers.head {
		app.context_router.handlers.head << handler
	}
	for handler in subapp.context_router.handlers.options {
		app.context_router.handlers.options << handler
	}
}

pub fn (mut app Hono) set_base_path(base_path string) {
	app.base_path = base_path
}

// 路由统计信息
pub fn (app Hono) get_router_stats() (int, int, int, int) {
	static_paths, dynamic_paths := app.context_hybrid_router.get_all_routes()
	cache_size, cache_capacity := app.context_hybrid_router.get_cache_stats()
	return static_paths.len, dynamic_paths.len, cache_size, cache_capacity
}

// 清理缓存
pub fn (mut app Hono) clear_cache() {
	app.context_hybrid_router.clear_cache()
}

pub fn Hono.new() Hono {
	return Hono{
		server: http.Server{}
		routes: map[string]Hono{}
		base_path: ''
		context_router: ContextRouter{}
		context_hybrid_router: ContextHybridRouter.new()
		context_trie_router: ContextTrieRouter.new()
	}
}
