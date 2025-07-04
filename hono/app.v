module hono

import net.urllib
import net.http

struct Router {
mut:
	handlers struct {
	mut:
		get     []IRequestHandler
		post    []IRequestHandler
		put     []IRequestHandler
		delete  []IRequestHandler
		patch   []IRequestHandler
		head    []IRequestHandler
		options []IRequestHandler
	}
}

pub struct Hono {
mut:
	server http.Server = http.Server{}
	router Router      = Router{}
	routes map[string] Hono = {}
	base_path string
pub mut:
	hybrid_router HybridRouter
}

pub fn (mut app Hono) get(path string, handler fn (Request) http.Response) {
	handlers := RequestHandler{path, handler}
	app.router.handlers.get << handlers
	app.hybrid_router.add_route('GET', handlers, app.base_path)
}

pub fn (mut app Hono) post(path string, handler fn (Request) http.Response) {
	handlers := RequestHandler{path, handler}
	app.router.handlers.post << handlers
	app.hybrid_router.add_route('POST', handlers, app.base_path)
}

pub fn (mut app Hono) put(path string, handler fn (Request) http.Response) {
	handlers := RequestHandler{path, handler}
	app.router.handlers.put << handlers
	app.hybrid_router.add_route('PUT', handlers, app.base_path)
}

pub fn (mut app Hono) delete(path string, handler fn (Request) http.Response) {
	handlers := RequestHandler{path, handler}
	app.router.handlers.delete << handlers
	app.hybrid_router.add_route('DELETE', handlers, app.base_path)
}

pub fn (mut app Hono) patch(path string, handler fn (Request) http.Response) {
	handlers := RequestHandler{path, handler}
	app.router.handlers.patch << handlers
	app.hybrid_router.add_route('PATCH', handlers, app.base_path)
}

pub fn (mut app Hono) head(path string, handler fn (Request) http.Response) {
	handlers := RequestHandler{path, handler}
	app.router.handlers.head << handlers
	app.hybrid_router.add_route('HEAD', handlers, app.base_path)
}

pub fn (mut app Hono) options(path string, handler fn (Request) http.Response) {
	handlers := RequestHandler{path, handler}
	app.router.handlers.options << handlers
	app.hybrid_router.add_route('OPTIONS', handlers, app.base_path)
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
	if route_match := s.app.hybrid_router.match_route(req.method.str(), url.path) {
		// 解析 query
		raw_query := url.query().to_map()
		mut query_map := map[string]string{}
		for key, values in raw_query {
			if values.len > 0 {
				query_map[key] = values[0]
			}
		}
		// param 由路由匹配结果提供
		param_map := route_match.params.clone()
		// body
		body := req.data
		// 构造 hono.Request
		hreq := Request{
			url: url.path
			param: param_map
			query: query_map
			body: body
		}
		res = route_match.handler.handle(hreq)
	}
	return res
}

pub fn (mut app Hono) listen(port string) {
	app.server.addr = port
	app.server.handler = server_hanler_new(app)
	app.server.listen_and_serve()
}

pub fn (mut app Hono) route(prefix string, mut subapp Hono) {
	// 简化路由合并，直接添加所有处理器
	app.routes[prefix] = subapp
	
	// 将子应用的路由添加到主应用
	for handler in subapp.router.handlers.get {
		app.router.handlers.get << handler
	}
	for handler in subapp.router.handlers.post {
		app.router.handlers.post << handler
	}
	for handler in subapp.router.handlers.put {
		app.router.handlers.put << handler
	}
	for handler in subapp.router.handlers.delete {
		app.router.handlers.delete << handler
	}
	for handler in subapp.router.handlers.patch {
		app.router.handlers.patch << handler
	}
	for handler in subapp.router.handlers.head {
		app.router.handlers.head << handler
	}
	for handler in subapp.router.handlers.options {
		app.router.handlers.options << handler
	}
}

pub fn (mut app Hono) set_base_path(base_path string) {
	app.base_path = base_path
}

pub fn (app Hono) get_router_stats() (int, int, int, int) {
	mut hybrid_router := app.hybrid_router
	static_routes, dynamic_routes := hybrid_router.get_all_routes()
	cache_size, cache_capacity := hybrid_router.get_cache_stats()
	return static_routes.len, dynamic_routes.len, cache_size, cache_capacity
}

pub fn (mut app Hono) clear_cache() {
	app.hybrid_router.clear_cache()
}

pub fn new_hono() Hono {
	return Hono{
		server: http.Server{}
		router: Router{}
		routes: map[string]Hono{}
		base_path: ''
		hybrid_router: new_hybrid_router()
	}
}
