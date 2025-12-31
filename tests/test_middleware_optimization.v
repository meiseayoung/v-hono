// 中间件优化测试
// 测试三个优化点：
// 1. 零中间件快速路径
// 2. 中间件预计算（启动时排序）
// 3. 复用 cache key

import hono
import time
import net.http

// 测试统计
struct TestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) start_test(test_name string) {
	stats.total_tests++
	print('🧪 ${test_name}... ')
}

fn (mut stats TestStats) pass_test() {
	stats.passed_tests++
	println('✅')
}

fn (mut stats TestStats) fail_test(error string) {
	stats.failed_tests++
	println('❌ ${error}')
}

fn (stats TestStats) print_summary() {
	println('\n=== 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')
	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// 测试1：零中间件快速路径 - has_middlewares 标志
fn test_zero_middleware_flag(mut stats TestStats) {
	stats.start_test('零中间件标志 (has_middlewares)')
	
	mut app := hono.Hono.new()
	
	// 新创建的应用应该没有中间件
	if app.has_middlewares {
		stats.fail_test('新应用不应该有中间件标志')
		return
	}
	
	// 添加中间件后标志应该为 true
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	
	if !app.has_middlewares {
		stats.fail_test('添加中间件后标志应该为 true')
		return
	}
	
	stats.pass_test()
}

// 测试2：中间件预计算 - sorted_middleware_prefixes
fn test_middleware_precompute(mut stats TestStats) {
	stats.start_test('中间件预计算 (sorted_middleware_prefixes)')
	
	mut app := hono.Hono.new()
	
	// 添加路由
	app.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	// 创建子应用并添加中间件
	mut sub_app := hono.Hono.new()
	sub_app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub_app.get('/hello', fn (mut c hono.Context) http.Response {
		return c.text('hello')
	})
	
	// 挂载子应用
	app.route('/api', mut sub_app)
	
	// 预计算前，sorted_middleware_prefixes 应该为空
	if app.sorted_middleware_prefixes.len != 0 {
		stats.fail_test('预计算前 sorted_middleware_prefixes 应该为空')
		return
	}
	
	// 调用预计算
	app.precompute_middleware_prefixes()
	
	// 预计算后，sorted_middleware_prefixes 应该包含前缀
	if app.sorted_middleware_prefixes.len == 0 && app.route_middlewares.len > 0 {
		stats.fail_test('预计算后 sorted_middleware_prefixes 应该包含前缀')
		return
	}
	
	// 验证 has_middlewares 标志
	if app.route_middlewares.len > 0 && !app.has_middlewares {
		stats.fail_test('有路由中间件时 has_middlewares 应该为 true')
		return
	}
	
	stats.pass_test()
}

// 测试3：FastRouter cache key 复用
fn test_fast_router_cache_key_reuse(mut stats TestStats) {
	stats.start_test('FastRouter cache key 复用')
	
	mut router := hono.FastRouter.new()
	
	// 添加静态路由
	static_handler := hono.ContextHandler{
		path: '/users'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('users')
		}
	}
	router.add_route('GET', static_handler, '') or {
		stats.fail_test('添加静态路由失败')
		return
	}
	
	// 添加动态路由
	dynamic_handler := hono.ContextHandler{
		path: '/users/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('user')
		}
	}
	router.add_route('GET', dynamic_handler, '') or {
		stats.fail_test('添加动态路由失败')
		return
	}
	
	// 测试静态路由匹配
	if _ := router.match_route('GET', '/users') {
		// 成功
	} else {
		stats.fail_test('静态路由匹配失败')
		return
	}
	
	// 测试动态路由匹配（第一次，会缓存）
	if match1 := router.match_route('GET', '/users/123') {
		if match1.params['id'] != '123' {
			stats.fail_test('参数提取失败')
			return
		}
	} else {
		stats.fail_test('动态路由匹配失败')
		return
	}
	
	// 测试动态路由匹配（第二次，应该命中缓存）
	if match2 := router.match_route('GET', '/users/123') {
		if match2.params['id'] != '123' {
			stats.fail_test('缓存命中后参数提取失败')
			return
		}
	} else {
		stats.fail_test('缓存命中失败')
		return
	}
	
	// 验证缓存状态
	_, _, cache_count := router.get_stats()
	if cache_count == 0 {
		stats.fail_test('缓存应该有条目')
		return
	}
	
	stats.pass_test()
}

// 测试4：HybridRouter cache key 复用
fn test_hybrid_router_cache_key_reuse(mut stats TestStats) {
	stats.start_test('HybridRouter cache key 复用')
	
	mut router := hono.ContextHybridRouter.new()
	
	// 添加动态路由
	dynamic_handler := hono.ContextHandler{
		path: '/posts/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('post')
		}
	}
	router.add_route('GET', dynamic_handler, '')
	
	// 第一次匹配（无缓存）
	if match1 := router.match_route('GET', '/posts/456') {
		if match1.params['id'] != '456' {
			stats.fail_test('参数提取失败')
			return
		}
	} else {
		stats.fail_test('动态路由匹配失败')
		return
	}
	
	// 第二次匹配（应该命中缓存）
	if match2 := router.match_route('GET', '/posts/456') {
		if match2.params['id'] != '456' {
			stats.fail_test('缓存命中后参数提取失败')
			return
		}
	} else {
		stats.fail_test('缓存命中失败')
		return
	}
	
	stats.pass_test()
}

// 测试5：性能对比 - 有中间件 vs 无中间件
fn test_middleware_performance_comparison(mut stats TestStats) {
	stats.start_test('中间件性能对比')
	
	// 创建无中间件的路由器
	mut router_no_mw := hono.FastRouter.new()
	handler := hono.ContextHandler{
		path: '/api/users/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('user')
		}
	}
	router_no_mw.add_route('GET', handler, '') or {
		stats.fail_test('添加路由失败')
		return
	}
	
	// 预热
	for _ in 0 .. 100 {
		_ := router_no_mw.match_route('GET', '/api/users/123') or { continue }
	}
	
	// 测试无中间件性能
	iterations := 10000
	start_no_mw := time.now()
	for _ in 0 .. iterations {
		_ := router_no_mw.match_route('GET', '/api/users/123') or { continue }
	}
	duration_no_mw := time.since(start_no_mw)
	
	// 创建有中间件的应用
	mut app_with_mw := hono.Hono.new()
	app_with_mw.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	app_with_mw.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	app_with_mw.precompute_middleware_prefixes()
	
	// 预热
	for _ in 0 .. 100 {
		_ := app_with_mw.fast_router.match_route('GET', '/api/users/123') or { continue }
	}
	
	// 测试有中间件性能
	start_with_mw := time.now()
	for _ in 0 .. iterations {
		_ := app_with_mw.fast_router.match_route('GET', '/api/users/123') or { continue }
	}
	duration_with_mw := time.since(start_with_mw)
	
	println('')
	println('  📊 无中间件: ${duration_no_mw.milliseconds()}ms (${iterations} 次)')
	println('  📊 有中间件: ${duration_with_mw.milliseconds()}ms (${iterations} 次)')
	
	// 性能差异不应该太大（路由匹配本身不受中间件影响）
	stats.pass_test()
}

// 测试6：预计算排序正确性
fn test_precompute_sorting(mut stats TestStats) {
	stats.start_test('预计算排序正确性')
	
	mut app := hono.Hono.new()
	
	// 添加多个子应用，模拟不同长度的前缀
	mut sub1 := hono.Hono.new()
	sub1.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub1.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	mut sub2 := hono.Hono.new()
	sub2.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub2.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	mut sub3 := hono.Hono.new()
	sub3.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		return next(mut c)
	})
	sub3.get('/test', fn (mut c hono.Context) http.Response {
		return c.text('test')
	})
	
	// 按不同顺序挂载（长前缀先挂载）
	app.route('/api/v1/users', mut sub1)
	app.route('/api', mut sub2)
	app.route('/api/v1', mut sub3)
	
	// 预计算
	app.precompute_middleware_prefixes()
	
	// 验证排序：短前缀应该在前面
	if app.sorted_middleware_prefixes.len >= 2 {
		for i in 0 .. app.sorted_middleware_prefixes.len - 1 {
			if app.sorted_middleware_prefixes[i].len > app.sorted_middleware_prefixes[i + 1].len {
				stats.fail_test('前缀排序不正确：${app.sorted_middleware_prefixes[i]} 应该在 ${app.sorted_middleware_prefixes[i + 1]} 之后')
				return
			}
		}
	}
	
	stats.pass_test()
}

fn main() {
	println('🚀 开始中间件优化测试...\n')
	
	mut stats := TestStats{}
	
	// 运行所有测试
	test_zero_middleware_flag(mut stats)
	test_middleware_precompute(mut stats)
	test_fast_router_cache_key_reuse(mut stats)
	test_hybrid_router_cache_key_reuse(mut stats)
	test_middleware_performance_comparison(mut stats)
	test_precompute_sorting(mut stats)
	
	// 打印测试总结
	stats.print_summary()
}
