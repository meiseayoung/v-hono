// v-hono picoev 服务器示例 - 高性能版本
// 运行: v run server_hono_picoev.v
// 测试: curl http://127.0.0.1:8081/

module main

import meiseayoung.hono
import net.http

fn main() {
	mut app := hono.Hono.new()
	
	// 静态路由
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello World')
	})
	
	app.get('/api/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	
	app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"users": []}')
	})
	
	app.post('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"created": true}')
	})
	
	// 动态路由
	app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}"}')
	})
	
	app.get('/api/users/:id/posts', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"posts": [], "user_id": "${id}"}')
	})
	
	app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		user_id := c.params['user_id'] or { '' }
		post_id := c.params['post_id'] or { '' }
		return c.json('{"user_id": "${user_id}", "post_id": "${post_id}"}')
	})
	
	app.get('/api/categories/:cat/items/:item', fn (mut c hono.Context) http.Response {
		cat := c.params['cat'] or { '' }
		item := c.params['item'] or { '' }
		return c.json('{"category": "${cat}", "item": "${item}"}')
	})
	
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║        v-hono picoev 服务器 - 高性能版本                      ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 端口: 8081                                                    ║')
	println('║ 特性: picoev 事件驱动 + Keep-Alive                            ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	
	app.listen_picoev(8081)
}
