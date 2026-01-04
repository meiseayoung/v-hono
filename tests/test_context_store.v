import meiseayoung.hono
import net.http

// Context Store 功能测试
// 测试 Context 的 store 字段和 get/set/get_client_ip 方法

struct TestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) run_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🧪 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats TestStats) print_summary() {
	println('\n=== Context Store 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// 创建测试用的 Context
fn create_test_context() hono.Context {
	req := http.Request{
		method: .get
		url: '/test'
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

// 测试 1: 基本的 set 和 get 操作
fn test_basic_set_get() bool {
	mut ctx := create_test_context()
	
	// 设置值
	ctx.set('user_id', '12345')
	ctx.set('role', 'admin')
	
	// 获取值
	if user_id := ctx.get('user_id') {
		if user_id != '12345' {
			return false
		}
	} else {
		return false
	}
	
	if role := ctx.get('role') {
		if role != 'admin' {
			return false
		}
	} else {
		return false
	}
	
	return true
}

// 测试 2: 获取不存在的 key 返回 none
fn test_get_nonexistent_key() bool {
	ctx := create_test_context()
	
	// 获取不存在的 key
	if _ := ctx.get('nonexistent') {
		return false // 应该返回 none
	}
	
	return true
}

// 测试 3: 覆盖已存在的值
fn test_overwrite_value() bool {
	mut ctx := create_test_context()
	
	// 设置初始值
	ctx.set('key', 'value1')
	
	// 覆盖值
	ctx.set('key', 'value2')
	
	// 验证新值
	if val := ctx.get('key') {
		return val == 'value2'
	}
	
	return false
}

// 测试 4: 空字符串值
fn test_empty_string_value() bool {
	mut ctx := create_test_context()
	
	// 设置空字符串
	ctx.set('empty', '')
	
	// 获取空字符串
	if val := ctx.get('empty') {
		return val == ''
	}
	
	return false
}

// 测试 5: 多个键值对
fn test_multiple_keys() bool {
	mut ctx := create_test_context()
	
	// 设置多个值
	for i in 0 .. 10 {
		ctx.set('key${i}', 'value${i}')
	}
	
	// 验证所有值
	for i in 0 .. 10 {
		if val := ctx.get('key${i}') {
			if val != 'value${i}' {
				return false
			}
		} else {
			return false
		}
	}
	
	return true
}

// 测试 6: get_client_ip 默认返回值
fn test_get_client_ip_default() bool {
	ctx := create_test_context()
	
	// 没有设置任何 IP 相关头时，应返回默认值
	ip := ctx.get_client_ip()
	return ip == '127.0.0.1'
}

// 测试 7: get_client_ip 从 X-Forwarded-For 获取
fn test_get_client_ip_forwarded_for() bool {
	mut headers := http.new_header()
	headers.add_custom('X-Forwarded-For', '192.168.1.100, 10.0.0.1') or { return false }
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	ctx := hono.Context.new(req, map[string]string{}, map[string]string{}, '')
	
	// 应该返回第一个 IP
	ip := ctx.get_client_ip()
	return ip == '192.168.1.100'
}

// 测试 8: get_client_ip 从 X-Real-IP 获取
fn test_get_client_ip_real_ip() bool {
	mut headers := http.new_header()
	headers.add_custom('X-Real-IP', '10.20.30.40') or { return false }
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	ctx := hono.Context.new(req, map[string]string{}, map[string]string{}, '')
	
	ip := ctx.get_client_ip()
	return ip == '10.20.30.40'
}

// 测试 9: X-Forwarded-For 优先于 X-Real-IP
fn test_get_client_ip_priority() bool {
	mut headers := http.new_header()
	headers.add_custom('X-Forwarded-For', '1.2.3.4') or { return false }
	headers.add_custom('X-Real-IP', '5.6.7.8') or { return false }
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	ctx := hono.Context.new(req, map[string]string{}, map[string]string{}, '')
	
	// X-Forwarded-For 应该优先
	ip := ctx.get_client_ip()
	return ip == '1.2.3.4'
}

// 测试 10: store 初始化为空
fn test_store_initialized_empty() bool {
	ctx := create_test_context()
	
	// 新创建的 Context 的 store 应该为空
	// 尝试获取任何 key 都应该返回 none
	if _ := ctx.get('any_key') {
		return false
	}
	
	return true
}

fn main() {
	println('🚀 开始 Context Store 功能测试...\n')

	mut stats := TestStats{}

	// 运行所有测试
	stats.run_test('基本 set/get 操作', test_basic_set_get)
	stats.run_test('获取不存在的 key', test_get_nonexistent_key)
	stats.run_test('覆盖已存在的值', test_overwrite_value)
	stats.run_test('空字符串值', test_empty_string_value)
	stats.run_test('多个键值对', test_multiple_keys)
	stats.run_test('get_client_ip 默认值', test_get_client_ip_default)
	stats.run_test('get_client_ip X-Forwarded-For', test_get_client_ip_forwarded_for)
	stats.run_test('get_client_ip X-Real-IP', test_get_client_ip_real_ip)
	stats.run_test('X-Forwarded-For 优先级', test_get_client_ip_priority)
	stats.run_test('store 初始化为空', test_store_initialized_empty)

	// 打印测试总结
	stats.print_summary()
}
