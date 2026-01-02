// FastCache 优化测试
// 验证高性能缓存的正确性和性能
module main

import meiseayoung.hono
import net.http
import time

struct TestResult {
mut:
	name   string
	passed bool
	detail string
}

fn main() {
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║           FastCache 优化测试                                  ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')

	mut results := []TestResult{}

	// 1. 基本功能测试
	results << test_basic_cache_operations()
	
	// 2. 路由匹配正确性测试
	results << test_route_matching_correctness()
	
	// 3. 参数提取正确性测试
	results << test_param_extraction()
	
	// 4. 缓存命中测试
	results << test_cache_hit()
	
	// 5. 缓存容量测试
	results << test_cache_capacity()
	
	// 6. 多路由并发测试
	results << test_multiple_routes()
	
	// 7. 性能基准测试
	results << test_performance_benchmark()
	
	// 8. 缓存一致性测试
	results << test_cache_consistency()

	// 打印结果
	println('')
	println('═══════════════════════════════════════════════════════════════')
	println('📊 测试结果汇总')
	println('═══════════════════════════════════════════════════════════════')
	
	mut passed := 0
	mut failed := 0
	
	for result in results {
		status := if result.passed { '✅' } else { '❌' }
		println('${status} ${result.name}')
		if result.detail.len > 0 {
			println('   ${result.detail}')
		}
		if result.passed {
			passed++
		} else {
			failed++
		}
	}
	
	println('')
	println('总计: ${passed}/${results.len} 通过')
	
	if failed == 0 {
		println('🎉 所有测试通过！FastCache 优化验证成功！')
	} else {
		println('⚠️  有 ${failed} 个测试失败')
	}
}

// 1. 基本缓存操作测试
fn test_basic_cache_operations() TestResult {
	mut cache := hono.FastRouteCache.new(100)
	
	// 测试 put 和 get
	test_match := hono.ContextRouteMatch{
		params: {'id': '123'}
		path: '/users/:id'
	}
	
	cache.put('GET:/users/123', test_match)
	
	if result := cache.get('GET:/users/123') {
		if result.params['id'] or { '' } == '123' {
			size, capacity := cache.get_stats()
			return TestResult{
				name: '基本缓存操作'
				passed: true
				detail: '缓存大小: ${size}/${capacity}'
			}
		}
	}
	
	return TestResult{
		name: '基本缓存操作'
		passed: false
		detail: '缓存 get/put 失败'
	}
}

// 2. 路由匹配正确性测试
fn test_route_matching_correctness() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	app.get('/posts/:post_id/comments/:comment_id', fn (mut c hono.Context) http.Response {
		return c.text('comment')
	})
	
	mut router := app.fast_router
	
	// 测试单参数路由
	if match1 := router.match_route('GET', '/users/456') {
		if match1.params['id'] or { '' } != '456' {
			return TestResult{name: '路由匹配正确性', passed: false, detail: '单参数提取错误'}
		}
	} else {
		return TestResult{name: '路由匹配正确性', passed: false, detail: '单参数路由匹配失败'}
	}
	
	// 测试多参数路由
	if match2 := router.match_route('GET', '/posts/100/comments/200') {
		post_id := match2.params['post_id'] or { '' }
		comment_id := match2.params['comment_id'] or { '' }
		if post_id != '100' || comment_id != '200' {
			return TestResult{name: '路由匹配正确性', passed: false, detail: '多参数提取错误: post_id=${post_id}, comment_id=${comment_id}'}
		}
	} else {
		return TestResult{name: '路由匹配正确性', passed: false, detail: '多参数路由匹配失败'}
	}
	
	return TestResult{name: '路由匹配正确性', passed: true, detail: '单参数和多参数路由均正确'}
}

// 3. 参数提取正确性测试
fn test_param_extraction() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/api/:version/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		return c.text('ok')
	})
	
	mut router := app.fast_router
	
	test_cases := [
		['/api/v1/users/100/posts/200', 'v1', '100', '200'],
		['/api/v2/users/abc/posts/xyz', 'v2', 'abc', 'xyz'],
		['/api/beta/users/user-123/posts/post-456', 'beta', 'user-123', 'post-456'],
	]
	
	for tc in test_cases {
		path := tc[0]
		expected_version := tc[1]
		expected_user := tc[2]
		expected_post := tc[3]
		
		if match_result := router.match_route('GET', path) {
			version := match_result.params['version'] or { '' }
			user_id := match_result.params['user_id'] or { '' }
			post_id := match_result.params['post_id'] or { '' }
			
			if version != expected_version || user_id != expected_user || post_id != expected_post {
				return TestResult{
					name: '参数提取正确性'
					passed: false
					detail: '路径 ${path} 参数提取错误'
				}
			}
		} else {
			return TestResult{name: '参数提取正确性', passed: false, detail: '路径 ${path} 匹配失败'}
		}
	}
	
	return TestResult{name: '参数提取正确性', passed: true, detail: '${test_cases.len} 个测试用例全部通过'}
}

// 4. 缓存命中测试
fn test_cache_hit() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	mut router := app.fast_router
	
	// 第一次匹配（缓存未命中，需要正则匹配）
	_ := router.match_route('GET', '/users/123')
	
	// 获取缓存统计
	cache_size1, _ := router.fast_cache.get_stats()
	
	// 第二次匹配（应该命中缓存）
	if match2 := router.match_route('GET', '/users/123') {
		if match2.params['id'] or { '' } == '123' {
			cache_size2, _ := router.fast_cache.get_stats()
			return TestResult{
				name: '缓存命中测试'
				passed: true
				detail: '缓存大小: ${cache_size1} -> ${cache_size2}，参数正确'
			}
		}
	}
	
	return TestResult{name: '缓存命中测试', passed: false, detail: '缓存命中后参数错误'}
}

// 5. 缓存容量测试
fn test_cache_capacity() TestResult {
	mut cache := hono.FastRouteCache.new(10)  // 小容量测试
	
	// 填满缓存
	for i in 0 .. 10 {
		cache.put('key${i}', hono.ContextRouteMatch{path: '/test/${i}'})
	}
	
	size1, _ := cache.get_stats()
	if size1 != 10 {
		return TestResult{name: '缓存容量测试', passed: false, detail: '填充后大小错误: ${size1}'}
	}
	
	// 超出容量，应该清空重建
	cache.put('key_overflow', hono.ContextRouteMatch{path: '/overflow'})
	
	size2, _ := cache.get_stats()
	if size2 != 1 {
		return TestResult{name: '缓存容量测试', passed: false, detail: '溢出后大小错误: ${size2}'}
	}
	
	// 验证新数据存在
	if _ := cache.get('key_overflow') {
		return TestResult{name: '缓存容量测试', passed: true, detail: '容量限制和清空重建正常'}
	}
	
	return TestResult{name: '缓存容量测试', passed: false, detail: '溢出后数据丢失'}
}

// 6. 多路由并发测试
fn test_multiple_routes() TestResult {
	mut app := hono.Hono.new()
	
	// 注册多个路由
	app.get('/users/:id', fn (mut c hono.Context) http.Response { return c.text('user') })
	app.get('/posts/:id', fn (mut c hono.Context) http.Response { return c.text('post') })
	app.get('/comments/:id', fn (mut c hono.Context) http.Response { return c.text('comment') })
	app.get('/tags/:name', fn (mut c hono.Context) http.Response { return c.text('tag') })
	
	mut router := app.fast_router
	
	// 交替匹配不同路由
	test_paths := [
		['/users/1', 'id', '1'],
		['/posts/2', 'id', '2'],
		['/comments/3', 'id', '3'],
		['/tags/golang', 'name', 'golang'],
		['/users/100', 'id', '100'],
		['/posts/200', 'id', '200'],
	]
	
	for tc in test_paths {
		path := tc[0]
		param_name := tc[1]
		expected_value := tc[2]
		
		if match_result := router.match_route('GET', path) {
			actual_value := match_result.params[param_name] or { '' }
			if actual_value != expected_value {
				return TestResult{
					name: '多路由并发测试'
					passed: false
					detail: '路径 ${path} 参数错误: 期望 ${expected_value}, 实际 ${actual_value}'
				}
			}
		} else {
			return TestResult{name: '多路由并发测试', passed: false, detail: '路径 ${path} 匹配失败'}
		}
	}
	
	return TestResult{name: '多路由并发测试', passed: true, detail: '${test_paths.len} 个路径全部正确'}
}

// 7. 性能基准测试
fn test_performance_benchmark() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user')
	})
	
	mut router := app.fast_router
	
	// 预热
	for i in 0 .. 100 {
		_ := router.match_route('GET', '/users/${i}')
	}
	
	// 测试缓存命中性能
	iterations := 10000
	sw := time.new_stopwatch()
	
	for _ in 0 .. iterations {
		_ := router.match_route('GET', '/users/50')  // 命中缓存
	}
	
	elapsed := sw.elapsed()
	avg_ns := elapsed.nanoseconds() / iterations
	avg_us := f64(avg_ns) / 1000.0
	
	// 缓存命中应该 < 1μs
	if avg_us < 1.0 {
		return TestResult{
			name: '性能基准测试'
			passed: true
			detail: '缓存命中平均耗时: ${avg_us:.3f}μs (< 1μs ✓)'
		}
	} else if avg_us < 5.0 {
		return TestResult{
			name: '性能基准测试'
			passed: true
			detail: '缓存命中平均耗时: ${avg_us:.3f}μs (< 5μs, 可接受)'
		}
	}
	
	return TestResult{
		name: '性能基准测试'
		passed: false
		detail: '缓存命中平均耗时: ${avg_us:.3f}μs (> 5μs, 过慢)'
	}
}

// 8. 缓存一致性测试
fn test_cache_consistency() TestResult {
	mut app := hono.Hono.new()
	
	app.get('/items/:id', fn (mut c hono.Context) http.Response {
		return c.text('item')
	})
	
	mut router := app.fast_router
	
	// 多次匹配相同路径，验证结果一致
	mut results := []string{}
	
	for _ in 0 .. 100 {
		if match_result := router.match_route('GET', '/items/999') {
			results << match_result.params['id'] or { 'error' }
		} else {
			results << 'no_match'
		}
	}
	
	// 检查所有结果是否一致
	first := results[0]
	for i, r in results {
		if r != first {
			return TestResult{
				name: '缓存一致性测试'
				passed: false
				detail: '第 ${i} 次结果不一致: ${r} != ${first}'
			}
		}
	}
	
	if first == '999' {
		return TestResult{name: '缓存一致性测试', passed: true, detail: '100 次匹配结果完全一致'}
	}
	
	return TestResult{name: '缓存一致性测试', passed: false, detail: '参数值错误: ${first}'}
}
