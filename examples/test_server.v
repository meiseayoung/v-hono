// 测试服务器 - 用于高并发测试
module main

import meiseayoung.hono
import net.http

fn main() {
	mut app := hono.Hono.new()
	
	// 简单的测试路由
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	
	app.get('/delay', fn (mut c hono.Context) http.Response {
		// 模拟一些处理延迟
		return c.text('OK with delay')
	})
	
	println('测试服务器启动中...')
	println('配置: timeout_secs=120, keepalive_timeout=30, max_keepalive_req=10000')
	
	app.listen(':8888')
}
