import meiseayoung.hono
import net.http

// Cookie Helper 功能测试
// 测试 Cookie 的 get/set/delete 和签名功能

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
	println('\n=== Cookie Helper 测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// 创建带 Cookie 头的测试 Context
fn create_test_context_with_cookies(cookie_header string) hono.Context {
	mut headers := http.new_header()
	if cookie_header.len > 0 {
		headers.add_custom('Cookie', cookie_header) or {}
	}
	
	req := http.Request{
		method: .get
		url: '/test'
		header: headers
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

// 创建空的测试 Context
fn create_empty_context() hono.Context {
	req := http.Request{
		method: .get
		url: '/test'
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}


// 测试 1: 获取单个 Cookie
fn test_get_single_cookie() bool {
	ctx := create_test_context_with_cookies('session_id=abc123')
	
	if value := hono.get_cookie(ctx, 'session_id') {
		return value == 'abc123'
	}
	return false
}

// 测试 2: 获取不存在的 Cookie 返回 none
fn test_get_nonexistent_cookie() bool {
	ctx := create_test_context_with_cookies('session_id=abc123')
	
	if _ := hono.get_cookie(ctx, 'nonexistent') {
		return false // 应该返回 none
	}
	return true
}

// 测试 3: 获取多个 Cookie
fn test_get_multiple_cookies() bool {
	ctx := create_test_context_with_cookies('session_id=abc123; user_id=456; theme=dark')
	
	session := hono.get_cookie(ctx, 'session_id') or { return false }
	user := hono.get_cookie(ctx, 'user_id') or { return false }
	theme := hono.get_cookie(ctx, 'theme') or { return false }
	
	return session == 'abc123' && user == '456' && theme == 'dark'
}

// 测试 4: 获取所有 Cookie
fn test_get_all_cookies() bool {
	ctx := create_test_context_with_cookies('a=1; b=2; c=3')
	
	cookies := hono.get_all_cookies(ctx)
	
	return cookies.len == 3 && 
		cookies['a'] == '1' && 
		cookies['b'] == '2' && 
		cookies['c'] == '3'
}

// 测试 5: 空 Cookie 头返回空 map
fn test_get_all_cookies_empty() bool {
	ctx := create_empty_context()
	
	cookies := hono.get_all_cookies(ctx)
	
	return cookies.len == 0
}

// 测试 6: 设置 Cookie
fn test_set_cookie_basic() bool {
	mut ctx := create_empty_context()
	
	hono.set_cookie(mut ctx, 'session', 'xyz789')
	
	// 检查 Set-Cookie 头是否被设置
	if set_cookie := ctx.headers['Set-Cookie'] {
		return set_cookie.contains('session=xyz789')
	}
	return false
}

// 测试 7: 设置 Cookie 带选项
fn test_set_cookie_with_options() bool {
	mut ctx := create_empty_context()
	
	hono.set_cookie(mut ctx, 'token', 'secret123', hono.CookieOptions{
		path: '/api'
		http_only: true
		secure: true
		max_age: 3600
		same_site: .strict
	})
	
	if set_cookie := ctx.headers['Set-Cookie'] {
		return set_cookie.contains('token=secret123') &&
			set_cookie.contains('Path=/api') &&
			set_cookie.contains('HttpOnly') &&
			set_cookie.contains('Secure') &&
			set_cookie.contains('Max-Age=3600') &&
			set_cookie.contains('SameSite=Strict')
	}
	return false
}


// 测试 8: 删除 Cookie
fn test_delete_cookie() bool {
	mut ctx := create_empty_context()
	
	hono.delete_cookie(mut ctx, 'session')
	
	if set_cookie := ctx.headers['Set-Cookie'] {
		// 删除 Cookie 应该设置 Max-Age=0 或过期时间
		return set_cookie.contains('session=') &&
			(set_cookie.contains('Max-Age=0') || set_cookie.contains('Expires='))
	}
	return false
}

// 测试 9: Cookie 值带空格
fn test_cookie_with_spaces() bool {
	ctx := create_test_context_with_cookies('name=John Doe')
	
	if value := hono.get_cookie(ctx, 'name') {
		return value == 'John Doe'
	}
	return false
}

// 测试 10: Cookie 值带引号
fn test_cookie_with_quotes() bool {
	ctx := create_test_context_with_cookies('data="hello world"')
	
	if value := hono.get_cookie(ctx, 'data') {
		return value == 'hello world'
	}
	return false
}

// 测试 11: 签名 Cookie 设置和获取
fn test_signed_cookie_roundtrip() bool {
	mut ctx := create_empty_context()
	secret := 'my-secret-key-12345'
	
	// 设置签名 Cookie
	hono.set_signed_cookie(mut ctx, 'auth', 'user123', secret) or {
		println('Failed to set signed cookie: ${err}')
		return false
	}
	
	// 获取 Set-Cookie 头中的值
	set_cookie_header := ctx.headers['Set-Cookie'] or { return false }
	
	// 提取 Cookie 值（格式: auth=value.signature; ...）
	mut cookie_value := ''
	parts := set_cookie_header.split(';')
	if parts.len > 0 {
		name_value := parts[0].trim_space()
		eq_pos := name_value.index('=') or { return false }
		cookie_value = name_value[eq_pos + 1..]
	}
	
	// 创建一个带有这个 Cookie 的新 Context 来验证
	verify_ctx := create_test_context_with_cookies('auth=${cookie_value}')
	
	// 验证签名 Cookie
	if value := hono.get_signed_cookie(verify_ctx, 'auth', secret) {
		return value == 'user123'
	} else {
		println('Failed to get signed cookie: ${err}')
		return false
	}
}

// 测试 12: 签名 Cookie 篡改检测
fn test_signed_cookie_tamper_detection() bool {
	mut ctx := create_empty_context()
	secret := 'my-secret-key-12345'
	
	// 设置签名 Cookie
	hono.set_signed_cookie(mut ctx, 'auth', 'user123', secret) or { return false }
	
	// 获取 Set-Cookie 头中的值
	set_cookie_header := ctx.headers['Set-Cookie'] or { return false }
	
	// 提取 Cookie 值
	mut cookie_value := ''
	parts := set_cookie_header.split(';')
	if parts.len > 0 {
		name_value := parts[0].trim_space()
		eq_pos := name_value.index('=') or { return false }
		cookie_value = name_value[eq_pos + 1..]
	}
	
	// 篡改 Cookie 值
	tampered_value := 'tampered' + cookie_value[8..] // 修改值部分
	
	// 创建带篡改 Cookie 的 Context
	verify_ctx := create_test_context_with_cookies('auth=${tampered_value}')
	
	// 验证应该失败
	if _ := hono.get_signed_cookie(verify_ctx, 'auth', secret) {
		return false // 不应该成功
	}
	return true // 验证失败是预期的
}

// 测试 13: 签名 Cookie 错误密钥
fn test_signed_cookie_wrong_secret() bool {
	mut ctx := create_empty_context()
	
	// 使用一个密钥设置
	hono.set_signed_cookie(mut ctx, 'auth', 'user123', 'secret1') or { return false }
	
	// 获取 Set-Cookie 头中的值
	set_cookie_header := ctx.headers['Set-Cookie'] or { return false }
	
	// 提取 Cookie 值
	mut cookie_value := ''
	parts := set_cookie_header.split(';')
	if parts.len > 0 {
		name_value := parts[0].trim_space()
		eq_pos := name_value.index('=') or { return false }
		cookie_value = name_value[eq_pos + 1..]
	}
	
	// 创建带 Cookie 的 Context
	verify_ctx := create_test_context_with_cookies('auth=${cookie_value}')
	
	// 使用不同的密钥验证应该失败
	if _ := hono.get_signed_cookie(verify_ctx, 'auth', 'secret2') {
		return false // 不应该成功
	}
	return true // 验证失败是预期的
}


// 测试 14: 空密钥应该返回错误
fn test_signed_cookie_empty_secret() bool {
	mut ctx := create_empty_context()
	
	// 空密钥应该返回错误
	if _ := hono.set_signed_cookie(mut ctx, 'auth', 'value', '') {
		return false // 不应该成功
	}
	return true
}

fn main() {
	println('🚀 开始 Cookie Helper 功能测试...\n')

	mut stats := TestStats{}

	// 运行所有测试
	stats.run_test('获取单个 Cookie', test_get_single_cookie)
	stats.run_test('获取不存在的 Cookie', test_get_nonexistent_cookie)
	stats.run_test('获取多个 Cookie', test_get_multiple_cookies)
	stats.run_test('获取所有 Cookie', test_get_all_cookies)
	stats.run_test('空 Cookie 头返回空 map', test_get_all_cookies_empty)
	stats.run_test('设置 Cookie 基本功能', test_set_cookie_basic)
	stats.run_test('设置 Cookie 带选项', test_set_cookie_with_options)
	stats.run_test('删除 Cookie', test_delete_cookie)
	stats.run_test('Cookie 值带空格', test_cookie_with_spaces)
	stats.run_test('Cookie 值带引号', test_cookie_with_quotes)
	stats.run_test('签名 Cookie 往返一致性', test_signed_cookie_roundtrip)
	stats.run_test('签名 Cookie 篡改检测', test_signed_cookie_tamper_detection)
	stats.run_test('签名 Cookie 错误密钥', test_signed_cookie_wrong_secret)
	stats.run_test('签名 Cookie 空密钥错误', test_signed_cookie_empty_secret)

	// 打印测试总结
	stats.print_summary()
}
