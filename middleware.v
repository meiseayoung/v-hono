// middleware.v - 中间件统一导出模块
// 本模块提供所有内置中间件的统一访问接口
// 使用方式: import hono 后可通过 hono.cors(), hono.jwt_middleware() 等方式调用
module hono

import net.http
import time
import rand

// ============================================================================
// 中间件导出说明
// ============================================================================
//
// 本框架提供以下 7 个内置中间件：
//
// 1. CORS 中间件 (cors.v)
//    - cors(options ...CorsOptions) ContextMiddleware
//    - 用于处理跨域资源共享
//
// 2. Cookie Helper (cookie.v)
//    - get_cookie(c Context, name string) ?string
//    - get_all_cookies(c Context) map[string]string
//    - set_cookie(mut c Context, name string, value string, options ...CookieOptions)
//    - delete_cookie(mut c Context, name string, options ...CookieOptions)
//    - set_signed_cookie(mut c Context, name string, value string, secret string, options ...CookieOptions) !
//    - get_signed_cookie(c Context, name string, secret string) !string
//
// 3. JWT 中间件 (jwt.v)
//    - jwt_middleware(options JwtOptions) ContextMiddleware
//    - sign_jwt(payload JwtPayload, secret string, alg JwtAlgorithm) !string
//    - verify_jwt(token string, secret string, alg JwtAlgorithm) !JwtPayload
//    - decode_jwt(token string) !JwtPayload
//    - get_jwt_payload(c Context) ?JwtPayload
//    - get_jwt_claim(c Context, key string) ?string
//
// 4. Bearer Auth 中间件 (bearer_auth.v)
//    - bearer_auth(options BearerAuthOptions) ContextMiddleware
//    - get_bearer_token(c Context) ?string
//
// 5. 压缩中间件 (compress.v)
//    - compress(options ...CompressOptions) ContextMiddleware
//    - decompress_gzip(data []u8) ![]u8
//    - decompress_deflate(data []u8) ![]u8
//
// 6. 限流中间件 (rate_limit.v)
//    - rate_limit(options RateLimitOptions) ContextMiddleware
//    - MemoryStore.new() &MemoryStore
//    - get_rate_limit_info(c Context) ?RateLimitInfo
//
// 7. 请求验证系统 (validator.v)
//    - validator(target ValidationTarget, schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware
//    - v_string() StringSchema
//    - v_int() IntSchema
//    - v_float() FloatSchema
//    - v_bool() BoolSchema
//    - v_array(items Schema) ArraySchema
//    - v_object(properties map[string]Schema) ObjectSchema
//    - get_validated_data(c Context) map[string]string
//    - get_validated_json(c Context) ?string
//    - get_validated_field(c Context, field string) ?string
//
// ============================================================================

// ============================================================================
// 中间件快捷别名函数
// 提供更简洁的调用方式，与 Hono.js 风格保持一致
// ============================================================================

// cors_middleware - CORS 中间件的别名函数
// 使用示例:
//   app.use(hono.cors_middleware())
//   app.use(hono.cors_middleware(CorsOptions{ origin: 'https://example.com' }))
pub fn cors_middleware(options ...CorsOptions) ContextMiddleware {
	return cors(...options)
}

// jwt_auth - JWT 认证中间件的别名函数
// 使用示例:
//   app.use('/api/*', hono.jwt_auth(JwtOptions{ secret: 'my-secret' }))
pub fn jwt_auth(options JwtOptions) ContextMiddleware {
	return jwt_middleware(options)
}

// bearer - Bearer Token 认证中间件的别名函数
// 使用示例:
//   app.use('/api/*', hono.bearer(BearerAuthOptions{ token: 'my-token' }))
pub fn bearer(options BearerAuthOptions) ContextMiddleware {
	return bearer_auth(options)
}

// gzip - 压缩中间件的别名函数（默认使用 gzip）
// 使用示例:
//   app.use(hono.gzip())
pub fn gzip(options ...CompressOptions) ContextMiddleware {
	if options.len > 0 {
		return compress(options[0])
	}
	return compress(CompressOptions{
		encoding: .gzip
	})
}

// deflate_compress - 压缩中间件的别名函数（使用 deflate）
// 使用示例:
//   app.use(hono.deflate_compress())
pub fn deflate_compress(options ...CompressOptions) ContextMiddleware {
	if options.len > 0 {
		return compress(options[0])
	}
	return compress(CompressOptions{
		encoding: .deflate
	})
}

// rate_limiter - 限流中间件的别名函数
// 使用示例:
//   store := MemoryStore.new()
//   app.use(hono.rate_limiter(RateLimitOptions{ store: store, limit: 100 }))
pub fn rate_limiter(options RateLimitOptions) ContextMiddleware {
	return rate_limit(options)
}

// validate_json - JSON body 验证中间件的便捷函数
// 使用示例:
//   app.post('/users', hono.validate_json(v_object({
//       'name': v_string().required()
//       'email': v_string().required()
//   })), handler)
pub fn validate_json(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.json, schema, ...options)
}

// validate_query - Query 参数验证中间件的便捷函数
// 使用示例:
//   app.get('/search', hono.validate_query(v_object({
//       'q': v_string().required()
//       'page': v_int().min(1)
//   })), handler)
pub fn validate_query(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.query, schema, ...options)
}

// validate_params - Path 参数验证中间件的便捷函数
// 使用示例:
//   app.get('/users/:id', hono.validate_params(v_object({
//       'id': v_int().required().min(1)
//   })), handler)
pub fn validate_params(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.param, schema, ...options)
}

// validate_headers - Header 验证中间件的便捷函数
// 使用示例:
//   app.use(hono.validate_headers(v_object({
//       'X-API-Key': v_string().required()
//   })))
pub fn validate_headers(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.header, schema, ...options)
}

// validate_form - Form 数据验证中间件的便捷函数
// 使用示例:
//   app.post('/login', hono.validate_form(v_object({
//       'username': v_string().required()
//       'password': v_string().required().min(6)
//   })), handler)
pub fn validate_form(schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	return validator(.form, schema, ...options)
}

// ============================================================================
// 中间件组合工具
// ============================================================================

// combine_middlewares - 组合多个中间件为一个
// 使用示例:
//   combined := hono.combine_middlewares([
//       hono.cors_middleware(),
//       hono.gzip(),
//       hono.rate_limiter(options)
//   ])
//   app.use(combined)
pub fn combine_middlewares(middlewares []ContextMiddleware) ContextMiddleware {
	return fn [middlewares] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 递归执行中间件链
		return execute_middleware_chain(0, middlewares, mut c, next)
	}
}

// execute_middleware_chain - 递归执行中间件链
fn execute_middleware_chain(idx int, middlewares []ContextMiddleware, mut c Context, final_next fn (mut Context) http.Response) http.Response {
	if idx >= middlewares.len {
		return final_next(mut c)
	}
	
	mw := middlewares[idx]
	return mw(mut c, fn [idx, middlewares, final_next] (mut ctx Context) http.Response {
		return execute_middleware_chain(idx + 1, middlewares, mut ctx, final_next)
	})
}

// ============================================================================
// 预配置中间件工厂
// ============================================================================

// secure_headers - 安全响应头中间件
// 添加常用的安全响应头
pub fn secure_headers() ContextMiddleware {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 设置安全响应头
		c.headers['X-Content-Type-Options'] = 'nosniff'
		c.headers['X-Frame-Options'] = 'DENY'
		c.headers['X-XSS-Protection'] = '1; mode=block'
		c.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
		
		return next(mut c)
	}
}

// request_id - 请求 ID 中间件
// 为每个请求生成唯一 ID
pub fn request_id() ContextMiddleware {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 检查是否已有请求 ID
		existing_id := c.req.header.get_custom('X-Request-ID') or { '' }
		
		request_id := if existing_id.len > 0 {
			existing_id
		} else {
			generate_request_id()
		}
		
		// 存储到 Context
		c.set('request_id', request_id)
		
		// 添加到响应头
		c.headers['X-Request-ID'] = request_id
		
		return next(mut c)
	}
}

// generate_request_id - 生成简单的请求 ID
fn generate_request_id() string {
	timestamp := time.now().unix_milli()
	random_part := rand.u32()
	return '${timestamp:x}-${random_part:08x}'
}

// timing - 请求计时中间件
// 记录请求处理时间
pub fn timing() ContextMiddleware {
	return fn (mut c Context, next fn (mut Context) http.Response) http.Response {
		start := time.now()
		
		// 执行后续处理
		response := next(mut c)
		
		// 计算耗时
		duration := time.since(start)
		duration_ms := duration.milliseconds()
		
		// 存储到 Context
		c.set('request_duration_ms', duration_ms.str())
		
		// 添加到响应头
		c.headers['X-Response-Time'] = '${duration_ms}ms'
		
		return response
	}
}

