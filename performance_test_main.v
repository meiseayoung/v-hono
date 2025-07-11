import hono
import net.http
import time

fn main() {
	println('=== 混合路由性能测试 ===')
	
	// 创建应用实例
	mut app := hono.Hono.new()
	
	// 添加静态路由
	app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"users": []}')
	})
	
	app.get('/api/posts', fn (mut c hono.Context) http.Response {
		return c.json('{"posts": []}')
	})
	
	app.get('/api/comments', fn (mut c hono.Context) http.Response {
		return c.json('{"comments": []}')
	})
	
	// 添加动态路由
	app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		return c.json('{"id": "${user_id}"}')
	})
	
	app.get('/api/posts/:id/comments', fn (mut c hono.Context) http.Response {
		post_id := c.params['id']
		return c.json('{"post_id": "${post_id}", "comments": []}')
	})
	
	app.get('/api/**/search', fn (mut c hono.Context) http.Response {
		return c.json('{"search": "wildcard"}')
	})
	
	// 添加100个动态路由
	println('添加100个动态路由...')
	for i := 1; i <= 100; i++ {
		// 用户相关路由
		app.get('/api/users/:id/profile', fn (mut c hono.Context) http.Response {
			user_id := c.params['id']
			return c.json('{"user_id": "${user_id}", "profile": {}}')
		})
		
		app.get('/api/users/:id/posts/:post_id', fn (mut c hono.Context) http.Response {
			user_id := c.params['id']
			post_id := c.params['post_id']
			return c.json('{"user_id": "${user_id}", "post_id": "${post_id}"}')
		})
		
		app.get('/api/users/:id/comments/:comment_id', fn (mut c hono.Context) http.Response {
			user_id := c.params['id']
			comment_id := c.params['comment_id']
			return c.json('{"user_id": "${user_id}", "comment_id": "${comment_id}"}')
		})
		
		// 帖子相关路由
		app.get('/api/posts/:id/author/:author_id', fn (mut c hono.Context) http.Response {
			post_id := c.params['id']
			author_id := c.params['author_id']
			return c.json('{"post_id": "${post_id}", "author_id": "${author_id}"}')
		})
		
		app.get('/api/posts/:id/tags/:tag_id', fn (mut c hono.Context) http.Response {
			post_id := c.params['id']
			tag_id := c.params['tag_id']
			return c.json('{"post_id": "${post_id}", "tag_id": "${tag_id}"}')
		})
		
		app.get('/api/posts/:id/categories/:category_id', fn (mut c hono.Context) http.Response {
			post_id := c.params['id']
			category_id := c.params['category_id']
			return c.json('{"post_id": "${post_id}", "category_id": "${category_id}"}')
		})
		
		// 评论相关路由
		app.get('/api/comments/:id/author/:author_id', fn (mut c hono.Context) http.Response {
			comment_id := c.params['id']
			author_id := c.params['author_id']
			return c.json('{"comment_id": "${comment_id}", "author_id": "${author_id}"}')
		})
		
		app.get('/api/comments/:id/post/:post_id', fn (mut c hono.Context) http.Response {
			comment_id := c.params['id']
			post_id := c.params['post_id']
			return c.json('{"comment_id": "${comment_id}", "post_id": "${post_id}"}')
		})
		
		// 分类相关路由
		app.get('/api/categories/:id/posts/:post_id', fn (mut c hono.Context) http.Response {
			category_id := c.params['id']
			post_id := c.params['post_id']
			return c.json('{"category_id": "${category_id}", "post_id": "${post_id}"}')
		})
		
		app.get('/api/categories/:id/tags/:tag_id', fn (mut c hono.Context) http.Response {
			category_id := c.params['id']
			tag_id := c.params['tag_id']
			return c.json('{"category_id": "${category_id}", "tag_id": "${tag_id}"}')
		})
	}
	
	// 测试静态路由性能
	println('\n--- 静态路由性能测试 ---')
	mut start := time.now()
	for i := 0; i < 1000000; i++ {
		app.context_hybrid_router.match_route('GET', '/api/users')
		app.context_hybrid_router.match_route('GET', '/api/posts')
		app.context_hybrid_router.match_route('GET', '/api/comments')
	}
	mut end := time.now()
	println('静态路由 1000000次匹配耗时: ${end - start}')
	
	// 测试动态路由性能（包含新增的100个路由）
	println('\n--- 动态路由性能测试（103个动态路由） ---')
	start = time.now()
	for i := 0; i < 1000000; i++ { // 减少测试次数，因为路由数量大幅增加
		app.context_hybrid_router.match_route('GET', '/api/users/123')
		app.context_hybrid_router.match_route('GET', '/api/posts/456/comments')
		app.context_hybrid_router.match_route('GET', '/api/anything/search')
		app.context_hybrid_router.match_route('GET', '/api/users/789/profile')
		app.context_hybrid_router.match_route('GET', '/api/posts/101/author/202')
		app.context_hybrid_router.match_route('GET', '/api/comments/303/post/404')
		app.context_hybrid_router.match_route('GET', '/api/categories/505/tags/606')
	}
	end = time.now()
	println('动态路由 1000000次匹配耗时: ${end - start}')
	
	// 测试缓存效果
	println('\n--- 缓存效果测试 ---')
	start = time.now()
	for i := 0; i < 1000000; i++ {
		app.context_hybrid_router.match_route('GET', '/api/users/123')
	}
	end = time.now()
	println('缓存命中 1000000次匹配耗时: ${end - start}')
	
	// 测试路由查找性能（遍历所有动态路由）
	println('\n--- 路由查找性能测试 ---')
	start = time.now()
	for i := 0; i < 10000; i++ {
		// 测试不同路由的匹配
		app.context_hybrid_router.match_route('GET', '/api/users/${i}')
		app.context_hybrid_router.match_route('GET', '/api/posts/${i}/comments')
		app.context_hybrid_router.match_route('GET', '/api/users/${i}/profile')
		app.context_hybrid_router.match_route('GET', '/api/posts/${i}/author/${i+1}')
		app.context_hybrid_router.match_route('GET', '/api/comments/${i}/post/${i+1}')
	}
	end = time.now()
	println('路由查找 50000次匹配耗时: ${end - start}')
	
	// 获取统计信息
	static_count, dynamic_count, cache_size, cache_capacity := app.get_router_stats()
	println('\n--- 路由统计信息 ---')
	println('静态路由数量: ${static_count}')
	println('动态路由数量: ${dynamic_count}')
	println('缓存大小: ${cache_size}/${cache_capacity}')
	
	// 添加 TrieRouter 性能测试
	println('\n--- Trie 路由树性能测试 ---')
	start = time.now()
	for i := 0; i < 1000000; i++ {
		app.context_trie_router.match_route('GET', '/api/users')
		app.context_trie_router.match_route('GET', '/api/posts')
		app.context_trie_router.match_route('GET', '/api/comments')
	}
	end = time.now()
	println('Trie静态路由 1000000次匹配耗时: ${end - start}')

	start = time.now()
	for i := 0; i < 1000000; i++ {
		app.context_trie_router.match_route('GET', '/api/users/123')
		app.context_trie_router.match_route('GET', '/api/posts/456/comments')
		app.context_trie_router.match_route('GET', '/api/anything/search')
		app.context_trie_router.match_route('GET', '/api/users/789/profile')
		app.context_trie_router.match_route('GET', '/api/posts/101/author/202')
		app.context_trie_router.match_route('GET', '/api/comments/303/post/404')
		app.context_trie_router.match_route('GET', '/api/categories/505/tags/606')
	}
	end = time.now()
	println('Trie动态路由 1000000次匹配耗时: ${end - start}')
	
	println('\n=== 测试完成 ===')
} 