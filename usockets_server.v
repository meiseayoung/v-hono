// uSockets Server Backend for V-Hono
// 
// 这个文件提供 V-Hono 的 uSockets 高性能服务器后端
// 
// 安装步骤:
// 1. 将 usockets 目录复制到 V-Hono 项目目录
// 2. 将此文件复制到 V-Hono 项目根目录
// 3. 修改 usockets/usockets.v 中的路径为绝对路径
//
// 使用方法:
//   app.listen_usockets(3000)  // 使用 uSockets 后端
//   app.listen(":3000")        // 使用默认 picoev 后端
//
// 编译命令 (必须使用 -enable-globals):
//   v -enable-globals -cc gcc -ldflags "-ldbghelp" your_app.v -o app.exe
//
// 性能对比 (200连接, 100K请求):
//   uSockets: ~22,000 RPS (高并发优化)
//   picoev:   ~15,000 RPS
//   
// 注意: uSockets 在高并发场景下优势明显 (~50% 提升)
//       低并发时两者性能相近

module hono

import usockets
import net.http
import strings

// uSockets 服务器配置
pub struct UsocketsConfig {
pub:
	port              int    = 8080
	host              string = '0.0.0.0'
	keepalive_timeout int    = 30
	max_keepalive_req int    = 10000
}

// 全局变量存储应用引用 (需要 -enable-globals 编译选项)
__global g_usockets_app = &Hono(unsafe { nil })
__global g_usockets_config = UsocketsConfig{}

// 使用 uSockets 启动服务器
pub fn (mut app Hono) listen_usockets(port int) {
	app.listen_usockets_with_config(UsocketsConfig{
		port: port
	})
}

// 使用 uSockets 启动服务器（带配置）
pub fn (mut app Hono) listen_usockets_with_config(config UsocketsConfig) {
	// 存储到全局变量
	g_usockets_app = unsafe { &app }
	g_usockets_config = config

	// 创建 uSockets 事件循环
	loop := usockets.create_loop()
	ctx := usockets.create_socket_context(loop)

	// 设置回调
	ctx.on_open(usockets_on_open)
	ctx.on_data(usockets_on_data)
	ctx.on_close(usockets_on_close)
	ctx.on_writable(usockets_on_writable)
	ctx.on_timeout(usockets_on_timeout)
	ctx.on_end(usockets_on_end)

	// 开始监听
	listener := ctx.listen(config.port)
	if listener.is_valid() {
		host_str := if config.host == '' { '127.0.0.1' } else { config.host }
		println('[v-hono] Listening on http://${host_str}:${config.port}/ (uSockets)')
		loop.run()
	} else {
		eprintln('[v-hono] Failed to listen on port ${config.port}')
	}
}

// uSockets 回调函数
fn usockets_on_open(s usockets.Socket, is_client int, ip &char, ip_length int) usockets.Socket {
	return s
}

fn usockets_on_data(s usockets.Socket, data &char, length int) usockets.Socket {
	if g_usockets_app == unsafe { nil } {
		s.write_bytes('HTTP/1.1 500 Internal Server Error\r\nContent-Length: 21\r\n\r\nInternal Server Error')
		return s
	}

	// 解析 HTTP 请求
	raw_data := unsafe { tos(&u8(data), length) }
	method, path, query_map, body := parse_http_request_usockets(raw_data)
	
	if method.len == 0 {
		s.write_bytes('HTTP/1.1 400 Bad Request\r\nContent-Length: 11\r\n\r\nBad Request')
		return s
	}

	// 路由匹配 - 优先使用快速路由器
	mut response_sent := false

	if g_usockets_app.use_fast_router {
		if route_match := g_usockets_app.fast_router.match_route(method, path) {
			mut hono_ctx := create_usockets_context(method, path, route_match.params, query_map, body)
			middlewares := get_middlewares_for_path_usockets(g_usockets_app, path)
			response := exec_middlewares_usockets(0, middlewares, mut hono_ctx, route_match.handler)
			send_usockets_response(s, hono_ctx, response)
			response_sent = true
		}
	}

	// 回退到混合路由器
	if !response_sent {
		if route_match := g_usockets_app.context_hybrid_router.match_route(method, path) {
			mut hono_ctx := create_usockets_context(method, path, route_match.params, query_map, body)
			middlewares := get_middlewares_for_path_usockets(g_usockets_app, path)
			response := exec_middlewares_usockets(0, middlewares, mut hono_ctx, route_match.handler)
			send_usockets_response(s, hono_ctx, response)
			response_sent = true
		}
	}

	// 404 Not Found
	if !response_sent {
		mut hono_ctx := create_usockets_context(method, path, map[string]string{}, query_map, body)

		if handler := g_usockets_app.not_found_handler {
			response := handler(mut hono_ctx)
			send_usockets_response(s, hono_ctx, response)
		} else {
			s.write_bytes('HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 9\r\nConnection: keep-alive\r\n\r\nNot Found')
		}
	}

	return s
}

fn usockets_on_close(s usockets.Socket, code int, reason voidptr) usockets.Socket {
	return s
}

fn usockets_on_writable(s usockets.Socket) usockets.Socket {
	return s
}

fn usockets_on_timeout(s usockets.Socket) usockets.Socket {
	return s.close()
}

fn usockets_on_end(s usockets.Socket) usockets.Socket {
	s.shutdown()
	return s.close()
}

// 解析 HTTP 请求
fn parse_http_request_usockets(raw string) (string, string, map[string]string, string) {
	mut method := ''
	mut path := ''
	mut query_map := map[string]string{}
	mut body := ''

	line_end := raw.index('\r\n') or { return method, path, query_map, body }
	request_line := raw[..line_end]

	parts := request_line.split(' ')
	if parts.len < 2 {
		return method, path, query_map, body
	}

	method = parts[0]
	full_path := parts[1]

	if query_idx := full_path.index('?') {
		path = full_path[..query_idx]
		query_str := full_path[query_idx + 1..]
		for part in query_str.split('&') {
			if eq_idx := part.index('=') {
				query_map[part[..eq_idx]] = part[eq_idx + 1..]
			}
		}
	} else {
		path = full_path
	}

	if body_start := raw.index('\r\n\r\n') {
		body = raw[body_start + 4..]
	}

	return method, path, query_map, body
}

// 创建 uSockets 上下文
fn create_usockets_context(method string, path string, params map[string]string, query map[string]string, body string) Context {
	return Context{
		req: http.Request{
			method: match method {
				'GET' { http.Method.get }
				'POST' { http.Method.post }
				'PUT' { http.Method.put }
				'DELETE' { http.Method.delete }
				'PATCH' { http.Method.patch }
				'HEAD' { http.Method.head }
				'OPTIONS' { http.Method.options }
				else { http.Method.get }
			}
			url: path
			data: body
		}
		params: params
		query: query
		body: body
		url: path
		path: path
		status_code: 200
		headers: map[string]string{}
	}
}

// 获取路径对应的所有中间件
fn get_middlewares_for_path_usockets(app &Hono, path string) []ContextMiddleware {
	mut middlewares := app.context_middlewares.clone()

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
fn exec_middlewares_usockets(idx int, middlewares []ContextMiddleware, mut ctx Context, handler IHandler) http.Response {
	if idx < middlewares.len {
		mw := middlewares[idx]
		return mw(mut ctx, fn [idx, middlewares, handler] (mut c Context) http.Response {
			return exec_middlewares_usockets(idx + 1, middlewares, mut c, handler)
		})
	}
	return handler.handle(mut ctx)
}

// 发送 uSockets 响应
fn send_usockets_response(s usockets.Socket, ctx Context, response http.Response) {
	status_code := if ctx.status_code != 0 { ctx.status_code } else { response.status_code }
	
	mut resp := strings.new_builder(512)
	
	// 状态行
	resp.write_string('HTTP/1.1 ')
	resp.write_string(status_code.str())
	resp.write_string(' ')
	resp.write_string(get_status_text_usockets(status_code))
	resp.write_string('\r\n')

	// 头部
	mut has_content_type := false
	for key, value in ctx.headers {
		if key.to_lower() == 'content-length' {
			continue
		}
		resp.write_string(key)
		resp.write_string(': ')
		resp.write_string(value)
		resp.write_string('\r\n')
		if key.to_lower() == 'content-type' {
			has_content_type = true
		}
	}

	if content_type := response.header.get(.content_type) {
		if !has_content_type {
			resp.write_string('Content-Type: ')
			resp.write_string(content_type)
			resp.write_string('\r\n')
			has_content_type = true
		}
	}

	if !has_content_type {
		resp.write_string('Content-Type: text/plain; charset=utf-8\r\n')
	}

	// Content-Length
	resp.write_string('Content-Length: ')
	resp.write_string(response.body.len.str())
	resp.write_string('\r\n')

	// Connection
	resp.write_string('Connection: keep-alive\r\n')

	// 空行 + body
	resp.write_string('\r\n')
	resp.write_string(response.body)

	s.write_bytes(resp.str())
}

// 获取状态码文本
fn get_status_text_usockets(code int) string {
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
