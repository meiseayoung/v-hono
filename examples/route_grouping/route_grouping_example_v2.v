// V-Hono 路由分组增强示例
// 演示新功能：子应用中间件继承、all() 方法、notFound/onError 处理器

import net.http
import meiseayoung.hono

fn main() {
	println('🚀 V-Hono 路由分组增强示例启动中...')
	
	// 创建主应用
	mut app := hono.Hono.new()
	
	// ========================================
	// 1. 自定义 notFound 处理器
	// ========================================
	app.not_found(fn (mut c hono.Context) http.Response {
		c.status(404)
		return c.json('{"error": "Not Found", "message": "The requested resource does not exist", "path": "${c.path}"}')
	})
	
	// ========================================
	// 2. 自定义 onError 处理器
	// ========================================
	app.on_error(fn (error_msg string, status_code int, mut c hono.Context) http.Response {
		c.status(status_code)
		return c.json('{"error": "Internal Error", "message": "${error_msg}", "code": ${status_code}}')
	})
	
	// ========================================
	// 3. 全局中间件
	// ========================================
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[GLOBAL] ${c.req.method} ${c.path}')
		return next(mut c)
	})
	
	// 根路由
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.html(generate_index_page())
	})
	
	// ========================================
	// 4. all() 方法示例 - 匹配所有 HTTP 方法
	// ========================================
	app.all('/echo', fn (mut c hono.Context) http.Response {
		return c.json('{"method": "${c.req.method}", "path": "${c.path}", "message": "Echo endpoint handles all HTTP methods"}')
	})
	
	// ========================================
	// 5. 子应用中间件继承示例 - API 路由组
	// ========================================
	mut api := hono.Hono.new()
	
	// API 子应用的中间件（只对 /api/* 路由生效）
	api.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[API] Request to API endpoint: ${c.path}')
		// 添加 API 版本头
		c.headers['X-API-Version'] = '1.0'
		return next(mut c)
	})
	
	api.get('/version', fn (mut c hono.Context) http.Response {
		return c.json('{"version": "1.0.0", "name": "V-Hono API"}')
	})
	
	app.route('/api', mut api)
	
	// ========================================
	// 6. Books 子应用（带认证中间件）
	// ========================================
	mut books := hono.Hono.new()
	
	// Books 子应用的认证中间件
	books.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[BOOKS] Auth check for: ${c.path}')
		// 模拟认证检查
		auth_header := c.req.header.get_custom('Authorization') or { '' }
		if auth_header == '' {
			println('[BOOKS] No auth header, allowing public access')
		} else {
			println('[BOOKS] Auth header present: ${auth_header}')
		}
		return next(mut c)
	})
	
	books.get('/', fn (mut c hono.Context) http.Response {
		return c.json('[{"id": 1, "title": "V Programming"}, {"id": 2, "title": "Web Development"}]')
	})
	
	books.get('/:id', fn (mut c hono.Context) http.Response {
		book_id := c.params['id']
		return c.json('{"id": "${book_id}", "title": "V Programming", "author": "V Team"}')
	})
	
	books.post('/', fn (mut c hono.Context) http.Response {
		c.status(201)
		return c.json('{"message": "Book created", "body": "${c.body}"}')
	})
	
	// 使用 all() 处理所有方法
	books.all('/stats', fn (mut c hono.Context) http.Response {
		return c.json('{"method": "${c.req.method}", "total_books": 100, "message": "Stats endpoint"}')
	})
	
	app.route('/api/books', mut books)
	
	// ========================================
	// 7. Admin 子应用（带严格认证中间件）
	// ========================================
	mut admin := hono.Hono.new()
	
	// Admin 子应用的严格认证中间件
	admin.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[ADMIN] Strict auth check for: ${c.path}')
		auth_header := c.req.header.get_custom('Authorization') or { '' }
		if !auth_header.starts_with('Bearer admin-') {
			c.status(401)
			return c.json('{"error": "Unauthorized", "message": "Admin access required"}')
		}
		println('[ADMIN] Admin access granted')
		return next(mut c)
	})
	
	admin.get('/', fn (mut c hono.Context) http.Response {
		return c.json('{"page": "Admin Dashboard", "stats": {"users": 100, "books": 50}}')
	})
	
	admin.get('/users', fn (mut c hono.Context) http.Response {
		return c.json('[{"id": 1, "name": "Admin User", "role": "admin"}]')
	})
	
	app.route('/admin', mut admin)
	
	// ========================================
	// 8. 健康检查（无中间件）
	// ========================================
	app.get('/health', fn (mut c hono.Context) http.Response {
		return c.json('{"status": "ok"}')
	})
	
	// 打印路由信息
	print_routes_info()
	
	// 启动服务器
	app.listen(':8080')
}

// 生成首页 HTML
fn generate_index_page() string {
	return '<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>V-Hono 路由分组增强示例</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; }
        .group { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 8px; }
        .endpoint { background: #f5f5f5; padding: 10px; margin: 5px 0; border-radius: 4px; font-family: monospace; }
        .method { display: inline-block; width: 70px; font-weight: bold; }
        .get { color: #61affe; }
        .post { color: #49cc90; }
        .all { color: #9b59b6; }
        h2 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        .feature { background: #e8f4fd; padding: 10px; margin: 10px 0; border-radius: 4px; border-left: 4px solid #007bff; }
        pre { background: #2d2d2d; color: #f8f8f2; padding: 15px; border-radius: 5px; overflow-x: auto; }
        .middleware { color: #e74c3c; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>🚀 V-Hono 路由分组增强示例</h1>
    
    <div class="feature">
        <strong>新功能演示：</strong>
        <ul>
            <li>✅ 子应用中间件继承 - 子应用的中间件只对其路由前缀生效</li>
            <li>✅ all() 方法 - 一次性注册所有 HTTP 方法</li>
            <li>✅ notFound() - 自定义 404 处理器</li>
            <li>✅ onError() - 自定义错误处理器</li>
        </ul>
    </div>
    
    <div class="group">
        <h2>🔧 通用端点</h2>
        <div class="endpoint"><span class="method get">GET</span> <a href="/">/</a> - 首页</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/health">/health</a> - 健康检查</div>
        <div class="endpoint"><span class="method all">ALL</span> <a href="/echo">/echo</a> - Echo（支持所有 HTTP 方法）</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/not-exist">/not-exist</a> - 测试自定义 404</div>
    </div>
    
    <div class="group">
        <h2>📡 API 路由组 (/api)</h2>
        <p class="middleware">中间件：添加 X-API-Version 头</p>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/version">/api/version</a> - API 版本</div>
    </div>
    
    <div class="group">
        <h2>📚 Books API (/api/books)</h2>
        <p class="middleware">中间件：认证检查（可选）</p>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/books">/api/books</a> - 获取所有书籍</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/books/1">/api/books/:id</a> - 获取单本书籍</div>
        <div class="endpoint"><span class="method post">POST</span> /api/books - 创建书籍</div>
        <div class="endpoint"><span class="method all">ALL</span> <a href="/api/books/stats">/api/books/stats</a> - 统计（支持所有方法）</div>
    </div>
    
    <div class="group">
        <h2>🔐 Admin API (/admin)</h2>
        <p class="middleware">中间件：严格认证（需要 Bearer admin-* token）</p>
        <div class="endpoint"><span class="method get">GET</span> <a href="/admin">/admin</a> - 管理仪表盘（需认证）</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/admin/users">/admin/users</a> - 用户管理（需认证）</div>
    </div>
    
    <div class="group">
        <h2>💻 代码示例</h2>
        <pre>// 1. 自定义 notFound 处理器
app.not_found(fn (mut c hono.Context) http.Response {
    c.status(404)
    return c.json(\'{"error": "Not Found"}\')
})

// 2. all() 方法 - 匹配所有 HTTP 方法
app.all(\'/echo\', fn (mut c hono.Context) http.Response {
    return c.json(\'{"method": "\' + c.req.method + \'"}\')
})

// 3. 子应用中间件继承
mut books := hono.Hono.new()
books.use(auth_middleware)  // 只对 /api/books/* 生效
books.get(\'/\', handler)
app.route(\'/api/books\', mut books)</pre>
    </div>
    
    <div class="group">
        <h2>🧪 测试命令</h2>
        <pre># 测试 all() 方法
curl http://127.0.0.1:8080/echo
curl -X POST http://127.0.0.1:8080/echo
curl -X PUT http://127.0.0.1:8080/echo

# 测试自定义 404
curl http://127.0.0.1:8080/not-exist

# 测试 Admin 认证中间件
curl http://127.0.0.1:8080/admin  # 返回 401
curl -H "Authorization: Bearer admin-token" http://127.0.0.1:8080/admin  # 成功</pre>
    </div>
</body>
</html>'
}

// 打印路由信息
fn print_routes_info() {
	println('')
	println('📍 服务器地址: http://127.0.0.1:8080')
	println('')
	println('🆕 新功能:')
	println('  - notFound(): 自定义 404 处理器')
	println('  - onError(): 自定义错误处理器')
	println('  - all(): 匹配所有 HTTP 方法')
	println('  - 子应用中间件继承')
	println('')
	println('🔧 通用端点:')
	println('  GET    /           - 首页')
	println('  GET    /health     - 健康检查')
	println('  ALL    /echo       - Echo（所有方法）')
	println('')
	println('📡 API (/api):')
	println('  GET    /api/version - API 版本')
	println('')
	println('📚 Books API (/api/books):')
	println('  GET    /api/books       - 获取所有书籍')
	println('  GET    /api/books/:id   - 获取单本书籍')
	println('  POST   /api/books       - 创建书籍')
	println('  ALL    /api/books/stats - 统计')
	println('')
	println('🔐 Admin API (/admin) - 需要认证:')
	println('  GET    /admin       - 管理仪表盘')
	println('  GET    /admin/users - 用户管理')
	println('')
}
