module main

import net.http
import hono

fn main() {
	mut app := hono.new_hono()
	
	// 基本路由
	app.get('/hello', fn (mut c hono.Context) http.Response {
		return c.text('Hello, World!')
	})
	
	// 根路径
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.html('<h1>Welcome to V-Hono!</h1><p>A lightweight web framework for V</p>')
	})
	
	// 健康检查
	app.get('/api/health', fn (mut c hono.Context) http.Response {
		c.status(200)
		return c.json('{"status": "ok", "message": "Health check passed"}')
	})
	
	// 动态路由 - 单参数
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		return c.json('{"user_id": "${user_id}", "name": "John Doe"}')
	})
	
	// 动态路由 - 多参数
	app.get('/posts/:id/comments/:comment_id', fn (mut c hono.Context) http.Response {
		post_id := c.params['id']
		comment_id := c.params['comment_id']
		return c.json('{"post_id": "${post_id}", "comment_id": "${comment_id}", "content": "Great post!"}')
	})
	
	// 动态路由 - 嵌套参数
	app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		user_id := c.params['user_id']
		post_id := c.params['post_id']
		return c.json('{"user_id": "${user_id}", "post_id": "${post_id}", "title": "Sample Post"}')
	})
	
	// POST 请求
	app.post('/api/users', fn (mut c hono.Context) http.Response {
		println('=== POST 请求信息 ===')
		println('请求体: ${c.body}')
		println('查询参数: ${c.query}')
		
		c.status(201)
		return c.json('{"message": "User created", "data": "${c.body}"}')
	})
	
	// 带参数的 POST 请求
	app.post('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		
		println('=== 带参数的 POST 请求信息 ===')
		println('用户ID: ${user_id}')
		println('请求体: ${c.body}')
		println('查询参数: ${c.query}')
		
		c.status(200)
		return c.json('{"message": "User updated", "user_id": "${user_id}", "data": "${c.body}"}')
	})
	
	// 复杂的 POST 请求
	app.post('/api/test/:action/:id', fn (mut c hono.Context) http.Response {
		action := c.params['action']
		id := c.params['id']
		
		println('=== 复杂 POST 请求信息 ===')
		println('动作: ${action}')
		println('ID: ${id}')
		println('查询参数: ${c.query}')
		println('请求体: ${c.body}')
		
		// 构建响应JSON
		mut response := '{'
		response += '"message": "复杂测试",'
		response += '"params": {'
		response += '"action": "${action}",'
		response += '"id": "${id}"'
		response += '},'
		response += '"query": {'
		
		// 添加查询参数
		mut query_count := 0
		for key, value in c.query {
			if query_count > 0 {
				response += ','
			}
			response += '"${key}": "${value}"'
			query_count++
		}
		
		response += '},'
		response += '"body": "${c.body}"'
		response += '}'
		
		c.status(200)
		return c.json(response)
	})
	
	// PUT 请求示例
	app.put('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		c.status(200)
		return c.json('{"message": "User replaced", "user_id": "${user_id}", "data": "${c.body}"}')
	})
	
	// DELETE 请求示例
	app.delete('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		c.status(204)
		return c.text('')
	})
	
	// PATCH 请求示例
	app.patch('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		c.status(200)
		return c.json('{"message": "User partially updated", "user_id": "${user_id}", "data": "${c.body}"}')
	})
	
	// 中间件示例
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[LOG] ${c.url}')
		return next(mut c)
	})
	
	// 认证中间件示例
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		token := c.query['token']
		if token == '' {
			c.status(401)
			return c.json('{"error": "Unauthorized", "message": "Token required"}')
		}
		return next(mut c)
	})
	
	println('Hono Server starting on :8080')
	println('=== 测试端点 ===')
	println('静态路由:')
	println('  - GET /')
	println('  - GET /hello')
	println('  - GET /api/health')
	println('动态路由:')
	println('  - GET /users/123')
	println('  - GET /posts/456/comments/789')
	println('  - GET /api/users/101/posts/202')
	println('POST 请求:')
	println('  - POST /api/users')
	println('  - POST /api/users/123')
	println('  - POST /api/test/create/456')
	println('其他方法:')
	println('  - PUT /api/users/123')
	println('  - DELETE /api/users/123')
	println('  - PATCH /api/users/123')
	println('')
	println('测试命令示例:')
	println('  curl http://localhost:8080/users/123')
	println('  curl http://localhost:8080/posts/456/comments/789')
	println('  curl -X POST http://localhost:8080/api/users -d "{\\"name\\":\\"John\\"}"')
	println('  curl -X POST "http://localhost:8080/api/test/create/456?token=abc123" -d "{\\"name\\":\\"Test\\"}"')
	
	app.listen(':8080')
} 