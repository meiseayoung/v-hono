// picoev 测试服务器
// 用于 test_picoev_integration.v 的测试

module main

import meiseayoung.hono
import net.http

fn main() {
	mut app := hono.Hono.new()
	
	// 全局中间件 - 添加自定义响应头
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		mut resp := next(mut c)
		c.headers['X-Middleware'] = 'applied'
		return resp
	})
	
	// ==================== 基本路由 ====================
	
	// 根路径
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello World')
	})
	
	// 健康检查
	app.get('/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	
	app.get('/api/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	
	// ==================== CRUD 路由 ====================
	
	app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"users": []}')
	})
	
	app.post('/api/users', fn (mut c hono.Context) http.Response {
		c.status(201)
		return c.json('{"created": true}')
	})
	
	app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}"}')
	})
	
	app.put('/api/users/:id', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}", "updated": true}')
	})
	
	app.delete('/api/users/:id', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}", "deleted": true}')
	})
	
	app.patch('/api/users/:id', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}", "patched": true}')
	})
	
	// ==================== 多参数路由 ====================
	
	app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		user_id := c.params['user_id'] or { '' }
		post_id := c.params['post_id'] or { '' }
		return c.json('{"user_id": "${user_id}", "post_id": "${post_id}"}')
	})
	
	app.get('/api/categories/:category/items/:item', fn (mut c hono.Context) http.Response {
		category := c.params['category'] or { '' }
		item := c.params['item'] or { '' }
		return c.json('{"category": "${category}", "item": "${item}"}')
	})
	
	// ==================== 查询参数路由 ====================
	
	app.get('/api/search', fn (mut c hono.Context) http.Response {
		q := c.query['q'] or { '' }
		limit := c.query['limit'] or { '10' }
		page := c.query['page'] or { '1' }
		return c.json('{"query": "${q}", "limit": ${limit}, "page": ${page}}')
	})
	
	// ==================== 响应格式路由 ====================
	
	app.get('/api/json', fn (mut c hono.Context) http.Response {
		return c.json('{"message": "JSON response"}')
	})
	
	app.get('/api/html', fn (mut c hono.Context) http.Response {
		return c.html('<html><body><h1>HTML Response</h1></body></html>')
	})
	
	app.get('/api/created', fn (mut c hono.Context) http.Response {
		c.status(201)
		return c.json('{"created": true}')
	})
	
	app.get('/api/custom-header', fn (mut c hono.Context) http.Response {
		c.headers['X-Custom-Header'] = 'custom-value'
		return c.text('OK')
	})
	
	// ==================== 中间件测试路由 ====================
	
	app.get('/api/middleware-test', fn (mut c hono.Context) http.Response {
		return c.text('middleware test')
	})
	
	app.get('/api/middleware-order', fn (mut c hono.Context) http.Response {
		return c.json('{"order": "correct"}')
	})
	
	// ==================== 自定义 404 ====================
	
	app.not_found(fn (mut c hono.Context) http.Response {
		c.status(404)
		return c.json('{"error": "Not Found", "path": "${c.path}"}')
	})
	
	// 启动服务器
	println('[test-server] Starting on port 9999...')
	app.listen(':9999')
}
