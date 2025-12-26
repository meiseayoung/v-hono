import hono
import time
import net.http

fn main() {
	println('=== 简化路由优化测试 ===')
	
	// 测试优化路由器的基本功能
	test_basic_functionality()
	
	println('✅ 路由优化测试完成')
}

fn test_basic_functionality() {
	println('\n📊 测试基本功能...')
	
	mut router := hono.new_optimized_router()
	
	// 添加一些路由
	handler1 := hono.ContextHandler{
		path: '/users/:id'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('user')
		}
	}
	
	handler2 := hono.ContextHandler{
		path: '/static/file'
		handler: fn (mut c hono.Context) http.Response {
			return c.text('static')
		}
	}
	
	router.add_route('GET', handler1, '')
	router.add_route('GET', handler2, '')
	
	println('  添加了2个路由')
	println('  编译缓存大小: ${router.compiled_cache.len}')
	
	// 测试匹配
	if handler, params := router.match_route('GET', '/users/123') {
		println('  ✅ 动态路由匹配成功')
		println('  参数: ${params}')
	} else {
		println('  ❌ 动态路由匹配失败')
	}
	
	if handler, params := router.match_route('GET', '/static/file') {
		println('  ✅ 静态路由匹配成功')
	} else {
		println('  ❌ 静态路由匹配失败')
	}
	
	// 显示统计信息
	router.analyze_performance()
	
	// 健康检查
	if router.health_check() {
		println('  ✅ 路由器健康检查通过')
	} else {
		println('  ❌ 路由器健康检查失败')
	}
}