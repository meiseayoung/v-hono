// veb 服务器示例 - 用于性能对比测试
// veb 是 V 语言官方的新版 web 框架（替代旧的 vweb）
// 
// 运行: v run server_veb.v
// 测试: curl http://127.0.0.1:8080/
//
// 压测命令:
//   wrk -t4 -c100 -d10s http://127.0.0.1:8080/
//   wrk -t4 -c100 -d10s http://127.0.0.1:8080/api/users/123

module main

import veb
import time

// 应用状态
pub struct App {
pub:
	start_time time.Time = time.now()
}

// Context 类型
pub struct Context {
	veb.Context
}

fn main() {
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║              veb 服务器 - 性能对比测试                        ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 端口: 8080                                                    ║')
	println('║ 测试端点:                                                     ║')
	println('║   GET  /                    - Hello World                     ║')
	println('║   GET  /api/health          - 健康检查                        ║')
	println('║   GET  /api/users           - 获取用户列表                    ║')
	println('║   POST /api/users           - 创建用户                        ║')
	println('║   GET  /api/users/:id       - 获取单个用户                    ║')
	println('║   GET  /api/users/:id/posts - 获取用户帖子                    ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')
	println('启动 veb 服务器在端口 8080...')
	
	mut app := &App{}
	veb.run[App, Context](mut app, 8080)
}

// ============================================
// 静态路由
// ============================================

// 首页
@['/']
pub fn (app &App) index(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.text('Hello World')
}

// 健康检查
@['/api/health']
pub fn (app &App) health(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.text('OK')
}

// 获取用户列表
@['/api/users'; get]
pub fn (app &App) get_users(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[[]User]([
		User{id: '1', name: 'Alice', email: 'alice@example.com'},
		User{id: '2', name: 'Bob', email: 'bob@example.com'},
	])
}

// 创建用户
@['/api/users'; post]
pub fn (app &App) create_user(mut ctx Context) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[CreateResponse](CreateResponse{created: true, id: '3'})
}

// ============================================
// 动态路由
// ============================================

// 获取单个用户
@['/api/users/:id']
pub fn (app &App) get_user(mut ctx Context, id string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[User](User{id: id, name: 'User ${id}', email: 'user${id}@example.com'})
}

// 获取用户的帖子
@['/api/users/:id/posts']
pub fn (app &App) get_user_posts(mut ctx Context, id string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[PostsResponse](PostsResponse{
		user_id: id
		posts: [
			Post{id: '1', title: 'First Post', content: 'Hello World'},
			Post{id: '2', title: 'Second Post', content: 'V is awesome'},
		]
	})
}

// 获取特定帖子
@['/api/users/:user_id/posts/:post_id']
pub fn (app &App) get_user_post(mut ctx Context, user_id string, post_id string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[PostResponse](PostResponse{
		user_id: user_id
		post_id: post_id
		post: Post{id: post_id, title: 'Post ${post_id}', content: 'Content of post ${post_id}'}
	})
}

// 获取分类商品
@['/api/categories/:cat/items/:item']
pub fn (app &App) get_category_item(mut ctx Context, cat string, item string) veb.Result {
	ctx.set_header(.connection, 'close')
	return ctx.json[ItemResponse](ItemResponse{
		category: cat
		item: item
		price: 99.99
	})
}

// ============================================
// 数据结构
// ============================================

struct User {
	id    string
	name  string
	email string
}

struct Post {
	id      string
	title   string
	content string
}

struct CreateResponse {
	created bool
	id      string
}

struct PostsResponse {
	user_id string
	posts   []Post
}

struct PostResponse {
	user_id string
	post_id string
	post    Post
}

struct ItemResponse {
	category string
	item     string
	price    f64
}
