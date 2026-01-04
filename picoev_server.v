module hono

import net
import net.http
import picoev
import picohttpparser

// picoev 服务器配置
pub struct PicoevConfig {
pub:
	port              int            = 8080
	host              string
	family            net.AddrFamily = .ip6
	timeout_secs      int            = 120    // 高并发场景需要更长超时（原 8 秒太短）
	max_headers       int            = 100
	max_read          int            = 8192
	max_write         int            = 65536
	keepalive_timeout int            = 30     // Keep-Alive 超时延长到 30 秒
	max_keepalive_req int            = 10000  // 单连接最大请求数提升到 10000
}

// picoev 请求上下文
struct PicoevRequestContext {
mut:
	app    &Hono = unsafe { nil }
	config PicoevConfig
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
		config: config
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

// ============================================================================
// WebSocket Upgrade Detection and Handling
// ============================================================================

// Check if a picoev request is a WebSocket upgrade request
fn is_picoev_ws_upgrade(req picohttpparser.Request) bool {
	mut has_upgrade := false
	mut has_connection := false
	mut has_ws_key := false
	
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		name_lower := h.name.to_lower()
		
		if name_lower == 'upgrade' {
			if h.value.to_lower() == 'websocket' {
				has_upgrade = true
			}
		} else if name_lower == 'connection' {
			if contains_ignore_case(h.value, 'upgrade') {
				has_connection = true
			}
		} else if name_lower == 'sec-websocket-key' {
			if h.value.len > 0 {
				has_ws_key = true
			}
		}
	}
	
	return has_upgrade && has_connection && has_ws_key
}

// Get WebSocket key from picoev request headers
fn get_picoev_ws_key(req picohttpparser.Request) string {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		if eq_ignore_case(h.name, 'sec-websocket-key') {
			return h.value
		}
	}
	return ''
}

// Get WebSocket protocol from picoev request headers
fn get_picoev_ws_protocol(req picohttpparser.Request) string {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		if eq_ignore_case(h.name, 'sec-websocket-protocol') {
			return h.value
		}
	}
	return ''
}

// Get WebSocket version from picoev request headers
fn get_picoev_ws_version(req picohttpparser.Request) string {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		if eq_ignore_case(h.name, 'sec-websocket-version') {
			return h.value
		}
	}
	return '13'
}

// Handle WebSocket upgrade for picoev
fn handle_picoev_ws_upgrade(mut ctx PicoevRequestContext, req picohttpparser.Request, mut res picohttpparser.Response, route_match ContextRouteMatch, hono_ctx Context) bool {
	// Validate WebSocket version
	ws_version := get_picoev_ws_version(req)
	if ws_version != '13' {
		res.raw('HTTP/1.1 426 Upgrade Required\r\n')
		res.header('Sec-WebSocket-Version', '13')
		res.header('Content-Type', 'text/plain')
		res.body('Unsupported WebSocket version')
		res.end()
		return false
	}
	
	// Get WebSocket key
	ws_key := get_picoev_ws_key(req)
	if ws_key.len == 0 {
		res.raw('HTTP/1.1 400 Bad Request\r\n')
		res.header('Content-Type', 'text/plain')
		res.body('Missing Sec-WebSocket-Key header')
		res.end()
		return false
	}
	
	// Compute accept key
	accept_key := compute_accept_key(ws_key)
	
	// Execute the route handler to get WSEvents
	// The handler should return a 101 response with WebSocket context stored
	mut mutable_ctx := hono_ctx
	response := route_match.handler.handle(mut mutable_ctx)
	
	// Check if this is a WebSocket upgrade response
	if response.status_code != 101 {
		// Not a WebSocket upgrade, send the response as-is
		send_picoev_response(mut res, mutable_ctx, response, false, ctx.config)
		return false
	}
	
	// Negotiate subprotocol
	mut selected_protocol := ''
	if '_ws_protocol' in mutable_ctx.store {
		selected_protocol = mutable_ctx.store['_ws_protocol']
	}
	
	// Send WebSocket handshake response
	res.raw('HTTP/1.1 101 Switching Protocols\r\n')
	res.header('Upgrade', 'websocket')
	res.header('Connection', 'Upgrade')
	res.header('Sec-WebSocket-Accept', accept_key)
	if selected_protocol.len > 0 {
		res.header('Sec-WebSocket-Protocol', selected_protocol)
	}
	res.body('')
	res.end()
	
	return true
}

// Send WebSocket frame via picoev response
fn send_ws_frame_picoev(data []u8) ! {
	// This is a placeholder - actual implementation depends on picoev's raw socket access
	// In practice, we need to write directly to the socket fd
}

// picoev 回调函数
fn picoev_callback(user_data voidptr, req picohttpparser.Request, mut res picohttpparser.Response) {
	mut ctx := unsafe { &PicoevRequestContext(user_data) }
	
	if ctx.app == unsafe { nil } {
		res.http_500()
		res.end()
		return
	}
	
	path, query_map := parse_path_and_query(req.path)
	keepalive := check_keepalive_request(req)
	method_str := req.method
	
	// Check if this is a WebSocket upgrade request
	is_ws_upgrade := is_picoev_ws_upgrade(req)
	
	// 优先使用快速路由器
	if ctx.app.use_fast_router {
		if route_match := ctx.app.fast_router.match_route(method_str, path) {
			mut hono_ctx := create_picoev_context(req, route_match.params, query_map)
			
			// Handle WebSocket upgrade if detected
			if is_ws_upgrade {
				if handle_picoev_ws_upgrade(mut ctx, req, mut res, route_match, hono_ctx) {
					// WebSocket upgrade successful, connection is now in WebSocket mode
					return
				}
				// If upgrade failed, response was already sent
				return
			}
			
			// 优化：零中间件快速路径
			if !ctx.app.has_middlewares {
				response := route_match.handler.handle(mut hono_ctx)
				send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
				return
			}
			
			middlewares := get_middlewares_for_path_picoev_optimized(ctx.app, path)
			response := exec_middlewares_picoev(0, middlewares, mut hono_ctx, route_match.handler)
			send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
			return
		}
	}
	
	// 回退到混合路由器
	if route_match := ctx.app.context_hybrid_router.match_route(method_str, path) {
		mut hono_ctx := create_picoev_context(req, route_match.params, query_map)
		
		// Handle WebSocket upgrade if detected
		if is_ws_upgrade {
			if handle_picoev_ws_upgrade(mut ctx, req, mut res, route_match, hono_ctx) {
				// WebSocket upgrade successful
				return
			}
			return
		}
		
		// 优化：零中间件快速路径
		if !ctx.app.has_middlewares {
			response := route_match.handler.handle(mut hono_ctx)
			send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
			return
		}
		
		middlewares := get_middlewares_for_path_picoev_optimized(ctx.app, path)
		response := exec_middlewares_picoev(0, middlewares, mut hono_ctx, route_match.handler)
		send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
		return
	}
	
	// 404 Not Found
	mut hono_ctx := create_picoev_context(req, map[string]string{}, query_map)
	
	if handler := ctx.app.not_found_handler {
		response := handler(mut hono_ctx)
		send_picoev_response(mut res, hono_ctx, response, keepalive, ctx.config)
		return
	}
	
	// 默认 404 响应
	res.raw('HTTP/1.1 404 Not Found\r\n')
	res.header('Content-Type', 'text/plain')
	res.header('Content-Length', '9')
	if keepalive {
		res.header('Connection', 'keep-alive')
		res.header('Keep-Alive', 'timeout=${ctx.config.keepalive_timeout}, max=${ctx.config.max_keepalive_req}')
	} else {
		res.header('Connection', 'close')
	}
	res.body('Not Found')
	res.end()
}

// 检查客户端是否请求 Keep-Alive - 优化版
// 避免 to_lower() 创建新字符串，使用大小写不敏感比较
fn check_keepalive_request(req picohttpparser.Request) bool {
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		// 大小写不敏感比较 "connection"
		if h.name.len == 10 && eq_ignore_case(h.name, 'connection') {
			// 检查是否包含 "keep-alive"（大小写不敏感）
			return contains_ignore_case(h.value, 'keep-alive')
		}
	}
	return true // HTTP/1.1 默认 Keep-Alive
}

// 大小写不敏感字符串比较（避免分配）
@[inline]
fn eq_ignore_case(a string, b string) bool {
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

// 大小写不敏感的 contains 检查（避免分配）
@[inline]
fn contains_ignore_case(haystack string, needle string) bool {
	if needle.len > haystack.len {
		return false
	}
	max_start := haystack.len - needle.len
	for i := 0; i <= max_start; i++ {
		mut found := true
		for j in 0 .. needle.len {
			ch := haystack[i + j]
			cn := needle[j]
			lh := if ch >= `A` && ch <= `Z` { ch + 32 } else { ch }
			ln := if cn >= `A` && cn <= `Z` { cn + 32 } else { cn }
			if lh != ln {
				found = false
				break
			}
		}
		if found {
			return true
		}
	}
	return false
}

// 获取路径对应的所有中间件（优化版：使用预排序的前缀列表）
fn get_middlewares_for_path_picoev_optimized(app &Hono, path string) []ContextMiddleware {
	// 优化：只有全局中间件时，直接返回引用（避免克隆）
	if app.route_middlewares.len == 0 {
		return app.context_middlewares
	}
	
	mut middlewares := app.context_middlewares.clone()
	
	// 优化：使用预排序的前缀列表（启动时已排序，不需要每次请求都排序）
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
fn get_middlewares_for_path_picoev(app &Hono, path string) []ContextMiddleware {
	return get_middlewares_for_path_picoev_optimized(app, path)
}

// 执行中间件链
fn exec_middlewares_picoev(idx int, middlewares []ContextMiddleware, mut ctx Context, handler IHandler) http.Response {
	if idx < middlewares.len {
		mw := middlewares[idx]
		return mw(mut ctx, fn [idx, middlewares, handler] (mut c Context) http.Response {
			return exec_middlewares_picoev(idx + 1, middlewares, mut c, handler)
		})
	}
	return handler.handle(mut ctx)
}

// 解析路径和查询参数 - 零分配优化版
// 使用指针遍历避免创建临时数组
fn parse_path_and_query(full_path string) (string, map[string]string) {
	mut query_map := map[string]string{}
	len := full_path.len
	
	if len == 0 {
		return full_path, query_map
	}
	
	// 快速路径：大多数请求没有查询参数
	// 从后向前搜索 '?' 通常更快（查询参数在末尾）
	mut query_start := -1
	for i := len - 1; i >= 0; i-- {
		if full_path[i] == `?` {
			query_start = i
			break
		}
	}
	
	// 没有查询参数，直接返回（最常见情况）
	if query_start == -1 {
		return full_path, query_map
	}
	
	path := full_path[..query_start]
	
	// 解析查询参数（单次遍历，避免 split）
	mut key_start := query_start + 1
	mut key_end := -1
	mut value_start := -1
	
	for i := query_start + 1; i <= len; i++ {
		ch := if i < len { full_path[i] } else { `&` } // 末尾视为分隔符
		
		if ch == `=` && key_end == -1 {
			key_end = i
			value_start = i + 1
		} else if ch == `&` {
			// 完成一个键值对
			if key_end > key_start && value_start > 0 {
				key := full_path[key_start..key_end]
				value := if value_start < i { full_path[value_start..i] } else { '' }
				query_map[key] = value
			} else if key_end == -1 && i > key_start {
				// 只有 key 没有 value（如 ?foo&bar=1）
				key := full_path[key_start..i]
				query_map[key] = ''
			}
			// 重置状态
			key_start = i + 1
			key_end = -1
			value_start = -1
		}
	}
	
	return path, query_map
}

// 创建 picoev 上下文 - 优化版
// 延迟转换 http.Request，只在真正需要时才转换
fn create_picoev_context(req picohttpparser.Request, params map[string]string, query map[string]string) Context {
	// 提取纯路径（不含查询参数）
	path := extract_path_only(req.path)
	
	return Context{
		req: convert_picoev_request(req)
		params: params
		query: query
		body: req.body
		url: req.path
		path: path
		status_code: 200
		headers: map[string]string{}
	}
}

// 快速提取路径（不含查询参数）
@[inline]
fn extract_path_only(full_path string) string {
	for i in 0 .. full_path.len {
		if full_path[i] == `?` {
			return full_path[..i]
		}
	}
	return full_path
}

// 转换 picoev 请求 - 优化版
// 使用预计算的方法映射避免字符串比较
fn convert_picoev_request(req picohttpparser.Request) http.Request {
	mut headers := http.new_header()
	
	for i in 0 .. req.num_headers {
		h := req.headers[i]
		headers.add_custom(h.name, h.value) or { continue }
	}
	
	return http.Request{
		method: parse_http_method_fast(req.method)
		url: req.path
		data: req.body
		header: headers
	}
}

// 快速 HTTP 方法解析（基于首字符和长度）
@[inline]
fn parse_http_method_fast(method string) http.Method {
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

// 发送 picoev 响应 - 优化版
fn send_picoev_response(mut res picohttpparser.Response, ctx Context, response http.Response, keepalive bool, config PicoevConfig) {
	status_code := if ctx.status_code != 0 { ctx.status_code } else { response.status_code }
	
	if status_code == 200 {
		res.http_ok()
	} else {
		res.raw('HTTP/1.1 ${status_code} ${get_status_text(status_code)}\r\n')
	}
	
	mut has_content_type := false
	mut has_connection := false
	
	for key, value in ctx.headers {
		// 使用快速大小写不敏感比较
		key_len := key.len
		if key_len == 14 && eq_ignore_case(key, 'content-length') {
			continue // 跳过 Content-Length
		}
		res.header(key, value)
		if key_len == 12 && eq_ignore_case(key, 'content-type') {
			has_content_type = true
		} else if key_len == 10 && eq_ignore_case(key, 'connection') {
			has_connection = true
		}
	}
	
	if !has_content_type {
		if content_type := response.header.get(.content_type) {
			res.header('Content-Type', content_type)
			has_content_type = true
		}
	}
	
	if !has_content_type {
		res.header('Content-Type', 'text/plain; charset=utf-8')
	}
	
	if !has_connection {
		if keepalive {
			res.header('Connection', 'keep-alive')
			res.header('Keep-Alive', 'timeout=${config.keepalive_timeout}, max=${config.max_keepalive_req}')
		} else {
			res.header('Connection', 'close')
		}
	}
	
	res.body(response.body)
	res.end()
}

// 获取状态码文本
fn get_status_text(code int) string {
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
