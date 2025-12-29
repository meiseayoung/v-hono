// vweb 服务器示例 - 用于性能对比测试
// 运行: v run server_vweb.v
// 测试: curl http://localhost:8080/

module main

import vweb

struct App {
	vweb.Context
}

fn main() {
	println('启动 vweb 服务器在端口 8080...')
	vweb.run(&App{}, 8080)
}

// 静态路由
@['/']
pub fn (mut app App) index() vweb.Result {
	return app.text('Hello World')
}

@['/api/health']
pub fn (mut app App) health() vweb.Result {
	return app.text('OK')
}

@['/api/users'; get]
pub fn (mut app App) get_users() vweb.Result {
	return app.json('{"users": []}')
}

@['/api/users'; post]
pub fn (mut app App) create_user() vweb.Result {
	return app.json('{"created": true}')
}

// 动态路由 - vweb 使用 :param 语法
@['/api/users/:id']
pub fn (mut app App) get_user(id string) vweb.Result {
	return app.json('{"id": "${id}"}')
}

@['/api/users/:id/posts']
pub fn (mut app App) get_user_posts(id string) vweb.Result {
	return app.json('{"posts": [], "user_id": "${id}"}')
}

@['/api/users/:user_id/posts/:post_id']
pub fn (mut app App) get_user_post(user_id string, post_id string) vweb.Result {
	return app.json('{"user_id": "${user_id}", "post_id": "${post_id}"}')
}

@['/api/categories/:cat/items/:item']
pub fn (mut app App) get_category_item(cat string, item string) vweb.Result {
	return app.json('{"category": "${cat}", "item": "${item}"}')
}
