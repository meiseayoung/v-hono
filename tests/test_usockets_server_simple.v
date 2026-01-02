// uSockets 简化测试服务器 - 与外层 main.v 配置一致
module main

import meiseayoung.hono
import net.http
import x.json2

// JSON 响应结构体
struct JsonResponse {
	message string
}

struct UserResponse {
	user_id string
}

fn main() {
	mut app := hono.Hono.new()

	// 与外层 main.v 完全一致的路由配置（无中间件）
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello, World!')
	})

	app.get('/json', fn (mut c hono.Context) http.Response {
		data := JsonResponse{message: 'Hello, JSON!'}
		json_str := json2.encode(data)
		return c.json(json_str)
	})

	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id'] or { 'unknown' }
		data := UserResponse{user_id: user_id}
		json_str := json2.encode(data)
		return c.json(json_str)
	})

	app.get('/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})

	println('[usockets-simple] Starting on port 9999 (uSockets)...')
	app.listen_usockets(9999)
}
