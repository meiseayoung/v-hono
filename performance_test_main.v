module main

import hono
import net.http
import time

fn main() {
	println('=== 混合路由性能测试 ===')
	
	// 创建应用实例
	mut app := hono.new_hono()
	
	// 添加静态路由
	app.get('/api/users', fn (req hono.Request) http.Response {
		return hono.Response.json('{"users": []}')
	})
	
	app.get('/api/posts', fn (req hono.Request) http.Response {
		return hono.Response.json('{"posts": []}')
	})
	
	app.get('/api/comments', fn (req hono.Request) http.Response {
		return hono.Response.json('{"comments": []}')
	})
	
	// 添加动态路由
	app.get('/api/users/:id', fn (req hono.Request) http.Response {
		return hono.Response.json('{"user_id": "${req.param["id"]}"}')
	})
	
	app.get('/api/posts/:id/comments', fn (req hono.Request) http.Response {
		return hono.Response.json('{"post_id": "${req.param["id"]}", "comments": []}')
	})
	
	app.get('/api/**/search', fn (req hono.Request) http.Response {
		return hono.Response.json('{"search": "wildcard"}')
	})
	
	// 测试静态路由性能
	println('\n--- 静态路由性能测试 ---')
	mut start := time.now()
	for i := 0; i < 1000000; i++ {
		_ = app.hybrid_router.match_route('GET', '/api/users')
		_ = app.hybrid_router.match_route('GET', '/api/posts')
		_ = app.hybrid_router.match_route('GET', '/api/comments')
	}
	mut end := time.now()
	println('静态路由 1000000次匹配耗时: ${end - start}')
	
	// 测试动态路由性能
	println('\n--- 动态路由性能测试 ---')
	start = time.now()
	for i := 0; i < 1000000; i++ {
		_ = app.hybrid_router.match_route('GET', '/api/users/123')
		_ = app.hybrid_router.match_route('GET', '/api/posts/456/comments')
		_ = app.hybrid_router.match_route('GET', '/api/anything/search')
	}
	end = time.now()
	println('动态路由 1000000: ${end - start}')
	
	// 测试缓存效果
	println('\n--- 缓存效果测试 ---')
	start = time.now()
	for i := 0; i < 1000000; i++ {
		_ = app.hybrid_router.match_route('GET', '/api/users/123')
	}
	end = time.now()
	println('缓存命中 1000000次匹配耗时: ${end - start}')
	
	// 获取统计信息
	static_count, dynamic_count, cache_size, cache_capacity := app.get_router_stats()
	println('\n--- 路由统计信息 ---')
	println('静态路由数量: ${static_count}')
	println('动态路由数量: ${dynamic_count}')
	println('缓存大小: ${cache_size}/${cache_capacity}')
	
	println('\n=== 测试完成 ===')
} 