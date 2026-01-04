module hono

import net.http

// CorsOrigin 类型 - 支持多种来源配置方式
// 可以是字符串（单域名或 "*"）、字符串数组（多域名）或回调函数
pub type CorsOrigin = string | []string | fn (string, Context) string

// CorsOptions 结构体 - CORS 配置选项
pub struct CorsOptions {
pub:
	origin         CorsOrigin = '*'  // 允许的来源，默认允许所有
	allow_methods  []string   = ['GET', 'HEAD', 'PUT', 'POST', 'DELETE', 'PATCH']
	allow_headers  []string   = []   // 允许的请求头
	expose_headers []string   = []   // 暴露的响应头
	max_age        int             // 预检请求缓存时间（秒），默认 0
	credentials    bool            // 是否允许凭证，默认 false
}

// cors - CORS 中间件工厂函数
// 返回一个 ContextMiddleware，用于处理跨域请求
pub fn cors(options ...CorsOptions) ContextMiddleware {
	opts := if options.len > 0 { options[0] } else { CorsOptions{} }
	
	return fn [opts] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 获取请求的 Origin 头
		origin := c.req.header.get_custom('Origin') or { '' }
		
		// 如果没有 Origin 头，直接继续处理
		if origin.len == 0 {
			return next(mut c)
		}
		
		// 计算允许的 Origin
		allowed_origin := get_allowed_origin(origin, opts.origin, c)
		
		// 如果 Origin 不被允许，直接继续处理（不设置 CORS 头）
		if allowed_origin.len == 0 {
			return next(mut c)
		}
		
		// 设置 Access-Control-Allow-Origin
		c.headers['Access-Control-Allow-Origin'] = allowed_origin
		
		// 设置 Access-Control-Allow-Credentials
		if opts.credentials {
			c.headers['Access-Control-Allow-Credentials'] = 'true'
		}
		
		// 设置 Access-Control-Expose-Headers
		if opts.expose_headers.len > 0 {
			c.headers['Access-Control-Expose-Headers'] = opts.expose_headers.join(', ')
		}
		
		// 检查是否为预检请求 (OPTIONS)
		if c.req.method == http.Method.options {
			return handle_preflight(mut c, opts)
		}
		
		// 非预检请求，继续处理
		return next(mut c)
	}
}

// get_allowed_origin - 根据配置计算允许的 Origin
fn get_allowed_origin(request_origin string, origin_config CorsOrigin, c Context) string {
	match origin_config {
		string {
			// 单个字符串配置
			if origin_config == '*' {
				// 通配符，允许所有来源
				return '*'
			}
			// 特定域名，检查是否匹配
			if origin_config == request_origin {
				return request_origin
			}
			return ''
		}
		[]string {
			// 多域名配置，检查请求来源是否在列表中
			for allowed in origin_config {
				if allowed == '*' {
					return '*'
				}
				if allowed == request_origin {
					return request_origin
				}
			}
			return ''
		}
		fn (string, Context) string {
			// 回调函数配置
			return origin_config(request_origin, c)
		}
	}
}

// handle_preflight - 处理 OPTIONS 预检请求
fn handle_preflight(mut c Context, opts CorsOptions) http.Response {
	// 设置 Access-Control-Allow-Methods
	if opts.allow_methods.len > 0 {
		c.headers['Access-Control-Allow-Methods'] = opts.allow_methods.join(', ')
	}
	
	// 设置 Access-Control-Allow-Headers
	if opts.allow_headers.len > 0 {
		c.headers['Access-Control-Allow-Headers'] = opts.allow_headers.join(', ')
	} else {
		// 如果没有配置，尝试使用请求中的 Access-Control-Request-Headers
		if request_headers := c.req.header.get_custom('Access-Control-Request-Headers') {
			c.headers['Access-Control-Allow-Headers'] = request_headers
		}
	}
	
	// 设置 Access-Control-Max-Age
	if opts.max_age > 0 {
		c.headers['Access-Control-Max-Age'] = opts.max_age.str()
	}
	
	// 返回 204 No Content
	c.status(204)
	
	mut headers := http.new_header()
	headers.add_custom('Connection', 'keep-alive') or {}
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	
	return http.Response{
		status_code: c.status_code
		header: headers
		body: ''
	}
}
