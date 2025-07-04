module hono

import net.http

pub struct Request {
pub:
	url   string
	param map[string]string
	query map[string]string
	body  string
}

// 接口定义，允许异构的泛型处理器
pub interface IRequestHandler {
	path string
	handle(req Request) http.Response
}

// 泛型处理器类型
pub type Handler = fn (Request) http.Response

// 泛型请求处理器结构体
pub struct RequestHandler {
pub:
	path    string
	handler fn (Request) http.Response = unsafe { nil }
}

// 实现 IRequestHandler 接口
pub fn (rh RequestHandler) handle(req Request) http.Response {
	return rh.handler(req)
}
