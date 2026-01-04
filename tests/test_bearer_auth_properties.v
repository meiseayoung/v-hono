import meiseayoung.hono
import net.http
import rand
import time

// Bearer Auth Middleware 属性测试
// Property-Based Testing for Bearer Auth functionality

const test_iterations = 100

struct BearerAuthTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats BearerAuthTestStats) run_property_test(test_name string, test_func fn () bool) {
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

fn (stats BearerAuthTestStats) print_summary() {
	println('\n=== Bearer Auth Middleware 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// 生成随机的 token
fn generate_random_token() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(16, 64) or { 32 }
	mut token := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		token += chars[idx].ascii_str()
	}
	return token
}

// 生成随机的 realm
fn generate_random_realm() string {
	realms := ['api', 'admin', 'user', 'protected', 'secure', 'private']
	idx := rand.int_in_range(0, realms.len) or { 0 }
	return realms[idx]
}

// 生成随机的 prefix
fn generate_random_prefix() string {
	prefixes := ['Bearer', 'Token', 'ApiKey', 'Auth']
	idx := rand.int_in_range(0, prefixes.len) or { 0 }
	return prefixes[idx]
}

// 创建带 Authorization 头的测试 Context
fn create_bearer_context_with_auth(auth_header string) hono.Context {
	mut headers := http.new_header()
	if auth_header.len > 0 {
		headers.add_custom('Authorization', auth_header) or {}
	}

	req := http.Request{
		method: .get
		url: '/api/protected'
		header: headers
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

// 创建带自定义 header 的测试 Context
fn create_bearer_context_with_custom_header(header_name string, header_value string) hono.Context {
	mut headers := http.new_header()
	if header_value.len > 0 {
		headers.add_custom(header_name, header_value) or {}
	}

	req := http.Request{
		method: .get
		url: '/api/protected'
		header: headers
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

// 模拟 next 函数，返回一个简单的响应
fn bearer_mock_next(mut c hono.Context) http.Response {
	c.status(200)
	return c.text('OK')
}


// ============================================================================
// Property 9: Bearer Token Validation
// Feature: builtin-middleware, Property 9: Bearer Token Validation
// Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10
//
// *For any* configured token(s), only requests with matching Bearer token in
// Authorization header SHALL be allowed to proceed.
// ============================================================================
fn test_property_9_bearer_token_validation() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])

	// Test 1: Valid single token should be allowed
	for _ in 0 .. test_iterations / 5 {
		valid_token := generate_random_token()
		auth_header := 'Bearer ${valid_token}'

		mut ctx := create_bearer_context_with_auth(auth_header)

		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: valid_token
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 200 {
			println('  Single token test failed: valid token rejected, status ${response.status_code}')
			return false
		}

		// Verify token is stored in context
		stored_token := ctx.get('bearer_token') or { '' }
		if stored_token != valid_token {
			println('  Single token test failed: token not stored in context')
			return false
		}
	}

	// Test 2: Invalid single token should be rejected
	for _ in 0 .. test_iterations / 5 {
		valid_token := generate_random_token()
		invalid_token := generate_random_token()

		// Ensure tokens are different
		if valid_token == invalid_token {
			continue
		}

		auth_header := 'Bearer ${invalid_token}'

		mut ctx := create_bearer_context_with_auth(auth_header)

		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: valid_token
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 401 {
			println('  Invalid token test failed: invalid token accepted, status ${response.status_code}')
			return false
		}

		// Verify WWW-Authenticate header is set
		www_auth := response.header.get_custom('WWW-Authenticate') or { '' }
		if !www_auth.starts_with('Bearer') {
			println('  Invalid token test failed: WWW-Authenticate header not set correctly')
			return false
		}
	}

	// Test 3: Multiple tokens - any valid token should be allowed
	for _ in 0 .. test_iterations / 5 {
		tokens := [generate_random_token(), generate_random_token(), generate_random_token()]

		// Pick a random valid token
		valid_idx := rand.int_in_range(0, tokens.len) or { 0 }
		auth_header := 'Bearer ${tokens[valid_idx]}'

		mut ctx := create_bearer_context_with_auth(auth_header)

		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: tokens
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 200 {
			println('  Multiple tokens test failed: valid token rejected, status ${response.status_code}')
			return false
		}
	}

	// Test 4: Missing Authorization header should be rejected
	for _ in 0 .. test_iterations / 5 {
		valid_token := generate_random_token()

		mut ctx := create_bearer_context_with_auth('')

		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: valid_token
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 401 {
			println('  Missing header test failed: request without auth accepted, status ${response.status_code}')
			return false
		}

		// Verify WWW-Authenticate header is set
		www_auth := response.header.get_custom('WWW-Authenticate') or { '' }
		if !www_auth.starts_with('Bearer') {
			println('  Missing header test failed: WWW-Authenticate header not set')
			return false
		}
	}

	// Test 5: Custom prefix should work correctly
	for _ in 0 .. test_iterations / 5 {
		valid_token := generate_random_token()
		custom_prefix := generate_random_prefix()
		auth_header := '${custom_prefix} ${valid_token}'

		mut ctx := create_bearer_context_with_auth(auth_header)

		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: valid_token
			prefix: custom_prefix
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 200 {
			println('  Custom prefix test failed: valid token with custom prefix rejected')
			return false
		}
	}

	return true
}

// Test custom verify_token callback
fn test_property_9_custom_verify_callback() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])

	for _ in 0 .. test_iterations / 2 {
		// Generate a token that starts with "valid_"
		valid_token := 'valid_${generate_random_token()}'
		auth_header := 'Bearer ${valid_token}'

		mut ctx := create_bearer_context_with_auth(auth_header)

		// Custom verify function that only accepts tokens starting with "valid_"
		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: ''
			verify_token: fn (token string, c hono.Context) bool {
				return token.starts_with('valid_')
			}
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 200 {
			println('  Custom verify callback test failed: valid token rejected')
			return false
		}
	}

	for _ in 0 .. test_iterations / 2 {
		// Generate a token that does NOT start with "valid_"
		invalid_token := 'invalid_${generate_random_token()}'
		auth_header := 'Bearer ${invalid_token}'

		mut ctx := create_bearer_context_with_auth(auth_header)

		// Custom verify function that only accepts tokens starting with "valid_"
		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: ''
			verify_token: fn (token string, c hono.Context) bool {
				return token.starts_with('valid_')
			}
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 401 {
			println('  Custom verify callback test failed: invalid token accepted')
			return false
		}
	}

	return true
}

// Test realm configuration
fn test_property_9_realm_configuration() bool {
	rand.seed([u32(time.now().unix()), u32(98765)])

	for _ in 0 .. test_iterations {
		valid_token := generate_random_token()
		invalid_token := generate_random_token()
		realm := generate_random_realm()

		// Ensure tokens are different
		if valid_token == invalid_token {
			continue
		}

		auth_header := 'Bearer ${invalid_token}'

		mut ctx := create_bearer_context_with_auth(auth_header)

		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: valid_token
			realm: realm
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 401 {
			println('  Realm test failed: invalid token accepted')
			return false
		}

		// Verify WWW-Authenticate header includes realm
		www_auth := response.header.get_custom('WWW-Authenticate') or { '' }
		expected_www_auth := 'Bearer realm="${realm}"'
		if www_auth != expected_www_auth {
			println('  Realm test failed: expected "${expected_www_auth}", got "${www_auth}"')
			return false
		}
	}

	return true
}

// Test custom header name
fn test_property_9_custom_header_name() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])

	custom_headers := ['X-API-Key', 'X-Auth-Token', 'X-Access-Token']

	for _ in 0 .. test_iterations {
		valid_token := generate_random_token()
		header_idx := rand.int_in_range(0, custom_headers.len) or { 0 }
		custom_header := custom_headers[header_idx]
		header_value := 'Bearer ${valid_token}'

		mut ctx := create_bearer_context_with_custom_header(custom_header, header_value)

		bearer_mw := hono.bearer_auth(hono.BearerAuthOptions{
			token: valid_token
			header_name: custom_header
		})
		response := bearer_mw(mut ctx, bearer_mock_next)

		if response.status_code != 200 {
			println('  Custom header name test failed: valid token rejected with custom header "${custom_header}"')
			return false
		}
	}

	return true
}

fn main() {
	println('🚀 开始 Bearer Auth Middleware 属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := BearerAuthTestStats{}

	// 运行属性测试
	// Feature: builtin-middleware, Property 9: Bearer Token Validation
	// Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10
	stats.run_property_test('Property 9: Bearer Token Validation', test_property_9_bearer_token_validation)
	stats.run_property_test('Property 9: Custom Verify Callback', test_property_9_custom_verify_callback)
	stats.run_property_test('Property 9: Realm Configuration', test_property_9_realm_configuration)
	stats.run_property_test('Property 9: Custom Header Name', test_property_9_custom_header_name)

	// 打印测试总结
	stats.print_summary()
}
