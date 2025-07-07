module main

import net.http
import hono

fn main() {
	mut app := hono.Hono.new()
	
	// 日志中间件
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[LOG] ${c.req.method} ${c.url}')
		return next(mut c)
	})
	
	// 静态文件服务 - 默认配置（./public 目录）
	app.use(hono.serve_static_default())
	
	// 静态文件服务 - 指定路径前缀
	app.use(hono.serve_static_path('/assets', './static'))
	
	// 静态文件服务 - 自定义配置
	options := hono.StaticOptions{
		root: './uploads'
		path: '/files'
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 3600  // 1小时缓存
		headers: {
			'X-Served-By': 'V-Hono'
			'X-Static-Files': 'true'
		}
	}
	app.use(hono.serve_static(options))
	
	// 基本路由
	app.get('/hello', fn (mut c hono.Context) http.Response {
		return c.text('Hello, World!')
	})
	
	// 根路径
	app.get('/', fn (mut c hono.Context) http.Response {
		html_content := '<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>V-Hono 完整示例</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1000px; margin: 0 auto; padding: 20px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .endpoint { background: #f5f5f5; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .feature { color: #2c5aa0; font-weight: bold; }
        .static-section { background: #e8f4fd; border-left: 4px solid #2196F3; }
        .api-section { background: #f3e5f5; border-left: 4px solid #9C27B0; }
    </style>
</head>
<body>
    <h1>🚀 V-Hono 完整示例</h1>
    <p>A lightweight web framework for V with static file serving</p>
    
    <div class="section static-section">
        <h2>📁 静态文件服务</h2>
        <div class="endpoint">
            <strong>默认目录:</strong> <code>/</code> → <code>./public</code>
        </div>
        <div class="endpoint">
            <strong>资源目录:</strong> <code>/assets</code> → <code>./static</code>
        </div>
        <div class="endpoint">
            <strong>文件目录:</strong> <code>/files</code> → <code>./uploads</code>
        </div>
        <p><strong>测试文件:</strong></p>
        <ul>
            <li><a href="/test.txt">/test.txt</a> (来自 ./public/test.txt)</li>
            <li><a href="/assets/style.css">/assets/style.css</a> (来自 ./static/style.css)</li>
            <li><a href="/files/sample.json">/files/sample.json</a> (来自 ./uploads/sample.json)</li>
        </ul>
    </div>
    
    <div class="section api-section">
        <h2>🔧 API 端点</h2>
        <div class="endpoint">
            <strong>健康检查:</strong> <a href="/api/health">/api/health</a>
        </div>
        <div class="endpoint">
            <strong>静态文件状态:</strong> <a href="/api/status">/api/status</a>
        </div>
        <div class="endpoint">
            <strong>静态文件信息:</strong> <a href="/api/static-info">/api/static-info</a>
        </div>
        <div class="endpoint">
            <strong>基础路由:</strong> <a href="/hello">/hello</a>
        </div>
    </div>
    
    <div class="section">
        <h2>🎯 动态路由示例</h2>
        <div class="endpoint">
            <strong>单参数:</strong> <a href="/users/123">/users/123</a>
        </div>
        <div class="endpoint">
            <strong>多参数:</strong> <a href="/posts/456/comments/789">/posts/456/comments/789</a>
        </div>
        <div class="endpoint">
            <strong>嵌套参数:</strong> <a href="/api/users/101/posts/202">/api/users/101/posts/202</a>
        </div>
    </div>
    
    <div class="section">
        <h2>✨ 特性</h2>
        <ul>
            <li class="feature">🚀 高性能路由系统</li>
            <li class="feature">🛡️ 路径遍历攻击防护</li>
            <li class="feature">📁 自动索引文件支持</li>
            <li class="feature">🔒 点文件访问控制</li>
            <li class="feature">🏷️ ETag 和 Last-Modified 支持</li>
            <li class="feature">💾 可配置缓存策略</li>
            <li class="feature">🎯 智能 Content-Type 检测</li>
            <li class="feature">🔧 洋葱模型中间件</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>🧪 测试命令</h2>
        <pre>
# 静态文件测试
curl http://localhost:8080/test.txt
curl http://localhost:8080/assets/style.css
curl http://localhost:8080/files/sample.json

# API 测试
curl http://localhost:8080/api/health
curl http://localhost:8080/api/status
curl http://localhost:8080/hello

# 动态路由测试
curl http://localhost:8080/users/123
curl http://localhost:8080/posts/456/comments/789
        </pre>
    </div>
</body>
</html>'
		return c.html(html_content)
	})
	
	// 健康检查
	app.get('/api/health', fn (mut c hono.Context) http.Response {
		c.status(200)
		return c.json('{"status": "ok", "message": "Health check passed"}')
	})
	
	// 静态文件服务状态
	app.get('/api/status', fn (mut c hono.Context) http.Response {
		return c.json('{"status": "ok", "static_files": "enabled"}')
	})
	
	app.get('/api/static-info', fn (mut c hono.Context) http.Response {
		return c.json('{
			"static_directories": [
				{"path": "/", "root": "./public"},
				{"path": "/assets", "root": "./static"},
				{"path": "/files", "root": "./uploads"}
			],
			"features": [
				"Path traversal protection",
				"Auto index files",
				"ETag support",
				"Last-Modified headers",
				"Configurable caching",
				"Custom headers"
			]
		}')
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
	
	println('🚀 V-Hono 完整示例启动中...')
	println('📍 服务器地址: http://localhost:8080')
	println('')
	println('📁 静态文件服务:')
	println('  - 默认: ./public (访问路径: /)')
	println('  - 资源: ./static (访问路径: /assets)')
	println('  - 文件: ./uploads (访问路径: /files)')
	println('')
	println('🔧 API 端点:')
	println('  - GET /api/health')
	println('  - GET /api/status')
	println('  - GET /api/static-info')
	println('  - GET /hello')
	println('')
	println('🎯 动态路由:')
	println('  - GET /users/123')
	println('  - GET /posts/456/comments/789')
	println('  - GET /api/users/101/posts/202')
	println('')
	println('📝 POST 请求:')
	println('  - POST /api/users')
	println('  - POST /api/users/123')
	println('  - POST /api/test/create/456')
	println('')
	println('🔄 其他方法:')
	println('  - PUT /api/users/123')
	println('  - DELETE /api/users/123')
	println('  - PATCH /api/users/123')
	println('')
	println('🧪 测试命令示例:')
	println('  # 静态文件测试')
	println('  curl http://localhost:8080/test.txt')
	println('  curl http://localhost:8080/assets/style.css')
	println('  curl http://localhost:8080/files/sample.json')
	println('')
	println('  # API 测试')
	println('  curl http://localhost:8080/api/health')
	println('  curl http://localhost:8080/api/status')
	println('  curl http://localhost:8080/hello')
	println('')
	println('  # 动态路由测试')
	println('  curl http://localhost:8080/users/123')
	println('  curl http://localhost:8080/posts/456/comments/789')
	println('')
	println('  # POST 测试')
	println('  curl -X POST http://localhost:8080/api/users -d "{\\"name\\":\\"John\\"}"')
	println('  curl -X POST "http://localhost:8080/api/test/create/456?token=abc123" -d "{\\"name\\":\\"Test\\"}"')
	
	app.listen(':8080')
} 