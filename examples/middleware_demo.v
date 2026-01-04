// middleware_demo.v - 中间件使用示例
// 本示例展示了 v-hono 框架所有内置中间件的基本用法
module main

import hono
import net.http
import time

fn main() {
	mut app := hono.Hono.new()
	
	// ============================================================================
	// 1. CORS 中间件示例
	// ============================================================================
	// 基本用法：允许所有来源
	app.use(hono.cors())
	
	// 高级配置示例（注释掉以避免重复）
	// app.use(hono.cors(hono.CorsOptions{
	//     origin: 'https://example.com'  // 只允许特定域名
	//     credentials: true               // 允许携带凭证
	//     max_age: 600                    // 预检请求缓存 10 分钟
	//     allow_methods: ['GET', 'POST', 'PUT', 'DELETE']
	//     allow_headers: ['Content-Type', 'Authorization']
	// }))
	
	// ============================================================================
	// 2. 压缩中间件示例
	// ============================================================================
	// 使用 gzip 压缩（默认）
	app.use(hono.gzip())
	
	// 或者使用 deflate 压缩
	// app.use(hono.deflate_compress())
	
	// 自定义压缩配置
	// app.use(hono.compress(hono.CompressOptions{
	//     encoding: .gzip
	//     threshold: 2048  // 只压缩大于 2KB 的响应
	//     level: 9         // 最高压缩级别
	// }))
	
	// ============================================================================
	// 3. 安全响应头中间件示例
	// ============================================================================
	app.use(hono.secure_headers())
	
	// ============================================================================
	// 4. 请求 ID 中间件示例
	// ============================================================================
	app.use(hono.request_id())
	
	// ============================================================================
	// 5. 请求计时中间件示例
	// ============================================================================
	app.use(hono.timing())
	
	// ============================================================================
	// 6. 限流中间件示例
	// ============================================================================
	// 创建内存存储
	store := hono.MemoryStore.new()
	
	// 应用限流中间件：每分钟最多 100 个请求
	app.use(hono.rate_limiter(hono.RateLimitOptions{
		store: store
		window_ms: 60000  // 1 分钟
		limit: 100        // 最多 100 个请求
		headers: true     // 添加限流响应头
	}))
	
	// ============================================================================
	// 路由示例
	// ============================================================================
	
	// 基本路由
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.json('{"message": "Welcome to v-hono middleware demo!"}')
	})
	
	// 获取请求信息
	app.get('/info', fn (mut c hono.Context) http.Response {
		// 获取请求 ID
		request_id := c.get('request_id') or { 'unknown' }
		// 获取客户端 IP
		client_ip := c.get_client_ip()
		
		return c.json('{"request_id": "${request_id}", "client_ip": "${client_ip}"}')
	})
	
	// ============================================================================
	// 7. Cookie Helper 示例
	// ============================================================================
	
	// 设置 Cookie
	app.get('/cookie/set', fn (mut c hono.Context) http.Response {
		// 设置普通 Cookie
		hono.set_cookie(mut c, 'session_id', 'abc123', hono.CookieOptions{
			http_only: true
			secure: false  // 开发环境设为 false
			max_age: 3600  // 1 小时
			path: '/'
		})
		
		return c.json('{"message": "Cookie set successfully"}')
	})
	
	// 获取 Cookie
	app.get('/cookie/get', fn (mut c hono.Context) http.Response {
		if session_id := hono.get_cookie(c, 'session_id') {
			return c.json('{"session_id": "${session_id}"}')
		}
		return c.json('{"error": "Cookie not found"}')
	})
	
	// 获取所有 Cookie
	app.get('/cookie/all', fn (mut c hono.Context) http.Response {
		cookies := hono.get_all_cookies(c)
		mut parts := []string{}
		for name, value in cookies {
			parts << '"${name}": "${value}"'
		}
		return c.json('{${parts.join(", ")}}')
	})
	
	// 删除 Cookie
	app.get('/cookie/delete', fn (mut c hono.Context) http.Response {
		hono.delete_cookie(mut c, 'session_id')
		return c.json('{"message": "Cookie deleted"}')
	})
	
	// 签名 Cookie 示例
	app.get('/cookie/signed/set', fn (mut c hono.Context) http.Response {
		secret := 'my-secret-key-for-signing'
		hono.set_signed_cookie(mut c, 'user_data', 'user123', secret) or {
			c.status(500)
			return c.json('{"error": "Failed to set signed cookie"}')
		}
		return c.json('{"message": "Signed cookie set successfully"}')
	})
	
	app.get('/cookie/signed/get', fn (mut c hono.Context) http.Response {
		secret := 'my-secret-key-for-signing'
		user_data := hono.get_signed_cookie(c, 'user_data', secret) or {
			c.status(400)
			return c.json('{"error": "Invalid or missing signed cookie"}')
		}
		return c.json('{"user_data": "${user_data}"}')
	})
	
	// ============================================================================
	// 8. JWT 中间件示例
	// ============================================================================
	
	// 生成 JWT Token
	app.post('/auth/login', fn (mut c hono.Context) http.Response {
		// 在实际应用中，这里应该验证用户凭证
		secret := 'my-jwt-secret-key'
		
		// 创建 JWT payload
		payload := hono.JwtPayload{
			sub: 'user123'
			iss: 'v-hono-demo'
			exp: time.now().unix() + 3600  // 1 小时后过期
			iat: time.now().unix()
			claims: {
				'role': 'admin'
				'name': 'John Doe'
			}
		}
		
		// 签名 JWT
		token := hono.sign_jwt(payload, secret, .hs256) or {
			c.status(500)
			return c.json('{"error": "Failed to generate token"}')
		}
		
		return c.json('{"token": "${token}"}')
	})
	
	// 验证 JWT Token（手动验证示例）
	app.get('/auth/verify', fn (mut c hono.Context) http.Response {
		secret := 'my-jwt-secret-key'
		
		// 从 Authorization 头获取 token
		auth_header := c.req.header.get_custom('Authorization') or {
			c.status(401)
			return c.json('{"error": "Missing Authorization header"}')
		}
		
		if !auth_header.starts_with('Bearer ') {
			c.status(401)
			return c.json('{"error": "Invalid Authorization format"}')
		}
		
		token := auth_header[7..]
		
		// 验证 token
		payload := hono.verify_jwt(token, secret, .hs256) or {
			c.status(401)
			return c.json('{"error": "Invalid token: ${err}"}')
		}
		
		return c.json('{"sub": "${payload.sub}", "iss": "${payload.iss}"}')
	})
	
	// ============================================================================
	// 9. Bearer Auth 中间件示例（保护特定路由）
	// ============================================================================
	
	// 创建受保护的子应用
	mut protected_app := hono.Hono.new()
	
	// 应用 Bearer Auth 中间件
	protected_app.use(hono.bearer(hono.BearerAuthOptions{
		token: 'my-api-token'  // 简单的静态 token
		realm: 'Protected API'
	}))
	
	protected_app.get('/data', fn (mut c hono.Context) http.Response {
		// 获取已验证的 token
		token := hono.get_bearer_token(c) or { 'unknown' }
		return c.json('{"message": "Protected data", "token": "${token}"}')
	})
	
	// 挂载受保护的路由
	app.route('/api', mut protected_app)
	
	// ============================================================================
	// 10. 请求验证示例
	// ============================================================================
	
	// JSON body 验证
	app.post('/users', 
		hono.validate_json(hono.v_object({
			'name':  hono.v_string().required().min(2).max(50)
			'email': hono.v_string().required().pattern(r'^[\w\.-]+@[\w\.-]+\.\w+$')
			'age':   hono.v_int().min(0).max(150)
		})),
		fn (mut c hono.Context) http.Response {
			// 获取验证后的数据
			data := hono.get_validated_data(c)
			name := data['name'] or { '' }
			email := data['email'] or { '' }
			
			return c.json('{"message": "User created", "name": "${name}", "email": "${email}"}')
		}
	)
	
	// Query 参数验证
	app.get('/search',
		hono.validate_query(hono.v_object({
			'q':    hono.v_string().required().min(1)
			'page': hono.v_int().min(1)
			'size': hono.v_int().min(1).max(100)
		})),
		fn (mut c hono.Context) http.Response {
			q := hono.get_validated_field(c, 'q') or { '' }
			page := hono.get_validated_field(c, 'page') or { '1' }
			
			return c.json('{"query": "${q}", "page": ${page}}')
		}
	)
	
	// ============================================================================
	// 11. 中间件组合示例
	// ============================================================================
	
	// 组合多个中间件
	combined := hono.combine_middlewares([
		hono.cors_middleware(),
		hono.secure_headers(),
		hono.timing(),
	])
	
	// 创建使用组合中间件的子应用
	mut combined_app := hono.Hono.new()
	combined_app.use(combined)
	
	combined_app.get('/test', fn (mut c hono.Context) http.Response {
		duration := c.get('request_duration_ms') or { '0' }
		return c.json('{"message": "Combined middleware test", "duration_ms": "${duration}"}')
	})
	
	app.route('/combined', mut combined_app)
	
	// ============================================================================
	// 启动服务器
	// ============================================================================
	
	println('=== v-hono Middleware Demo ===')
	println('')
	println('Available endpoints:')
	println('  GET  /                    - Welcome message')
	println('  GET  /info                - Request info (ID, IP)')
	println('')
	println('Cookie endpoints:')
	println('  GET  /cookie/set          - Set a cookie')
	println('  GET  /cookie/get          - Get a cookie')
	println('  GET  /cookie/all          - Get all cookies')
	println('  GET  /cookie/delete       - Delete a cookie')
	println('  GET  /cookie/signed/set   - Set a signed cookie')
	println('  GET  /cookie/signed/get   - Get a signed cookie')
	println('')
	println('Auth endpoints:')
	println('  POST /auth/login          - Get JWT token')
	println('  GET  /auth/verify         - Verify JWT token')
	println('  GET  /api/data            - Protected endpoint (Bearer token: my-api-token)')
	println('')
	println('Validation endpoints:')
	println('  POST /users               - Create user (JSON body validation)')
	println('  GET  /search?q=xxx        - Search (query validation)')
	println('')
	println('Combined middleware:')
	println('  GET  /combined/test       - Test combined middlewares')
	println('')
	println('Starting server on http://localhost:3000')
	println('')
	
	app.listen(':3000')
}
