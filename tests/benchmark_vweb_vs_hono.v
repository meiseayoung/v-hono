// vweb vs v-hono 性能对比测试
// 测试路由匹配性能（不启动实际服务器）

module main

import time
import hono
import net.http

// ============================================
// 测试配置
// ============================================
const iterations = 100_000
const warmup_iterations = 1000

// ============================================
// v-hono 路由测试
// ============================================
fn setup_hono_app() hono.Hono {
	mut app := hono.Hono.new()
	
	// 静态路由
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello World')
	})
	app.get('/api/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"users": []}')
	})
	app.post('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"created": true}')
	})
	
	// 动态路由
	app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		id := c.params['id'] or { '' }
		return c.json('{"id": "${id}"}')
	})
	app.get('/api/users/:id/posts', fn (mut c hono.Context) http.Response {
		return c.json('{"posts": []}')
	})
	app.get('/api/users/:id/posts/:post_id', fn (mut c hono.Context) http.Response {
		return c.json('{"post": {}}')
	})
	app.get('/api/categories/:cat/items/:item', fn (mut c hono.Context) http.Response {
		return c.json('{"item": {}}')
	})
	
	return app
}

fn benchmark_hono_routing(mut app hono.Hono) {
	println('\n========================================')
	println('v-hono 路由性能测试')
	println('========================================')
	
	// 测试路径
	test_paths := [
		['GET', '/'],
		['GET', '/api/health'],
		['GET', '/api/users'],
		['POST', '/api/users'],
		['GET', '/api/users/123'],
		['GET', '/api/users/456/posts'],
		['GET', '/api/users/789/posts/101'],
		['GET', '/api/categories/electronics/items/phone'],
	]
	
	// 预热
	println('预热中 (${warmup_iterations} 次)...')
	for _ in 0 .. warmup_iterations {
		for path_info in test_paths {
			method := path_info[0]
			path := path_info[1]
			app.fast_router.match_route(method, path) or { continue }
		}
	}
	
	// 正式测试
	println('正式测试 (${iterations} 次)...\n')
	
	mut total_time := i64(0)
	mut match_count := 0
	
	for path_info in test_paths {
		method := path_info[0]
		path := path_info[1]
		
		sw := time.new_stopwatch()
		for _ in 0 .. iterations {
			if _ := app.fast_router.match_route(method, path) {
				match_count++
			}
		}
		elapsed := sw.elapsed()
		total_time += elapsed.nanoseconds()
		
		avg_ns := elapsed.nanoseconds() / iterations
		ops_per_sec := if avg_ns > 0 { 1_000_000_000 / avg_ns } else { 0 }
		
		println('  ${method} ${path}')
		println('    总耗时: ${elapsed}')
		println('    平均: ${avg_ns} ns/op')
		println('    吞吐: ${ops_per_sec} ops/sec')
		println('')
	}
	
	total_ops := iterations * test_paths.len
	avg_total_ns := total_time / total_ops
	total_ops_per_sec := if avg_total_ns > 0 { 1_000_000_000 / avg_total_ns } else { 0 }
	
	println('----------------------------------------')
	println('v-hono 总计:')
	println('  总操作数: ${total_ops}')
	println('  总耗时: ${total_time / 1_000_000} ms')
	println('  平均: ${avg_total_ns} ns/op')
	println('  吞吐: ${total_ops_per_sec} ops/sec')
}

// ============================================
// 简单的路由匹配模拟（模拟 vweb 的路由行为）
// ============================================
struct SimpleRouter {
mut:
	routes map[string]string
}

fn SimpleRouter.new() SimpleRouter {
	return SimpleRouter{
		routes: map[string]string{}
	}
}

fn (mut r SimpleRouter) add(method string, path string) {
	r.routes['${method}:${path}'] = path
}

fn (r SimpleRouter) match_static(method string, path string) ?string {
	key := '${method}:${path}'
	if key in r.routes {
		return r.routes[key]
	}
	return none
}

// 模拟 vweb 的简单路由匹配（基于字符串比较）
fn (r SimpleRouter) match_simple(method string, path string) ?string {
	// vweb 使用属性注解和函数名映射，这里模拟其基本行为
	key := '${method}:${path}'
	if key in r.routes {
		return r.routes[key]
	}
	
	// 简单的动态路由匹配（模拟 vweb 的参数提取）
	for route_key, route_path in r.routes {
		if route_key.starts_with('${method}:') {
			if match_dynamic_simple(route_path, path) {
				return route_path
			}
		}
	}
	return none
}

// 简单的动态路由匹配
fn match_dynamic_simple(pattern string, path string) bool {
	pattern_parts := pattern.split('/')
	path_parts := path.split('/')
	
	if pattern_parts.len != path_parts.len {
		return false
	}
	
	for i, part in pattern_parts {
		if part.starts_with(':') {
			continue // 参数匹配任意值
		}
		if part != path_parts[i] {
			return false
		}
	}
	return true
}

fn benchmark_simple_routing() {
	println('\n========================================')
	println('简单路由器性能测试 (模拟 vweb 行为)')
	println('========================================')
	
	mut router := SimpleRouter.new()
	
	// 添加路由
	router.add('GET', '/')
	router.add('GET', '/api/health')
	router.add('GET', '/api/users')
	router.add('POST', '/api/users')
	router.add('GET', '/api/users/:id')
	router.add('GET', '/api/users/:id/posts')
	router.add('GET', '/api/users/:id/posts/:post_id')
	router.add('GET', '/api/categories/:cat/items/:item')
	
	test_paths := [
		['GET', '/'],
		['GET', '/api/health'],
		['GET', '/api/users'],
		['POST', '/api/users'],
		['GET', '/api/users/123'],
		['GET', '/api/users/456/posts'],
		['GET', '/api/users/789/posts/101'],
		['GET', '/api/categories/electronics/items/phone'],
	]
	
	// 预热
	println('预热中 (${warmup_iterations} 次)...')
	for _ in 0 .. warmup_iterations {
		for path_info in test_paths {
			method := path_info[0]
			path := path_info[1]
			router.match_simple(method, path) or { continue }
		}
	}
	
	// 正式测试
	println('正式测试 (${iterations} 次)...\n')
	
	mut total_time := i64(0)
	
	for path_info in test_paths {
		method := path_info[0]
		path := path_info[1]
		
		sw := time.new_stopwatch()
		for _ in 0 .. iterations {
			router.match_simple(method, path) or { continue }
		}
		elapsed := sw.elapsed()
		total_time += elapsed.nanoseconds()
		
		avg_ns := elapsed.nanoseconds() / iterations
		ops_per_sec := if avg_ns > 0 { 1_000_000_000 / avg_ns } else { 0 }
		
		println('  ${method} ${path}')
		println('    总耗时: ${elapsed}')
		println('    平均: ${avg_ns} ns/op')
		println('    吞吐: ${ops_per_sec} ops/sec')
		println('')
	}
	
	total_ops := iterations * test_paths.len
	avg_total_ns := total_time / total_ops
	total_ops_per_sec := if avg_total_ns > 0 { 1_000_000_000 / avg_total_ns } else { 0 }
	
	println('----------------------------------------')
	println('简单路由器 总计:')
	println('  总操作数: ${total_ops}')
	println('  总耗时: ${total_time / 1_000_000} ms')
	println('  平均: ${avg_total_ns} ns/op')
	println('  吞吐: ${total_ops_per_sec} ops/sec')
}

// ============================================
// 主函数
// ============================================
fn main() {
	println('╔══════════════════════════════════════════════════════════════╗')
	println('║       vweb vs v-hono 路由性能对比测试                        ║')
	println('╠══════════════════════════════════════════════════════════════╣')
	println('║  测试内容: 路由匹配性能                                      ║')
	println('║  迭代次数: ${iterations}                                       ║')
	println('║  预热次数: ${warmup_iterations}                                          ║')
	println('╚══════════════════════════════════════════════════════════════╝')
	
	// 测试简单路由器（模拟 vweb）
	benchmark_simple_routing()
	
	// 测试 v-hono
	mut hono_app := setup_hono_app()
	benchmark_hono_routing(mut hono_app)
	
	// 输出对比总结
	println('\n╔══════════════════════════════════════════════════════════════╗')
	println('║                      测试完成                                ║')
	println('╠══════════════════════════════════════════════════════════════╣')
	println('║  说明:                                                       ║')
	println('║  - 简单路由器模拟了 vweb 的基本路由匹配行为                  ║')
	println('║  - v-hono 使用了优化的 FastRouter 和缓存机制                 ║')
	println('║  - 实际 HTTP 服务器性能还受网络 I/O 等因素影响               ║')
	println('╚══════════════════════════════════════════════════════════════╝')
}
