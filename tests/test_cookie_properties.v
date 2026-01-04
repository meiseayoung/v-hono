import meiseayoung.hono
import net.http
import rand
import time

// Cookie Helper 属性测试
// Property-Based Testing for Cookie functionality

const test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats PropertyTestStats) run_property_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🔬 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== Cookie Helper 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// 创建带 Cookie 头的测试 Context
fn create_context_with_cookies(cookie_header string) hono.Context {
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


// 生成随机的 Cookie 名称（只包含有效字符）
fn generate_random_cookie_name() string {
	valid_chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
	len := rand.int_in_range(1, 20) or { 5 }
	mut name := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, valid_chars.len) or { 0 }
		name += valid_chars[idx].ascii_str()
	}
	return name
}

// 生成随机的 Cookie 值（不包含分号和等号）
fn generate_random_cookie_value() string {
	// 使用安全的字符集，避免特殊字符
	valid_chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.'
	len := rand.int_in_range(1, 50) or { 10 }
	mut value := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, valid_chars.len) or { 0 }
		value += valid_chars[idx].ascii_str()
	}
	return value
}

// 生成随机的密钥
fn generate_random_secret() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
	len := rand.int_in_range(16, 64) or { 32 }
	mut secret := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		secret += chars[idx].ascii_str()
	}
	return secret
}

// ============================================================================
// Property 3: Cookie Round-Trip Consistency
// Feature: builtin-middleware, Property 3: Cookie Round-Trip Consistency
// Validates: Requirements 2.1, 2.3
// 
// *For any* cookie name and value, calling set_cookie followed by get_cookie 
// on the same name SHALL return the original value.
// ============================================================================
fn test_property_3_cookie_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		name := generate_random_cookie_name()
		value := generate_random_cookie_value()
		
		// 设置 Cookie
		mut ctx := create_empty_context()
		hono.set_cookie(mut ctx, name, value)
		
		// 获取 Set-Cookie 头中的值
		set_cookie_header := ctx.headers['Set-Cookie'] or {
			println('  Iteration ${i}: Failed to get Set-Cookie header')
			return false
		}
		
		// 提取 Cookie 值
		mut cookie_value := ''
		parts := set_cookie_header.split(';')
		if parts.len > 0 {
			name_value := parts[0].trim_space()
			eq_pos := name_value.index('=') or {
				println('  Iteration ${i}: Invalid cookie format')
				return false
			}
			cookie_value = name_value[eq_pos + 1..]
		}
		
		// 创建带 Cookie 的 Context 来验证
		verify_ctx := create_context_with_cookies('${name}=${cookie_value}')
		
		// 获取 Cookie 并验证
		retrieved := hono.get_cookie(verify_ctx, name) or {
			println('  Iteration ${i}: Failed to get cookie')
			return false
		}
		
		if retrieved != value {
			println('  Iteration ${i}: Value mismatch - expected "${value}", got "${retrieved}"')
			return false
		}
	}
	
	return true
}


// ============================================================================
// Property 4: Signed Cookie Round-Trip
// Feature: builtin-middleware, Property 4: Signed Cookie Round-Trip
// Validates: Requirements 2.7, 2.8
// 
// *For any* cookie name, value, and secret, calling set_signed_cookie followed 
// by get_signed_cookie with the same secret SHALL return the original value.
// ============================================================================
fn test_property_4_signed_cookie_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		name := generate_random_cookie_name()
		value := generate_random_cookie_value()
		secret := generate_random_secret()
		
		// 设置签名 Cookie
		mut ctx := create_empty_context()
		hono.set_signed_cookie(mut ctx, name, value, secret) or {
			println('  Iteration ${i}: Failed to set signed cookie: ${err}')
			return false
		}
		
		// 获取 Set-Cookie 头中的值
		set_cookie_header := ctx.headers['Set-Cookie'] or {
			println('  Iteration ${i}: Failed to get Set-Cookie header')
			return false
		}
		
		// 提取 Cookie 值（包含签名）
		mut cookie_value := ''
		parts := set_cookie_header.split(';')
		if parts.len > 0 {
			name_value := parts[0].trim_space()
			eq_pos := name_value.index('=') or {
				println('  Iteration ${i}: Invalid cookie format')
				return false
			}
			cookie_value = name_value[eq_pos + 1..]
		}
		
		// 创建带签名 Cookie 的 Context 来验证
		verify_ctx := create_context_with_cookies('${name}=${cookie_value}')
		
		// 获取并验证签名 Cookie
		retrieved := hono.get_signed_cookie(verify_ctx, name, secret) or {
			println('  Iteration ${i}: Failed to get signed cookie: ${err}')
			return false
		}
		
		if retrieved != value {
			println('  Iteration ${i}: Value mismatch - expected "${value}", got "${retrieved}"')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 5: Signed Cookie Tamper Detection
// Feature: builtin-middleware, Property 5: Signed Cookie Tamper Detection
// Validates: Requirements 2.9
// 
// *For any* signed cookie, modifying the cookie value or signature SHALL cause 
// get_signed_cookie to return an error.
// ============================================================================
fn test_property_5_signed_cookie_tamper_detection() bool {
	rand.seed([u32(time.now().unix()), u32(98765)])
	
	for i in 0 .. test_iterations {
		name := generate_random_cookie_name()
		value := generate_random_cookie_value()
		secret := generate_random_secret()
		
		// 设置签名 Cookie
		mut ctx := create_empty_context()
		hono.set_signed_cookie(mut ctx, name, value, secret) or {
			println('  Iteration ${i}: Failed to set signed cookie: ${err}')
			return false
		}
		
		// 获取 Set-Cookie 头中的值
		set_cookie_header := ctx.headers['Set-Cookie'] or {
			println('  Iteration ${i}: Failed to get Set-Cookie header')
			return false
		}
		
		// 提取 Cookie 值（包含签名）
		mut cookie_value := ''
		parts := set_cookie_header.split(';')
		if parts.len > 0 {
			name_value := parts[0].trim_space()
			eq_pos := name_value.index('=') or {
				println('  Iteration ${i}: Invalid cookie format')
				return false
			}
			cookie_value = name_value[eq_pos + 1..]
		}
		
		// 篡改 Cookie 值（修改第一个字符）
		if cookie_value.len > 1 {
			// 找到签名分隔符
			dot_pos := cookie_value.last_index('.') or {
				println('  Iteration ${i}: No signature separator found')
				return false
			}
			
			// 篡改值部分
			original_value_part := cookie_value[..dot_pos]
			signature_part := cookie_value[dot_pos..]
			
			// 修改值的第一个字符
			mut tampered_value := ''
			if original_value_part.len > 0 {
				first_char := original_value_part[0]
				new_char := if first_char == `a` { 'b' } else { 'a' }
				tampered_value = new_char + original_value_part[1..] + signature_part
			} else {
				tampered_value = 'x' + signature_part
			}
			
			// 创建带篡改 Cookie 的 Context
			verify_ctx := create_context_with_cookies('${name}=${tampered_value}')
			
			// 验证应该失败
			if _ := hono.get_signed_cookie(verify_ctx, name, secret) {
				println('  Iteration ${i}: Tampered cookie was accepted (should have been rejected)')
				return false
			}
		}
	}
	
	return true
}


fn main() {
	println('🚀 开始 Cookie Helper 属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// 运行属性测试
	// Feature: builtin-middleware, Property 3: Cookie Round-Trip Consistency
	// Validates: Requirements 2.1, 2.3
	stats.run_property_test('Property 3: Cookie Round-Trip Consistency', test_property_3_cookie_roundtrip)
	
	// Feature: builtin-middleware, Property 4: Signed Cookie Round-Trip
	// Validates: Requirements 2.7, 2.8
	stats.run_property_test('Property 4: Signed Cookie Round-Trip', test_property_4_signed_cookie_roundtrip)
	
	// Feature: builtin-middleware, Property 5: Signed Cookie Tamper Detection
	// Validates: Requirements 2.9
	stats.run_property_test('Property 5: Signed Cookie Tamper Detection', test_property_5_signed_cookie_tamper_detection)

	// 打印测试总结
	stats.print_summary()
}
