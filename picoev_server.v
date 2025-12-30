module hono

import net
import net.http
import picoev
import picohttpparser

// picoev 服务器配置
pub struct PicoevConfig {
pub:
	port         int            = 8080
	host         string
	family       net.AddrFamily = .ip6
	timeout_secs int            = 30
	max_headers  int            = 100
	max_read     int            = 8192
	max_write    int            = 8192
}

// picoev 请求上下文
struct PicoevRequestContext {
mut:
	app &Hono = unsafe { nil }
}

// 使用 picoev 启动服务器
pub fn (mut app Hono) listen_picoev(port int) {
	app.listen_picoev_with_config(PicoevConfig{
		port: port
	})
}

// 使用 picoev 启动服务器（带配置）
pub fn (mut app Hono) listen_picoev_with_config(config PicoevConfig) {
	mut ctx := &PicoevRequestContext{
		app: unsafe { &app }
	}
	
	mut pico := picoev.new(
		port: config.port
		host: config.host
		family: config.family
		timeout_secs: config.timeout_secs
		max_headers: config.max_headers
		max_read: config.max_read
		max_write: config.max_write
		cb: picoev_callback
		user_data: ctx
	) or {
		eprintln('[v-hono] Failed to create picoev server: ${err}')
		return
	}
	
	host_str := if config.host == '' { '127.0.0.1' } else { config.host }
	println('[v-hono] Listening on http://${host_str}:${config.port}/ (picoev)')
	
	pico.serve()
}

// picoev 回调函数
fn picoev_callback(user_data voidptr, req picohttpparser.Request, mut res picohttpparser.Response) {
	mut ctx := unsafe { &PicoevRequestContext(user_data) }
	
	if ctx.app == unsafe { nil } {
		res.http_500()
		res.end()
		return
	}
	
	// 解析路径和查询参数
	path, query_map := parse_path_and_query(req.path)
	
	// 路由匹配
	method_str := req.method
	
	// 优先使用快速路由器
	if ctx.app.use_fast_router {
		if route_match := ctx.app.fast_router.match_route(method_str, path) {
			// 构造 Context
			mut hono_ctx := create_picoev_context(req, route_match.params, query_map)
			
			// 获取中间件
			middlewares := get_middlewares_for_path_picoev(ctx.app, path)
			
			// 执行中间件和处理器
			response := exec_middlewares_picoev(0, middlewares, mut hono_ctx, route_match.handler)
			
			// 发送响应
			send_picoev_response(mut res, hono_ctx, response)
			return
		}
	}
	
	// 回退到混合路由器
	if route_match := ctx.app.context_hybrid_router.match_route(method_str, path) {
		mut hono_ctx := create_picoev_context(req, route_match.params, query_map)
		
		// 获取中间件
		middlewares := get_middlewares_for_path_picoev(ctx.app, path)
		
		// 执行中间件和处理器
		response := exec_middlewares_picoev(0, middlewares, mut hono_ctx, route_match.handler)
		
		send_picoev_response(mut res, hono_ctx, response)
		return
	}
	
	// 404 Not Found - 检查自定义 notFound 处理器
	mut hono_ctx := create_picoev_context(req, map[string]string{}, query_map)
	
	if handler := ctx.app.not_found_handler {
		response := handler(mut hono_ctx)
		send_picoev_response(mut res, hono_ctx, response)
		return
	}
	
	// 默认 404 响应
	hono_ctx.status(404)
	res.raw('HTTP/1.1 404 Not Found\r\n')
	res.header('Content-Type', 'text/plain')
	res.header('Connection', 'keep-alive')
	res.body('Not Found')
	res.end()
}

// 获取路径对应的所有中间件（全局 + 路由前缀匹配的）
fn get_middlewares_for_path_picoev(app &Hono, path string) []ContextMiddleware {
	mut middlewares := app.context_middlewares.clone()
	
	// 按前缀长度排序，确保更具体的前缀后执行
	mut prefixes := app.route_middlewares.keys()
	prefixes.sort(a.len < b.len)
	
	for prefix in prefixes {
		if path.starts_with(prefix) || prefix == '/' {
			if mws := app.route_middlewares[prefix] {
				middlewares << mws
			}
		}
	}
	
	return middlewares
}

// 执行中间件链
fn exec_middlewares_picoev(idx int, middlewares []ContextMiddleware, mut ctx Context, handler IHandler) http.Response {
	if idx < middlewares.len {
		mw := middlewares[idx]
		return mw(mut ctx, fn [idx, middlewares, handler] (mut c Context) http.Response {
			return exec_middlewares_picoev(idx + 1, middlewares, mut c, handler)
		})
	} else {
		return handler.handle(mut ctx)
	}
}

// 解析路径和查询参数
fn parse_path_and_query(full_path string) (string, map[string]string) {
	mut query_map := map[string]string{}
	
	if idx := full_path.index('?') {
		path := full_path[..idx]
		query_str := full_path[idx + 1..]
		
		// 解析查询参数
		for part in query_str.split('&') {
			if eq_idx := part.index('=') {
				key := part[..eq_idx]
				value := part[eq_idx + 1..]
				query_map[key] = value
			}
		}
		
		return path, query_map
	}
	
	return full_path, query_map
}

// 创建 picoev 上下文
fn create_picoev_context(req picohttpparser.Request, params map[string]string, query map[string]string) Context {
	// 将 picohttpparser.Request 转换为需要的格式
	return Context{
		req: convert_picoev_request(req)
		params: params
		query: query
		body: req.body
		url: req.path
		path: req.path
		status_code: 200
		headers: map[string]string{}
	}
}

// 转换 picoev 请求
fn convert_picoev_request(req picohttpparser.Request) http.Request {
	mut headers := http.new_header()
	
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		headers.add_custom(h.name, h.value) or { continue }
	}
	
	return http.Request{
		method: match req.method {
			'GET' { http.Method.get }
			'POST' { http.Method.post }
			'PUT' { http.Method.put }
			'DELETE' { http.Method.delete }
			'PATCH' { http.Method.patch }
			'HEAD' { http.Method.head }
			'OPTIONS' { http.Method.options }
			else { http.Method.get }
		}
		url: req.path
		data: req.body
		header: headers
	}
}

// 发送 picoev 响应
fn send_picoev_response(mut res picohttpparser.Response, ctx Context, response http.Response) {
	// 设置状态码
	status_code := if ctx.status_code != 0 { ctx.status_code } else { response.status_code }
	
	if status_code == 200 {
		res.http_ok()
	} else {
		// 手动构建状态行
		status_text := get_status_text(status_code)
		res.raw('HTTP/1.1 ${status_code} ${status_text}\r\n')
	}
	
	// 设置响应头
	mut has_content_type := false
	mut has_connection := false
	
	// 从 Context 的 headers 中获取
	for key, value in ctx.headers {
		res.header(key, value)
		if key.to_lower() == 'content-type' {
			has_content_type = true
		}
		if key.to_lower() == 'connection' {
			has_connection = true
		}
	}
	
	// 从 http.Response 的 header 中获取
	if content_type := response.header.get(.content_type) {
		if !has_content_type {
			res.header('Content-Type', content_type)
			has_content_type = true
		}
	}
	
	// 默认 Content-Type
	if !has_content_type {
		res.header('Content-Type', 'text/plain')
	}
	
	// Keep-Alive
	if !has_connection {
		res.header('Connection', 'keep-alive')
	}
	
	// 设置响应体并发送
	res.body(response.body)
	res.end()  // 关键：必须调用 end() 来实际发送响应
}

// 获取状态码文本
fn get_status_text(code int) string {
	return match code {
		200 { 'OK' }
		201 { 'Created' }
		204 { 'No Content' }
		301 { 'Moved Permanently' }
		302 { 'Found' }
		304 { 'Not Modified' }
		400 { 'Bad Request' }
		401 { 'Unauthorized' }
		403 { 'Forbidden' }
		404 { 'Not Found' }
		405 { 'Method Not Allowed' }
		500 { 'Internal Server Error' }
		502 { 'Bad Gateway' }
		503 { 'Service Unavailable' }
		else { 'Unknown' }
	}
}
