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
	// 优化：预计算中间件前缀排序
	app.precompute_middleware_prefixes()
	
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

// ============================================================================
// WebSocket Upgrade Detection and Handling for uSockets
// ============================================================================

// Check if a raw HTTP request is a WebSocket upgrade request
fn is_usockets_ws_upgrade(raw_data string) bool {
	// Check for Upgrade: websocket header (case-insensitive)
	mut has_upgrade := false
	mut has_connection := false
	mut has_ws_key := false
	
	lines := raw_data.split('\r\n')
	for line in lines {
		lower_line := line.to_lower()
		if lower_line.starts_with('upgrade:') {
			if lower_line.contains('websocket') {
				has_upgrade = true
			}
		} else if lower_line.starts_with('connection:') {
			if lower_line.contains('upgrade') {
				has_connection = true
			}
		} else if lower_line.starts_with('sec-websocket-key:') {
			has_ws_key = true
		}
	}
	
	return has_upgrade && has_connection && has_ws_key
}

// Get WebSocket key from raw HTTP request headers
fn get_usockets_ws_key(raw_data string) string {
	lines := raw_data.split('\r\n')
	for line in lines {
		if line.to_lower().starts_with('sec-websocket-key:') {
			parts := line.split(':')
			if parts.len >= 2 {
				return parts[1..].join(':').trim_space()
			}
		}
	}
	return ''
}

// Get WebSocket protocol from raw HTTP request headers
fn get_usockets_ws_protocol(raw_data string) string {
	lines := raw_data.split('\r\n')
	for line in lines {
		if line.to_lower().starts_with('sec-websocket-protocol:') {
			parts := line.split(':')
			if parts.len >= 2 {
				return parts[1..].join(':').trim_space()
			}
		}
	}
	return ''
}

// Get WebSocket version from raw HTTP request headers
fn get_usockets_ws_version(raw_data string) string {
	lines := raw_data.split('\r\n')
	for line in lines {
		if line.to_lower().starts_with('sec-websocket-version:') {
			parts := line.split(':')
			if parts.len >= 2 {
				return parts[1..].join(':').trim_space()
			}
		}
	}
	return '13'
}

// Handle WebSocket upgrade for uSockets
// Returns true if upgrade was successful, false otherwise
fn handle_usockets_ws_upgrade(s usockets.Socket, raw_data string, route_match ContextRouteMatch, hono_ctx Context) bool {
	// Validate WebSocket version
	ws_version := get_usockets_ws_version(raw_data)
	if ws_version != '13' {
		s.write_bytes('HTTP/1.1 426 Upgrade Required\r\nSec-WebSocket-Version: 13\r\nContent-Type: text/plain\r\nContent-Length: 28\r\n\r\nUnsupported WebSocket version')
		return false
	}
	
	// Get WebSocket key
	ws_key := get_usockets_ws_key(raw_data)
	if ws_key.len == 0 {
		s.write_bytes('HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nContent-Length: 30\r\n\r\nMissing Sec-WebSocket-Key header')
		return false
	}
	
	// Compute accept key
	accept_key := compute_accept_key(ws_key)
	
	// Execute the route handler to get WSEvents
	mut mutable_ctx := hono_ctx
	response := route_match.handler.handle(mut mutable_ctx)
	
	// Check if this is a WebSocket upgrade response
	if response.status_code != 101 {
		// Not a WebSocket upgrade, send the response as-is
		send_usockets_response(s, mutable_ctx, response)
		return false
	}
	
	// Negotiate subprotocol
	mut selected_protocol := ''
	if '_ws_protocol' in mutable_ctx.store {
		selected_protocol = mutable_ctx.store['_ws_protocol']
	}
	
	// Build and send WebSocket handshake response
	mut resp := strings.new_builder(256)
	resp.write_string('HTTP/1.1 101 Switching Protocols\r\n')
	resp.write_string('Upgrade: websocket\r\n')
	resp.write_string('Connection: Upgrade\r\n')
	resp.write_string('Sec-WebSocket-Accept: ')
	resp.write_string(accept_key)
	resp.write_string('\r\n')
	if selected_protocol.len > 0 {
		resp.write_string('Sec-WebSocket-Protocol: ')
		resp.write_string(selected_protocol)
		resp.write_string('\r\n')
	}
	resp.write_string('\r\n')
	
	s.write_bytes(resp.str())
	
	// Note: After the handshake, the connection is now in WebSocket mode.
	// The uSockets backend will continue to receive data on this socket,
	// but it will be WebSocket frames instead of HTTP requests.
	// For full WebSocket support, additional frame handling would be needed
	// in the usockets_on_data callback.
	
	return true
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

	// Check if this is a WebSocket upgrade request
	is_ws_upgrade := is_usockets_ws_upgrade(raw_data)

	// 路由匹配 - 优先使用快速路由器
	mut response_sent := false

	if g_usockets_app.use_fast_router {
		if route_match := g_usockets_app.fast_router.match_route(method, path) {
			mut hono_ctx := create_usockets_context(method, path, route_match.params, query_map, body)
			
			// Handle WebSocket upgrade if detected
			if is_ws_upgrade {
				// Parse headers for WebSocket context
				hono_ctx = create_usockets_context_with_headers(raw_data, method, path, route_match.params, query_map, body)
				if handle_usockets_ws_upgrade(s, raw_data, route_match, hono_ctx) {
					// WebSocket upgrade successful
					return s
				}
				// If upgrade failed, response was already sent
				return s
			}
			
			// 优化1：零中间件快速路径
			if !g_usockets_app.has_middlewares {
				response := route_match.handler.handle(mut hono_ctx)
				send_usockets_response(s, hono_ctx, response)
			} else {
				middlewares := get_middlewares_for_path_usockets_optimized(g_usockets_app, path)
				response := exec_middlewares_usockets(0, middlewares, mut hono_ctx, route_match.handler)
				send_usockets_response(s, hono_ctx, response)
			}
			response_sent = true
		}
	}

	// 回退到混合路由器
	if !response_sent {
		if route_match := g_usockets_app.context_hybrid_router.match_route(method, path) {
			mut hono_ctx := create_usockets_context(method, path, route_match.params, query_map, body)
			
			// Handle WebSocket upgrade if detected
			if is_ws_upgrade {
				// Parse headers for WebSocket context
				hono_ctx = create_usockets_context_with_headers(raw_data, method, path, route_match.params, query_map, body)
				if handle_usockets_ws_upgrade(s, raw_data, route_match, hono_ctx) {
					// WebSocket upgrade successful
					return s
				}
				// If upgrade failed, response was already sent
				return s
			}
			
			// 优化1：零中间件快速路径
			if !g_usockets_app.has_middlewares {
				response := route_match.handler.handle(mut hono_ctx)
				send_usockets_response(s, hono_ctx, response)
			} else {
				middlewares := get_middlewares_for_path_usockets_optimized(g_usockets_app, path)
				response := exec_middlewares_usockets(0, middlewares, mut hono_ctx, route_match.handler)
				send_usockets_response(s, hono_ctx, response)
			}
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


// 解析 HTTP 请求 - 零分配优化版
// 使用指针遍历避免创建临时数组
fn parse_http_request_usockets(raw string) (string, string, map[string]string, string) {
	mut method := ''
	mut path := ''
	mut query_map := map[string]string{}
	mut body := ''
	
	len := raw.len
	if len == 0 {
		return method, path, query_map, body
	}
	
	// 1. 查找第一行结束位置（\r\n）
	mut line_end := -1
	for i in 0 .. len - 1 {
		if raw[i] == `\r` && raw[i + 1] == `\n` {
			line_end = i
			break
		}
	}
	if line_end == -1 {
		return method, path, query_map, body
	}
	
	// 2. 解析 method（到第一个空格）
	mut method_end := 0
	for method_end < line_end && raw[method_end] != ` ` {
		method_end++
	}
	if method_end == 0 || method_end >= line_end {
		return method, path, query_map, body
	}
	method = raw[..method_end]
	
	// 3. 解析 path 和 query（从空格后到下一个空格）
	mut path_start := method_end + 1
	// 跳过多余空格
	for path_start < line_end && raw[path_start] == ` ` {
		path_start++
	}
	
	mut path_end := path_start
	mut query_start := -1
	for path_end < line_end && raw[path_end] != ` ` {
		if raw[path_end] == `?` && query_start == -1 {
			query_start = path_end + 1
		}
		path_end++
	}
	
	if query_start > 0 {
		path = raw[path_start..query_start - 1]
		// 解析 query string（单次遍历）
		query_map = parse_query_string_fast(raw, query_start, path_end)
	} else {
		path = raw[path_start..path_end]
	}
	
	// 4. 查找 body（\r\n\r\n 之后）
	for i in line_end .. len - 3 {
		if raw[i] == `\r` && raw[i + 1] == `\n` && raw[i + 2] == `\r` && raw[i + 3] == `\n` {
			if i + 4 < len {
				body = raw[i + 4..]
			}
			break
		}
	}
	
	return method, path, query_map, body
}

// 快速解析 query string（单次遍历，避免 split）
@[inline]
fn parse_query_string_fast(raw string, start int, end int) map[string]string {
	mut query_map := map[string]string{}
	
	mut key_start := start
	mut key_end := -1
	mut value_start := -1
	
	for i := start; i <= end; i++ {
		ch := if i < end { raw[i] } else { `&` } // 末尾视为分隔符
		
		if ch == `=` && key_end == -1 {
			key_end = i
			value_start = i + 1
		} else if ch == `&` {
			// 完成一个键值对
			if key_end > key_start && value_start > 0 {
				key := raw[key_start..key_end]
				value := if value_start < i { raw[value_start..i] } else { '' }
				query_map[key] = value
			} else if key_end == -1 && i > key_start {
				// 只有 key 没有 value
				key := raw[key_start..i]
				query_map[key] = ''
			}
			// 重置状态
			key_start = i + 1
			key_end = -1
			value_start = -1
		}
	}
	
	return query_map
}

// 创建 uSockets 上下文 - 优化版
fn create_usockets_context(method string, path string, params map[string]string, query map[string]string, body string) Context {
	return Context{
		req: http.Request{
			method: parse_http_method_usockets(method)
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

// 创建 uSockets 上下文 - 带 HTTP 头部解析（用于 WebSocket 升级）
fn create_usockets_context_with_headers(raw_data string, method string, path string, params map[string]string, query map[string]string, body string) Context {
	// Parse headers from raw HTTP request
	mut headers := http.new_header()
	
	lines := raw_data.split('\r\n')
	mut in_headers := false
	
	for line in lines {
		if !in_headers {
			// Skip the request line
			if line.contains(' HTTP/') {
				in_headers = true
			}
			continue
		}
		
		// Empty line marks end of headers
		if line.len == 0 {
			break
		}
		
		// Parse header
		colon_idx := line.index(':') or { continue }
		if colon_idx > 0 {
			name := line[..colon_idx].trim_space()
			value := line[colon_idx + 1..].trim_space()
			headers.add_custom(name, value) or { continue }
		}
	}
	
	return Context{
		req: http.Request{
			method: parse_http_method_usockets(method)
			url: path
			data: body
			header: headers
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

// 快速 HTTP 方法解析（基于首字符和长度）
@[inline]
fn parse_http_method_usockets(method string) http.Method {
	len := method.len
	if len == 0 {
		return http.Method.get
	}
	
	// 基于首字符快速分支
	match method[0] {
		`G` {
			if len == 3 { return http.Method.get }
		}
		`P` {
			if len == 4 && method[1] == `O` { return http.Method.post }
			if len == 3 && method[1] == `U` { return http.Method.put }
			if len == 5 { return http.Method.patch }
		}
		`D` {
			if len == 6 { return http.Method.delete }
		}
		`H` {
			if len == 4 { return http.Method.head }
		}
		`O` {
			if len == 7 { return http.Method.options }
		}
		else {}
	}
	return http.Method.get
}

// 获取路径对应的所有中间件（优化版：使用预排序的前缀列表）
fn get_middlewares_for_path_usockets_optimized(app &Hono, path string) []ContextMiddleware {
	// 优化2：只有全局中间件时，直接返回引用（避免克隆）
	if app.route_middlewares.len == 0 {
		return app.context_middlewares
	}
	
	mut middlewares := app.context_middlewares.clone()

	// 优化3：使用预排序的前缀列表（启动时已排序，不需要每次请求都排序）
	for prefix in app.sorted_middleware_prefixes {
		if path.starts_with(prefix) || prefix == '/' {
			if mws := app.route_middlewares[prefix] {
				middlewares << mws
			}
		}
	}

	return middlewares
}

// 获取路径对应的所有中间件（保留旧版本兼容）
fn get_middlewares_for_path_usockets(app &Hono, path string) []ContextMiddleware {
	return get_middlewares_for_path_usockets_optimized(app, path)
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

// 发送 uSockets 响应 - 优化版
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
		// 使用快速大小写不敏感比较
		key_len := key.len
		if key_len == 14 && eq_ignore_case_usockets(key, 'content-length') {
			continue
		}
		resp.write_string(key)
		resp.write_string(': ')
		resp.write_string(value)
		resp.write_string('\r\n')
		if key_len == 12 && eq_ignore_case_usockets(key, 'content-type') {
			has_content_type = true
		}
	}

	if !has_content_type {
		if content_type := response.header.get(.content_type) {
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

// 大小写不敏感字符串比较（避免分配）
@[inline]
fn eq_ignore_case_usockets(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		ca := a[i]
		cb := b[i]
		// 转换为小写比较
		la := if ca >= `A` && ca <= `Z` { ca + 32 } else { ca }
		lb := if cb >= `A` && cb <= `Z` { cb + 32 } else { cb }
		if la != lb {
			return false
		}
	}
	return true
}

// 获取状态码文本
fn get_status_text_usockets(code int) string {
	return match code {
		101 { 'Switching Protocols' }
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
		426 { 'Upgrade Required' }
		500 { 'Internal Server Error' }
		502 { 'Bad Gateway' }
		503 { 'Service Unavailable' }
		else { 'Unknown' }
	}
}
