module hono

import net.http

// BearerToken 类型 - 支持单 token 或多 token 配置
pub type BearerToken = string | []string

// BearerAuthOptions 结构体 - Bearer Auth 配置选项
pub struct BearerAuthOptions {
pub:
	token         BearerToken                         // Token 配置（必需）
	realm         string                              // WWW-Authenticate realm
	prefix        string       = 'Bearer'             // 认证前缀，默认 "Bearer"
	header_name   string       = 'Authorization'      // 请求头名称，默认 "Authorization"
	hash_function ?fn (string) string                 // 哈希函数（用于安全比较）
	verify_token  ?fn (string, Context) bool          // 自定义验证回调
}

// bearer_auth - Bearer Auth 中间件工厂函数
// 返回一个 ContextMiddleware，用于验证 Bearer Token
pub fn bearer_auth(options BearerAuthOptions) ContextMiddleware {
	return fn [options] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 获取 Authorization 头
		auth_header := c.req.header.get_custom(options.header_name) or {
			return unauthorized_response(mut c, options.realm, 'Missing authorization header')
		}

		if auth_header.len == 0 {
			return unauthorized_response(mut c, options.realm, 'Missing authorization header')
		}

		// 解析 token
		token := extract_bearer_token(auth_header, options.prefix) or {
			return unauthorized_response(mut c, options.realm, 'Invalid token format')
		}

		// 验证 token
		if !validate_bearer_token(token, options, c) {
			return unauthorized_response(mut c, options.realm, 'Invalid token')
		}

		// 将 token 存储到 Context（便于后续使用）
		c.set('bearer_token', token)

		// 继续处理请求
		return next(mut c)
	}
}

// extract_bearer_token - 从 Authorization 头提取 token
fn extract_bearer_token(auth_header string, prefix string) !string {
	expected_prefix := '${prefix} '

	if !auth_header.starts_with(expected_prefix) {
		return error('Invalid authorization format')
	}

	token := auth_header[expected_prefix.len..].trim_space()

	if token.len == 0 {
		return error('Empty token')
	}

	return token
}

// validate_bearer_token - 验证 Bearer Token
fn validate_bearer_token(token string, options BearerAuthOptions, c Context) bool {
	// 优先使用自定义验证回调
	if verify_fn := options.verify_token {
		return verify_fn(token, c)
	}

	// 使用配置的 token 进行验证
	match options.token {
		string {
			// 单 token 验证
			return secure_token_compare(token, options.token, options.hash_function)
		}
		[]string {
			// 多 token 验证
			for valid_token in options.token {
				if secure_token_compare(token, valid_token, options.hash_function) {
					return true
				}
			}
			return false
		}
	}
}

// secure_token_compare - 安全的 token 比较（防止时序攻击）
fn secure_token_compare(provided string, expected string, hash_fn ?fn (string) string) bool {
	// 如果提供了哈希函数，先对 token 进行哈希
	if hash_function := hash_fn {
		hashed_provided := hash_function(provided)
		hashed_expected := hash_function(expected)
		return constant_time_compare_bearer(hashed_provided, hashed_expected)
	}

	// 直接使用常量时间比较
	return constant_time_compare_bearer(provided, expected)
}

// constant_time_compare_bearer - 常量时间字符串比较，防止时序攻击
fn constant_time_compare_bearer(a string, b string) bool {
	if a.len != b.len {
		return false
	}

	mut result := u8(0)
	for i := 0; i < a.len; i++ {
		result |= a[i] ^ b[i]
	}

	return result == 0
}

// unauthorized_response - 返回 401 未授权响应
fn unauthorized_response(mut c Context, realm string, message string) http.Response {
	c.status(401)

	// 设置 WWW-Authenticate 头
	mut www_auth := 'Bearer'
	if realm.len > 0 {
		www_auth = 'Bearer realm="${realm}"'
	}
	c.headers['WWW-Authenticate'] = www_auth

	return c.json('{"error":"Unauthorized","message":"${message}"}')
}

// get_bearer_token - 从 Context 获取已验证的 Bearer Token
// 这是一个便捷方法，用于在 handler 中获取已验证的 token
pub fn get_bearer_token(c Context) ?string {
	return c.get('bearer_token')
}
