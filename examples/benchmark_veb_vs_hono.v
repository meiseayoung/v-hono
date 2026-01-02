// veb vs v-hono 性能对比测试
// 运行: v run benchmark_veb_vs_hono.v
// 
// 测试内容:
// 1. 路由匹配性能（纯路由，不启动服务器）
// 2. 静态路由 vs 动态路由性能对比
// 3. 缓存命中率分析

module main

import time
import meiseayoung.hono
import net.http

// ============================================
// 测试配置
// ============================================
const iterations = 10000
const warmup_iterations = 1000

// 测试路径
const static_paths = [
	'/',
	'/api/health',
	'/api/users',
]

const dynamic_paths = [
	'/api/users/123',
	'/api/users/456/posts',
	'/api/users/789/posts/101',
	'/api/categories/electronics/items/phone',
]

// ============================================
// 简单路由器（模拟 veb 的路由匹配方式）
// ============================================
struct SimpleRouter {
mut:
	static_routes  map[string]string
	dynamic_routes []DynamicRoute
}

struct DynamicRoute {
	pattern    string
	param_names []string
}

fn SimpleRouter.new() SimpleRouter {
	return SimpleRouter{
		static_routes: map[string]string{}
		dynamic_routes: []DynamicRoute{}
	}
}

fn (mut r SimpleRouter) add_static(path string) {
	r.static_routes[path] = path
}

fn (mut r SimpleRouter) add_dynamic(pattern string, param_names []string) {
	r.dynamic_routes << DynamicRoute{pattern, param_names}
}

// 简单的动态路由匹配（模拟 veb 的线性扫描方式）
fn (r SimpleRouter) match_route(path string) (bool, map[string]string) {
	// 1. 先尝试静态匹配
	if path in r.static_routes {
		return true, map[string]string{}
	}
	
	// 2. 动态路由匹配（线性扫描）
	path_parts := path.split('/').filter(it.len > 0)
	
	for route in r.dynamic_routes {
		pattern_parts := route.pattern.split('/').filter(it.len > 0)
		
		if path_parts.len != pattern_parts.len {
			continue
		}
		
		mut matched := true
		mut params := map[string]string{}
		mut param_idx := 0
		
		for i, part in pattern_parts {
			if part.starts_with(':') {
				// 参数匹配
				if param_idx < route.param_names.len {
					params[route.param_names[param_idx]] = path_parts[i]
					param_idx++
				}
			} else if part != path_parts[i] {
				matched = false
				break
			}
		}
		
		if matched {
			return true, params
		}
	}
	
	return false, map[string]string{}
}

// ============================================
// 基准测试函数
// ============================================
struct BenchmarkResult {
	name           string
	total_time_ns  i64
	avg_time_ns    i64
	min_time_ns    i64
	max_time_ns    i64
	ops_per_sec    f64
	iterations     int
}

fn benchmark(name string, iterations int, f fn () bool) BenchmarkResult {
	mut times := []i64{cap: iterations}
	mut min_time := i64(9223372036854775807)
	mut max_time := i64(0)
	
	// 预热
	for _ in 0 .. warmup_iterations {
		f()
	}
	
	// 正式测试
	for _ in 0 .. iterations {
		sw := time.new_stopwatch()
		f()
		elapsed := sw.elapsed().nanoseconds()
		times << elapsed
		
		if elapsed < min_time {
			min_time = elapsed
		}
		if elapsed > max_time {
			max_time = elapsed
		}
	}
	
	mut total := i64(0)
	for t in times {
		total += t
	}
	
	avg := total / iterations
	ops_per_sec := 1_000_000_000.0 / f64(avg)
	
	return BenchmarkResult{
		name: name
		total_time_ns: total
		avg_time_ns: avg
		min_time_ns: min_time
		max_time_ns: max_time
		ops_per_sec: ops_per_sec
		iterations: iterations
	}
}

fn print_result(r BenchmarkResult) {
	println('┌─────────────────────────────────────────────────────────────┐')
	println('│ ${r.name:-59} │')
	println('├─────────────────────────────────────────────────────────────┤')
	println('│ 迭代次数: ${r.iterations:-48} │')
	println('│ 总耗时:   ${r.total_time_ns / 1_000_000:-45} ms │')
	println('│ 平均耗时: ${r.avg_time_ns:-45} ns │')
	println('│ 最小耗时: ${r.min_time_ns:-45} ns │')
	println('│ 最大耗时: ${r.max_time_ns:-45} ns │')
	println('│ 吞吐量:   ${r.ops_per_sec:-42.0} ops/s │')
	println('└─────────────────────────────────────────────────────────────┘')
}

fn print_comparison(name string, simple_result BenchmarkResult, hono_result BenchmarkResult) {
	speedup := f64(simple_result.avg_time_ns) / f64(hono_result.avg_time_ns)
	winner := if speedup > 1.0 { 'v-hono' } else { 'SimpleRouter' }
	ratio := if speedup > 1.0 { speedup } else { 1.0 / speedup }
	
	println('')
	println('═══════════════════════════════════════════════════════════════')
	println(' ${name} 对比结果')
	println('═══════════════════════════════════════════════════════════════')
	println(' SimpleRouter: ${simple_result.avg_time_ns} ns/op (${simple_result.ops_per_sec:.0} ops/s)')
	println(' v-hono:       ${hono_result.avg_time_ns} ns/op (${hono_result.ops_per_sec:.0} ops/s)')
	println(' 胜出:         ${winner} (快 ${ratio:.2}x)')
	println('═══════════════════════════════════════════════════════════════')
}

// ============================================
// 主测试函数
// ============================================
fn main() {
	println('')
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║         veb vs v-hono 路由性能对比测试                        ║')
	println('║         (SimpleRouter 模拟 veb 的路由匹配方式)                ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 测试配置:                                                     ║')
	println('║   - 迭代次数: ${iterations:-46} ║')
	println('║   - 预热次数: ${warmup_iterations:-46} ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')
	
	// 初始化 SimpleRouter
	mut simple_router := SimpleRouter.new()
	simple_router.add_static('/')
	simple_router.add_static('/api/health')
	simple_router.add_static('/api/users')
	simple_router.add_dynamic('/api/users/:id', ['id'])
	simple_router.add_dynamic('/api/users/:id/posts', ['id'])
	simple_router.add_dynamic('/api/users/:user_id/posts/:post_id', ['user_id', 'post_id'])
	simple_router.add_dynamic('/api/categories/:cat/items/:item', ['cat', 'item'])
	
	// 初始化 v-hono
	mut hono_app := hono.Hono.new()
	hono_app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello World')
	})
	hono_app.get('/api/health', fn (mut c hono.Context) http.Response {
		return c.text('OK')
	})
	hono_app.get('/api/users', fn (mut c hono.Context) http.Response {
		return c.json('{"users": []}')
	})
	hono_app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
		return c.json('{"id": "123"}')
	})
	hono_app.get('/api/users/:id/posts', fn (mut c hono.Context) http.Response {
		return c.json('{"posts": []}')
	})
	hono_app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		return c.json('{"post": {}}')
	})
	hono_app.get('/api/categories/:cat/items/:item', fn (mut c hono.Context) http.Response {
		return c.json('{"item": {}}')
	})
	
	// ============================================
	// 测试 1: 静态路由性能
	// ============================================
	println('\n【测试 1】静态路由匹配性能')
	println('─────────────────────────────────────────────────────────────────')
	
	simple_static_result := benchmark('SimpleRouter 静态路由', iterations, fn [simple_router] () bool {
		for path in static_paths {
			simple_router.match_route(path)
		}
		return true
	})
	print_result(simple_static_result)
	
	hono_static_result := benchmark('v-hono 静态路由', iterations, fn [mut hono_app] () bool {
		for path in static_paths {
			hono_app.fast_router.match_route('GET', path) or { continue }
		}
		return true
	})
	print_result(hono_static_result)
	
	print_comparison('静态路由', simple_static_result, hono_static_result)
	
	// ============================================
	// 测试 2: 动态路由性能
	// ============================================
	println('\n【测试 2】动态路由匹配性能')
	println('─────────────────────────────────────────────────────────────────')
	
	simple_dynamic_result := benchmark('SimpleRouter 动态路由', iterations, fn [simple_router] () bool {
		for path in dynamic_paths {
			simple_router.match_route(path)
		}
		return true
	})
	print_result(simple_dynamic_result)
	
	hono_dynamic_result := benchmark('v-hono 动态路由', iterations, fn [mut hono_app] () bool {
		for path in dynamic_paths {
			hono_app.fast_router.match_route('GET', path) or { continue }
		}
		return true
	})
	print_result(hono_dynamic_result)
	
	print_comparison('动态路由', simple_dynamic_result, hono_dynamic_result)
	
	// ============================================
	// 测试 3: 混合路由性能
	// ============================================
	println('\n【测试 3】混合路由匹配性能（静态 + 动态）')
	println('─────────────────────────────────────────────────────────────────')
	
	mut all_paths := []string{}
	all_paths << static_paths
	all_paths << dynamic_paths
	
	simple_mixed_result := benchmark('SimpleRouter 混合路由', iterations, fn [simple_router, all_paths] () bool {
		for path in all_paths {
			simple_router.match_route(path)
		}
		return true
	})
	print_result(simple_mixed_result)
	
	hono_mixed_result := benchmark('v-hono 混合路由', iterations, fn [mut hono_app, all_paths] () bool {
		for path in all_paths {
			hono_app.fast_router.match_route('GET', path) or { continue }
		}
		return true
	})
	print_result(hono_mixed_result)
	
	print_comparison('混合路由', simple_mixed_result, hono_mixed_result)
	
	// ============================================
	// 路由器统计信息
	// ============================================
	println('\n【路由器统计信息】')
	println('─────────────────────────────────────────────────────────────────')
	
	static_count, dynamic_count, cache_count, _ := hono_app.get_router_stats()
	println('v-hono FastRouter:')
	println('  - 静态路由数: ${static_count}')
	println('  - 动态路由数: ${dynamic_count}')
	println('  - 缓存条目数: ${cache_count}')
	
	println('')
	println('SimpleRouter:')
	println('  - 静态路由数: ${simple_router.static_routes.len}')
	println('  - 动态路由数: ${simple_router.dynamic_routes.len}')
	
	// ============================================
	// 总结
	// ============================================
	println('\n')
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║                        测试总结                               ║')
	println('╠═══════════════════════════════════════════════════════════════╣')
	println('║ 1. 静态路由: SimpleRouter 使用 map 直接查找，通常更快        ║')
	println('║ 2. 动态路由: v-hono 使用 Trie + 缓存，性能更稳定             ║')
	println('║ 3. v-hono 的优势在于动态路由性能一致，不随复杂度增加而下降   ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
}
