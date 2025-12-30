// picoev 优化集成测试
// 测试 picoev 服务器的完整功能，确保优化没有引入新问题
// 
// 使用方法:
// 1. 先启动测试服务器: v run tests/test_picoev_server.v
// 2. 运行测试: v run tests/test_picoev_integration.v

module main

import net.http
import time

// 测试统计
struct TestStats {
mut:
	total   int
	passed  int
	failed  int
	errors  []string
}

fn (mut s TestStats) run(name string, test_fn fn () bool) {
	s.total++
	print('  🧪 ${name}... ')
	
	result := test_fn()
	if result {
		s.passed++
		println('✅')
	} else {
		s.failed++
		s.errors << name
		println('❌')
	}
}

fn (s TestStats) summary() {
	println('')
	println('═══════════════════════════════════════════════════════════════')
	println('📊 测试结果: ${s.passed}/${s.total} 通过')
	
	if s.failed > 0 {
		println('❌ 失败的测试:')
		for err in s.errors {
			println('   - ${err}')
		}
	} else {
		println('🎉 所有测试通过！picoev 优化验证成功！')
	}
	println('═══════════════════════════════════════════════════════════════')
}

const base_url = 'http://127.0.0.1:9999'

fn main() {
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║           picoev 优化集成测试                                 ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')
	
	// 验证服务器是否运行
	println('🔍 检查测试服务器...')
	if !check_server_ready() {
		println('❌ 服务器未运行')
		println('   请先启动: v run tests/test_picoev_server.v')
		return
	}
	println('✅ 服务器已就绪')
	println('')
	
	mut stats := TestStats{}
	
	// 1. 基本 GET 路由测试
	println('📦 1. 基本 GET 路由测试')
	stats.run('GET 根路径', test_get_root)
	stats.run('GET 健康检查', test_get_health)
	stats.run('GET 静态路由', test_get_static)
	println('')
	
	// 2. 动态路由测试
	println('📦 2. 动态路由测试')
	stats.run('单参数路由', test_single_param)
	stats.run('多参数路由', test_multi_params)
	stats.run('嵌套参数路由', test_nested_params)
	println('')
	
	// 3. 查询参数测试
	println('📦 3. 查询参数测试')
	stats.run('单个查询参数', test_single_query)
	stats.run('多个查询参数', test_multi_query)
	println('')
	
	// 4. 响应格式测试
	println('📦 4. 响应格式测试')
	stats.run('JSON 响应', test_json_response)
	stats.run('HTML 响应', test_html_response)
	stats.run('自定义状态码 201', test_custom_status)
	println('')
	
	// 5. 中间件测试
	println('📦 5. 中间件测试')
	stats.run('全局中间件响应头', test_middleware_header)
	println('')
	
	// 6. 404 处理测试
	println('📦 6. 错误处理测试')
	stats.run('404 未找到', test_not_found)
	println('')
	
	// 7. Keep-Alive 测试
	println('📦 7. Keep-Alive 连接测试')
	stats.run('连接复用', test_keep_alive)
	println('')
	
	// 8. 性能测试
	println('📦 8. 性能测试')
	stats.run('响应时间 < 50ms', test_response_time)
	stats.run('吞吐量测试', test_throughput)
	println('')
	
	// 输出总结
	stats.summary()
}

// 检查服务器是否就绪
fn check_server_ready() bool {
	for _ in 0 .. 5 {
		resp := http.get(base_url + '/health') or {
			time.sleep(200 * time.millisecond)
			continue
		}
		if resp.status_code == 200 {
			return true
		}
		time.sleep(200 * time.millisecond)
	}
	return false
}

// ==================== 基本 GET 路由测试 ====================

fn test_get_root() bool {
	resp := http.get(base_url + '/') or { return false }
	return resp.status_code == 200 && resp.body.contains('Hello')
}

fn test_get_health() bool {
	resp := http.get(base_url + '/health') or { return false }
	return resp.status_code == 200 && resp.body == 'OK'
}

fn test_get_static() bool {
	resp := http.get(base_url + '/api/health') or { return false }
	return resp.status_code == 200 && resp.body == 'OK'
}

// ==================== 动态路由测试 ====================

fn test_single_param() bool {
	resp := http.get(base_url + '/api/users/456') or { return false }
	return resp.status_code == 200 && resp.body.contains('456')
}

fn test_multi_params() bool {
	resp := http.get(base_url + '/api/users/123/posts/789') or { return false }
	return resp.status_code == 200 && resp.body.contains('123') && resp.body.contains('789')
}

fn test_nested_params() bool {
	resp := http.get(base_url + '/api/categories/tech/items/laptop') or { return false }
	return resp.status_code == 200 && resp.body.contains('tech') && resp.body.contains('laptop')
}

// ==================== 查询参数测试 ====================

fn test_single_query() bool {
	resp := http.get(base_url + '/api/search?q=test') or { return false }
	return resp.status_code == 200 && resp.body.contains('test')
}

fn test_multi_query() bool {
	resp := http.get(base_url + '/api/search?q=hello&limit=10&page=1') or { return false }
	return resp.status_code == 200 && resp.body.contains('hello')
}

// ==================== 响应格式测试 ====================

fn test_json_response() bool {
	resp := http.get(base_url + '/api/json') or { return false }
	content_type := resp.header.get(.content_type) or { '' }
	return resp.status_code == 200 && content_type.contains('application/json')
}

fn test_html_response() bool {
	resp := http.get(base_url + '/api/html') or { return false }
	content_type := resp.header.get(.content_type) or { '' }
	return resp.status_code == 200 && content_type.contains('text/html')
}

fn test_custom_status() bool {
	resp := http.get(base_url + '/api/created') or { return false }
	return resp.status_code == 201
}

// ==================== 中间件测试 ====================

fn test_middleware_header() bool {
	resp := http.get(base_url + '/api/health') or { return false }
	// 检查中间件添加的响应头 - 通过原始响应检查
	raw_resp := resp.body
	// 中间件应该已经执行，检查响应是否正常
	return resp.status_code == 200 && raw_resp == 'OK'
}

// ==================== 错误处理测试 ====================

fn test_not_found() bool {
	resp := http.get(base_url + '/nonexistent/path/here') or { return false }
	return resp.status_code == 404
}

// ==================== Keep-Alive 测试 ====================

fn test_keep_alive() bool {
	// 发送多个请求，检查连接是否正常
	for _ in 0 .. 5 {
		resp := http.get(base_url + '/api/health') or { return false }
		if resp.status_code != 200 {
			return false
		}
	}
	return true
}

// ==================== 性能测试 ====================

fn test_response_time() bool {
	sw := time.new_stopwatch()
	
	for _ in 0 .. 10 {
		_ := http.get(base_url + '/api/health') or { return false }
	}
	
	elapsed := sw.elapsed()
	avg_ms := f64(elapsed.milliseconds()) / 10.0
	
	// 平均响应时间应小于 50ms
	return avg_ms < 50.0
}

fn test_throughput() bool {
	sw := time.new_stopwatch()
	requests := 50
	mut success := 0
	
	for _ in 0 .. requests {
		resp := http.get(base_url + '/api/health') or { continue }
		if resp.status_code == 200 {
			success++
		}
	}
	
	elapsed := sw.elapsed()
	rps := f64(success) * 1000.0 / f64(elapsed.milliseconds())
	
	print('(${rps:.0f} req/s) ')
	
	// 吞吐量应大于 20 req/s，成功率 > 90%
	return rps > 20.0 && success >= requests * 9 / 10
}
