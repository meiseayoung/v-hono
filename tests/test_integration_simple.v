import meiseayoung.hono
import time
import net.http

fn main() {
	println('=== V-Hono 简化集成测试 ===')
	
	// 测试1: 基本应用创建和FastRouter
	test_basic_app_creation()
	
	// 测试2: 路由添加和匹配
	test_route_management()
	
	// 测试3: 性能验证
	test_performance_validation()
	
	// 测试4: 配置系统
	test_config_system()
	
	println('✅ V-Hono 简化集成测试完成')
}

fn test_basic_app_creation() {
	println('\n📊 基本应用创建测试...')
	
	// 创建应用
	mut app := hono.Hono.new()
	
	// 验证FastRouter默认启用
	if app.use_fast_router {
		println('  ✅ FastRouter默认启用')
	} else {
		println('  ❌ FastRouter未默认启用')
	}
	
	// 测试FastRouter开关
	app.set_fast_router_enabled(false)
	if !app.use_fast_router {
		println('  ✅ FastRouter禁用成功')
	} else {
		println('  ❌ FastRouter禁用失败')
	}
	
	app.set_fast_router_enabled(true)
	if app.use_fast_router {
		println('  ✅ FastRouter重新启用成功')
	} else {
		println('  ❌ FastRouter重新启用失败')
	}
}

fn test_route_management() {
	println('\n📊 路由管理测试...')
	
	mut app := hono.Hono.new()
	
	// 添加不同类型的路由
	app.get('/static', fn (mut c hono.Context) http.Response {
		return c.text('static response')
	})
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		return c.text('user response')
	})
	
	app.post('/api/:version/users', fn (mut c hono.Context) http.Response {
		return c.text('api response')
	})
	
	// 验证路由统计
	static_count, dynamic_count, cache_count, _ := app.get_router_stats()
	println('  路由统计: 静态=${static_count}, 动态=${dynamic_count}, 缓存=${cache_count}')
	
	// 测试路由匹配
	test_paths := ['/static', '/users/123', '/nonexistent']
	expected_results := [true, true, false]
	
	mut success_count := 0
	for i, path in test_paths {
		expected := expected_results[i]
		
		match_result := app.fast_router.match_route('GET', path)
		actual := match_result != none
		
		if actual == expected {
			success_count++
		}
	}
	
	if success_count == test_paths.len {
		println('  ✅ 路由匹配测试通过 (${success_count}/${test_paths.len})')
	} else {
		println('  ❌ 路由匹配测试失败 (${success_count}/${test_paths.len})')
	}
}

fn test_performance_validation() {
	println('\n📊 性能验证测试...')
	
	// 创建FastRouter和HybridRouter进行对比
	mut fast_router := hono.FastRouter.new()
	mut hybrid_router := hono.ContextHybridRouter.new()
	
	// 添加相同的路由
	route_path := '/api/:version/users/:user_id'
	test_path := '/api/v1/users/123'
	
	fast_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('fast')
		}
	}
	
	hybrid_handler := hono.ContextHandler{
		path: route_path
		handler: fn (mut c hono.Context) http.Response {
			return c.text('hybrid')
		}
	}
	
	fast_router.add_route('GET', fast_handler, '') or {
		println('  ❌ FastRouter添加路由失败')
		return
	}
	
	hybrid_router.add_route('GET', hybrid_handler, '')
	
	iterations := 1000
	
	// 测试FastRouter性能
	fast_router.clear_cache()
	start_time1 := time.now()
	mut fast_matches := 0
	for _ in 0 .. iterations {
		if _ := fast_router.match_route('GET', test_path) {
			fast_matches++
		}
	}
	fast_time := time.since(start_time1)
	
	// 测试HybridRouter性能
	hybrid_router.clear_cache()
	start_time2 := time.now()
	mut hybrid_matches := 0
	for _ in 0 .. iterations {
		if _ := hybrid_router.match_route('GET', test_path) {
			hybrid_matches++
		}
	}
	hybrid_time := time.since(start_time2)
	
	if fast_matches > 0 && hybrid_matches > 0 {
		fast_avg := f64(fast_time.microseconds()) / f64(fast_matches)
		hybrid_avg := f64(hybrid_time.microseconds()) / f64(hybrid_matches)
		
		println('  FastRouter平均: ${fast_avg:.3f}μs')
		println('  HybridRouter平均: ${hybrid_avg:.3f}μs')
		
		if fast_avg < hybrid_avg {
			improvement := hybrid_avg / fast_avg
			println('  ✅ FastRouter性能提升: ${improvement:.2f}x')
		} else {
			println('  ❌ FastRouter性能未提升')
		}
	}
}

fn test_config_system() {
	println('\n📊 配置系统测试...')
	
	// 测试默认配置创建
	config := hono.default_config()
	
	// 验证默认值
	if config.server.host == '127.0.0.1' && config.server.port == 8080 {
		println('  ✅ 配置创建正确')
	} else {
		println('  ❌ 配置创建错误')
	}
	
	// 测试配置字段
	if config.server.read_timeout == 30 && config.static.root_dir == './static' {
		println('  ✅ 配置字段正确')
	} else {
		println('  ❌ 配置字段错误')
	}
	
	// 测试配置环境
	if config.env == 'development' {
		println('  ✅ 默认环境正确')
	} else {
		println('  ❌ 默认环境错误')
	}
}