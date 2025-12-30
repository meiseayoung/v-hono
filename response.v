module hono

import net.http

// 响应工具
pub struct Response {
}

// 创建HTML响应
pub fn Response.html(content string) http.Response {
	return http.Response{
		status_code: 200
		header: http.new_header(key: .content_type, value: 'text/html; charset=utf-8')
		body: content
	}
}

// 创建JSON响应
pub fn Response.json(content string) http.Response {
	return http.Response{
		status_code: 200
		header: http.new_header(key: .content_type, value: 'application/json; charset=utf-8')
		body: content
	}
}

// 创建文本响应
pub fn Response.text(content string) http.Response {
	return http.Response{
		status_code: 200
		header: http.new_header(key: .content_type, value: 'text/plain; charset=utf-8')
		body: content
	}
}

// 创建错误响应
pub fn Response.error(status_code int, message string) http.Response {
	return http.Response{
		status_code: status_code
		body: message
	}
}
