// V-Hono 路由分组示例
// 参考 Hono.js 的路由分组功能: https://hono.dev/docs/api/routing#grouping
//
// Hono.js 路由分组示例:
// ```typescript
// const book = new Hono()
// book.get('/', (c) => c.text('List Books'))
// book.get('/:id', (c) => c.text('Get Book: ' + c.req.param('id')))
// 
// const app = new Hono()
// app.route('/books', book)
// ```

import net.http
import meiseayoung.hono

fn main() {
	println('🚀 V-Hono 路由分组示例启动中...')
	
	// 创建主应用
	mut app := hono.Hono.new()
	
	// 添加全局日志中间件
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[LOG] ${c.req.method} ${c.path}')
		return next(mut c)
	})
	
	// 根路由
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.html(generate_index_page())
	})
	
	// ========================================
	// 路由分组: Books API - /api/books
	// ========================================
	mut books := hono.Hono.new()
	
	// 在子应用中定义相对路径，挂载时会自动添加前缀
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
	
	books.put('/:id', fn (mut c hono.Context) http.Response {
		book_id := c.params['id']
		return c.json('{"message": "Book updated", "id": "${book_id}"}')
	})
	
	books.delete('/:id', fn (mut c hono.Context) http.Response {
		c.status(204)
		return c.text('')
	})
	
	// 挂载 books 路由组到 /api/books
	app.route('/api/books', mut books)
	
	// ========================================
	// 路由分组: Users API - /api/users
	// ========================================
	mut users := hono.Hono.new()
	
	users.get('/', fn (mut c hono.Context) http.Response {
		return c.json('[{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]')
	})
	
	users.get('/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		return c.json('{"id": "${user_id}", "name": "Alice", "email": "alice@example.com"}')
	})
	
	users.get('/:user_id/posts', fn (mut c hono.Context) http.Response {
		user_id := c.params['user_id']
		return c.json('[{"id": 1, "user_id": "${user_id}", "title": "My First Post"}]')
	})
	
	users.get('/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		user_id := c.params['user_id']
		post_id := c.params['post_id']
		return c.json('{"id": "${post_id}", "user_id": "${user_id}", "title": "My Post"}')
	})
	
	users.post('/', fn (mut c hono.Context) http.Response {
		c.status(201)
		return c.json('{"message": "User created", "body": "${c.body}"}')
	})
	
	// 挂载 users 路由组到 /api/users
	app.route('/api/users', mut users)
	
	// ========================================
	// 路由分组: Admin API - /admin
	// ========================================
	mut admin := hono.Hono.new()
	
	admin.get('/', fn (mut c hono.Context) http.Response {
		return c.json('{"page": "Admin Dashboard", "stats": {"users": 100, "books": 50}}')
	})
	
	admin.get('/users', fn (mut c hono.Context) http.Response {
		return c.json('[{"id": 1, "name": "Admin User", "role": "admin"}]')
	})
	
	admin.get('/settings', fn (mut c hono.Context) http.Response {
		return c.json('{"theme": "dark", "language": "zh-CN"}')
	})
	
	// 挂载 admin 路由组到 /admin
	app.route('/admin', mut admin)
	
	// ========================================
	// 其他路由（直接在主应用定义）
	// ========================================
	app.get('/health', fn (mut c hono.Context) http.Response {
		return c.json('{"status": "ok"}')
	})
	
	app.get('/api/version', fn (mut c hono.Context) http.Response {
		return c.json('{"version": "1.0.0", "name": "V-Hono API"}')
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
    <title>V-Hono 路由分组示例</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; }
        .group { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 8px; }
        .endpoint { background: #f5f5f5; padding: 10px; margin: 5px 0; border-radius: 4px; font-family: monospace; }
        .method { display: inline-block; width: 60px; font-weight: bold; }
        .get { color: #61affe; }
        .post { color: #49cc90; }
        .put { color: #fca130; }
        .delete { color: #f93e3e; }
        h2 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        pre { background: #2d2d2d; color: #f8f8f2; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🚀 V-Hono 路由分组示例</h1>
    <p>参考 <a href="https://hono.dev/docs/api/routing#grouping">Hono.js 路由分组</a> 实现</p>
    
    <div class="group">
        <h2>📚 Books API (/api/books)</h2>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/books">/api/books</a> - 获取所有书籍</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/books/1">/api/books/:id</a> - 获取单本书籍</div>
        <div class="endpoint"><span class="method post">POST</span> /api/books - 创建书籍</div>
        <div class="endpoint"><span class="method put">PUT</span> /api/books/:id - 更新书籍</div>
        <div class="endpoint"><span class="method delete">DELETE</span> /api/books/:id - 删除书籍</div>
    </div>
    
    <div class="group">
        <h2>👥 Users API (/api/users)</h2>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/users">/api/users</a> - 获取所有用户</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/users/1">/api/users/:id</a> - 获取单个用户</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/users/1/posts">/api/users/:user_id/posts</a> - 获取用户帖子</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/users/1/posts/1">/api/users/:user_id/posts/:post_id</a> - 获取特定帖子</div>
        <div class="endpoint"><span class="method post">POST</span> /api/users - 创建用户</div>
    </div>
    
    <div class="group">
        <h2>🔐 Admin API (/admin)</h2>
        <div class="endpoint"><span class="method get">GET</span> <a href="/admin">/admin</a> - 管理仪表盘</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/admin/users">/admin/users</a> - 用户管理</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/admin/settings">/admin/settings</a> - 系统设置</div>
    </div>
    
    <div class="group">
        <h2>🔧 其他端点</h2>
        <div class="endpoint"><span class="method get">GET</span> <a href="/health">/health</a> - 健康检查</div>
        <div class="endpoint"><span class="method get">GET</span> <a href="/api/version">/api/version</a> - API 版本</div>
    </div>
    
    <div class="group">
        <h2>💻 代码示例</h2>
        <pre>// 创建路由组
mut books := hono.Hono.new()

// 在子应用中定义相对路径
books.get("/", handler)           // -> /api/books
books.get("/:id", handler)        // -> /api/books/:id
books.post("/", handler)          // -> /api/books

// 挂载到主应用
app.route("/api/books", mut books)</pre>
    </div>
</body>
</html>'
}

// 打印路由信息
fn print_routes_info() {
	println('')
	println('📍 服务器地址: http://127.0.0.1:8080')
	println('')
	println('📚 Books API (/api/books):')
	println('  GET    /api/books     - 获取所有书籍')
	println('  GET    /api/books/:id - 获取单本书籍')
	println('  POST   /api/books     - 创建书籍')
	println('  PUT    /api/books/:id - 更新书籍')
	println('  DELETE /api/books/:id - 删除书籍')
	println('')
	println('👥 Users API (/api/users):')
	println('  GET    /api/users                         - 获取所有用户')
	println('  GET    /api/users/:id                     - 获取单个用户')
	println('  GET    /api/users/:user_id/posts          - 获取用户帖子')
	println('  GET    /api/users/:user_id/posts/:post_id - 获取特定帖子')
	println('  POST   /api/users                         - 创建用户')
	println('')
	println('🔐 Admin API (/admin):')
	println('  GET    /admin          - 管理仪表盘')
	println('  GET    /admin/users    - 用户管理')
	println('  GET    /admin/settings - 系统设置')
	println('')
}
