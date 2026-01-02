// 优化分析：v-hono 静态路由性能瓶颈测试

module main

import time
import meiseayoung.hono
import net.http

const iterations = 100_000

fn main() {
	println('╔══════════════════════════════════════════════════════════════╗')
	println('║       v-hono 静态路由性能瓶颈分析                            ║')
	println('╚══════════════════════════════════════════════════════════════╝')
	
	// 测试1: 纯 map 查找
	test_pure_map()
	
	// 测试2: 带字符串拼接的 map 查找
	test_map_with_string_concat()
	
	// 测试3: v-hono FastRouter（带缓存）
	test_hono_with_cache()
	
	// 测试4: v-hono FastRouter（禁用缓存）
	test_hono_without_cache()
	
	// 测试5: 直接访问静态路由 map
	test_hono_direct_static()
}

fn test_pure_map() {
	println('\n[测试1] 纯 map 查找')
	println('----------------------------------------')
	
	mut routes := map[string]string{}
	routes['GET:/'] = 'handler1'
	routes['GET:/api/health'] = 'handler2'
	routes['GET:/api/users'] = 'handler3'
	
	sw := time.new_stopwatch()
	for _ in 0 .. iterations {
		_ := routes['GET:/api/users'] or { '' }
	}
	elapsed := sw.elapsed()
	
	avg_ns := elapsed.nanoseconds() / iterations
	println('  平均: ${avg_ns} ns/op')
	println('  吞吐: ${1_000_000_000 / avg_ns} ops/sec')
}

fn test_map_with_string_concat() {
	println('\n[测试2] 带字符串拼接的 map 查找')
	println('----------------------------------------')
	
	mut routes := map[string]string{}
	routes['GET:/'] = 'handler1'
	routes['GET:/api/health'] = 'handler2'
	routes['GET:/api/users'] = 'handler3'
	
	method := 'GET'
	path := '/api/users'
	
	sw := time.new_stopwatch()
	for _ in 0 .. iterations {
		key := '${method}:${path}'
		_ := routes[key] or { '' }
	}
	elapsed := sw.elapsed()
	
	avg_ns := elapsed.nanoseconds() / iterations
	println('  平均: ${avg_ns} ns/op')
	println('  吞吐: ${1_000_000_000 / avg_ns} ops/sec')
}

fn test_hono_with_cache() {
	println('\n[测试3] v-hono FastRouter（带 LRU 缓存）')
	println('----------------------------------------')
	
	mut app := hono.Hono.new()
	app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.text('users')
	})
	
	// 预热
	for _ in 0 .. 1000 {
		app.fast_router.match_route('GET', '/api/users') or { continue }
	}
	
	sw := time.new_stopwatch()
	for _ in 0 .. iterations {
		app.fast_router.match_route('GET', '/api/users') or { continue }
	}
	elapsed := sw.elapsed()
	
	avg_ns := elapsed.nanoseconds() / iterations
	println('  平均: ${avg_ns} ns/op')
	println('  吞吐: ${1_000_000_000 / avg_ns} ops/sec')
}

fn test_hono_without_cache() {
	println('\n[测试4] v-hono FastRouter（禁用缓存）')
	println('----------------------------------------')
	
	mut app := hono.Hono.new()
	app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.text('users')
	})
	
	// 禁用缓存
	app.fast_router.set_cache_enabled(false)
	
	sw := time.new_stopwatch()
	for _ in 0 .. iterations {
		app.fast_router.match_route('GET', '/api/users') or { continue }
	}
	elapsed := sw.elapsed()
	
	avg_ns := elapsed.nanoseconds() / iterations
	println('  平均: ${avg_ns} ns/op')
	println('  吞吐: ${1_000_000_000 / avg_ns} ops/sec')
}

fn test_hono_direct_static() {
	println('\n[测试5] 直接访问 FastRouter 静态路由 map')
	println('----------------------------------------')
	
	mut app := hono.Hono.new()
	app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.text('users')
	})
	
	sw := time.new_stopwatch()
	for _ in 0 .. iterations {
		key := 'GET:/api/users'
		_ := app.fast_router.static_routes[key] or { continue }
	}
	elapsed := sw.elapsed()
	
	avg_ns := elapsed.nanoseconds() / iterations
	println('  平均: ${avg_ns} ns/op')
	println('  吞吐: ${1_000_000_000 / avg_ns} ops/sec')
	
	println('\n╔══════════════════════════════════════════════════════════════╗')
	println('║                      分析结论                                ║')
	println('╠══════════════════════════════════════════════════════════════╣')
	println('║  性能瓶颈来源:                                               ║')
	println('║  1. LRU 缓存的 cleanup_expired_if_needed() 调用 time.now()   ║')
	println('║  2. 每次查询都要检查缓存过期（即使是静态路由）               ║')
	println('║  3. 创建 ContextRouteMatch 结构体的开销                      ║')
	println('║  4. 字符串拼接 cache_key 的开销                              ║')
	println('╚══════════════════════════════════════════════════════════════╝')
}
