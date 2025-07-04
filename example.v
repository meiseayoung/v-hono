module main

import net.http
import hono

fn main() {
	mut app := hono.new_hono()
	
	// 简单路由 - 使用基本类型
	app.get('/hello', fn (req hono.Request) http.Response {
		return http.Response{
			status_code: 200
			body: 'Hello, World!'
		}
	})
	
	// 静态路由
	app.get('/', fn (req hono.Request) http.Response {
		return http.Response{
			status_code: 200
			body: '<h1>Welcome to Hono with Hybrid Router!</h1>'
		}
	})
	
	// 健康检查路由
	app.get('/api/health', fn (req hono.Request) http.Response {
		return http.Response{
			status_code: 200
			body: '{"status": "ok"}'
		}
	})
	
	// 动态路由示例
	app.get('/users/:id', fn (req hono.Request) http.Response {
		return http.Response{
			status_code: 200
			body: 'User route accessed, id=' + req.param['id']
		}
	})
	
	// POST 路由示例 - 获取请求体
	app.post('/api/users', fn (req hono.Request) http.Response {
		println('收到POST请求到 /api/users')
		println('请求体: ${req.body}')
		println('查询参数: ${req.query}')
		
		return http.Response{
			status_code: 201
			body: '{"message": "User created", "body": "${req.body}"}'
		}
	})
	
	// POST 路由示例 - 带参数的动态路由
	app.post('/api/users/:id', fn (req hono.Request) http.Response {
		user_id := req.param['id']
		println('收到POST请求到 /api/users/${user_id}')
		println('请求体: ${req.body}')
		
		return http.Response{
			status_code: 200
			body: '{"message": "User updated", "id": "${user_id}", "body": "${req.body}"}'
		}
	})
	
	// 综合POST示例 - 展示param、query、body
	app.post('/api/test/:action/:id', fn (req hono.Request) http.Response {
		action := req.param['action']
		id := req.param['id']
		
		println('=== 综合POST请求信息 ===')
		println('路径参数: action=${action}, id=${id}')
		println('查询参数: ${req.query}')
		println('请求体: ${req.body}')
		
		// 构建响应JSON
		mut response := '{'
		response += '"message": "综合测试",'
		response += '"params": {'
		response += '"action": "${action}",'
		response += '"id": "${id}"'
		response += '},'
		response += '"query": {'
		
		// 添加查询参数
		mut query_count := 0
		for key, value in req.query {
			if query_count > 0 {
				response += ','
			}
			response += '"${key}": "${value}"'
			query_count++
		}
		
		response += '},'
		response += '"body": "${req.body}"'
		response += '}'
		
		return http.Response{
			status_code: 200
			body: response
		}
	})
	
	println('Server starting on :8080')
	println('测试静态路由: http://localhost:8080/')
	println('测试健康检查: http://localhost:8080/api/health')
	println('测试简单路由: http://localhost:8080/hello')
	println('测试动态路由: http://localhost:8080/users/123')
	println('测试POST创建用户: curl -X POST http://localhost:8080/api/users -d "{\\"name\\":\\"John\\",\\"email\\":\\"john@example.com\\"}"')
	println('测试POST更新用户: curl -X POST http://localhost:8080/api/users/123 -d "{\\"name\\":\\"John Updated\\"}"')
	println('测试综合POST: curl -X POST "http://localhost:8080/api/test/create/456?token=abc123&type=user" -d "{\\"name\\":\\"Test User\\",\\"email\\":\\"test@example.com\\"}"')
	app.listen(':8080')
} 