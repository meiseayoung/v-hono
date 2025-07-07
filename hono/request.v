module hono

import net.http

// Context 结构体，类似 Hono.js 的实现
pub struct Context {
pub:
	req    http.Request
	params map[string]string
	query  map[string]string
	url    string
pub mut:
	status_code int = 200
	headers     map[string]string
	body        string
}

// Context 构造函数
pub fn Context.new(req http.Request, params map[string]string, query map[string]string, body string) Context {
	return Context{
		req: req
		params: params
		query: query
		body: body
		url: req.url
		headers: map[string]string{}
	}
}

// Context 的便捷方法 - 直接返回 http.Response
pub fn (mut c Context) json(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'application/json; charset=utf-8') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

pub fn (mut c Context) text(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/plain; charset=utf-8') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

pub fn (mut c Context) html(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/html; charset=utf-8') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

pub fn (mut c Context) status(code int) {
	c.status_code = code
}

// 处理器接口，使用 Context
pub interface IHandler {
	path string
	handle(mut c Context) http.Response
}

// 泛型处理器类型，使用 Context
pub type ContextHandlerFn = fn (mut Context) http.Response

// Context 处理器结构体
pub struct ContextHandler {
pub:
	path    string
	handler fn (mut Context) http.Response = unsafe { nil }
}

// 实现 IHandler 接口
pub fn (ch ContextHandler) handle(mut c Context) http.Response {
	return ch.handler(mut c)
}
