import meiseayoung.hono
import net.http
import rand
import time

// CORS Middleware 属性测试
// Property-Based Testing for CORS functionality

const test_iterations = 100

struct CorsTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats CorsTestStats) run_property_test(test_name string, test_func fn () bool) {
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

fn (stats CorsTestStats) print_summary() {
	println('\n=== CORS Middleware 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// 创建带 Origin 头的测试 Context
fn create_cors_context_with_origin(origin string, method http.Method) hono.Context {
	mut headers := http.new_header()
	if origin.len > 0 {
		headers.add_custom('Origin', origin) or {}
	}
	
	req := http.Request{
		method: method
		url: '/test'
		header: headers
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

// 创建带 Origin 和 Access-Control-Request-Headers 的预检请求 Context
fn create_cors_preflight_context(origin string, request_headers string) hono.Context {
	mut headers := http.new_header()
	if origin.len > 0 {
		headers.add_custom('Origin', origin) or {}
	}
	if request_headers.len > 0 {
		headers.add_custom('Access-Control-Request-Headers', request_headers) or {}
	}
	
	req := http.Request{
		method: .options
		url: '/test'
		header: headers
	}
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}

// 生成随机的域名
fn generate_cors_random_origin() string {
	protocols := ['http', 'https']
	domains := ['example', 'test', 'api', 'app', 'web', 'service', 'backend', 'frontend']
	tlds := ['com', 'org', 'net', 'io', 'dev', 'app']
	
	protocol := protocols[rand.int_in_range(0, protocols.len) or { 0 }]
	domain := domains[rand.int_in_range(0, domains.len) or { 0 }]
	tld := tlds[rand.int_in_range(0, tlds.len) or { 0 }]
	
	// 有时添加端口
	port := if rand.int_in_range(0, 3) or { 0 } == 0 {
		':${rand.int_in_range(3000, 9000) or { 8080 }}'
	} else {
		''
	}
	
	return '${protocol}://${domain}.${tld}${port}'
}

// 生成随机的 HTTP 方法
fn generate_cors_random_method() http.Method {
	methods := [http.Method.get, http.Method.post, http.Method.put, http.Method.delete, http.Method.patch]
	return methods[rand.int_in_range(0, methods.len) or { 0 }]
}

// 生成随机的请求头列表
fn generate_cors_random_headers() []string {
	all_headers := ['Content-Type', 'Authorization', 'X-Custom-Header', 'X-Request-ID', 'Accept', 'Cache-Control']
	count := rand.int_in_range(1, all_headers.len) or { 2 }
	mut result := []string{}
	for i in 0 .. count {
		result << all_headers[i]
	}
	return result
}

// 模拟 next 函数，返回一个简单的响应
fn cors_mock_next(mut c hono.Context) http.Response {
	return c.text('OK')
}

// ============================================================================
// Property 1: CORS Origin Header Consistency
// Feature: builtin-middleware, Property 1: CORS Origin Header Consistency
// Validates: Requirements 1.1, 1.3, 1.4, 1.5, 1.6
// 
// *For any* request with an Origin header and any CORS configuration, the 
// Access-Control-Allow-Origin response header SHALL match the configured 
// origin policy (wildcard "*", specific domain, or callback result).
// ============================================================================
fn test_property_1_cors_origin_header_consistency() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	// Test 1: Wildcard origin ("*") should allow all origins
	for _ in 0 .. test_iterations / 4 {
		origin := generate_cors_random_origin()
		mut ctx := create_cors_context_with_origin(origin, generate_cors_random_method())
		
		cors_mw := hono.cors()
		_ := cors_mw(mut ctx, cors_mock_next)
		
		allowed_origin := ctx.headers['Access-Control-Allow-Origin'] or { '' }
		if allowed_origin != '*' {
			println('  Wildcard test failed: expected "*", got "${allowed_origin}"')
			return false
		}
	}
	
	// Test 2: Specific domain should only allow that domain
	for _ in 0 .. test_iterations / 4 {
		allowed_domain := generate_cors_random_origin()
		request_origin := generate_cors_random_origin()
		
		mut ctx := create_cors_context_with_origin(request_origin, generate_cors_random_method())
		
		cors_mw := hono.cors(hono.CorsOptions{
			origin: allowed_domain
		})
		_ := cors_mw(mut ctx, cors_mock_next)
		
		result_origin := ctx.headers['Access-Control-Allow-Origin'] or { '' }
		
		if request_origin == allowed_domain {
			// Should be allowed
			if result_origin != request_origin {
				println('  Specific domain test failed: expected "${request_origin}", got "${result_origin}"')
				return false
			}
		} else {
			// Should not be allowed (no header set)
			if result_origin != '' {
				println('  Specific domain test failed: expected empty, got "${result_origin}"')
				return false
			}
		}
	}
	
	// Test 3: Array of domains should allow any domain in the array
	for _ in 0 .. test_iterations / 4 {
		allowed_domains := [generate_cors_random_origin(), generate_cors_random_origin(), generate_cors_random_origin()]
		
		// Test with an allowed domain
		allowed_idx := rand.int_in_range(0, allowed_domains.len) or { 0 }
		request_origin := allowed_domains[allowed_idx]
		
		mut ctx := create_cors_context_with_origin(request_origin, generate_cors_random_method())
		
		cors_mw := hono.cors(hono.CorsOptions{
			origin: allowed_domains
		})
		_ := cors_mw(mut ctx, cors_mock_next)
		
		result_origin := ctx.headers['Access-Control-Allow-Origin'] or { '' }
		if result_origin != request_origin {
			println('  Array domain test failed: expected "${request_origin}", got "${result_origin}"')
			return false
		}
	}
	
	// Test 4: Callback function should use callback result
	for _ in 0 .. test_iterations / 4 {
		request_origin := generate_cors_random_origin()
		
		mut ctx := create_cors_context_with_origin(request_origin, generate_cors_random_method())
		
		// Callback that returns the origin if it starts with "https"
		cors_mw := hono.cors(hono.CorsOptions{
			origin: fn (origin string, c hono.Context) string {
				if origin.starts_with('https') {
					return origin
				}
				return ''
			}
		})
		_ := cors_mw(mut ctx, cors_mock_next)
		
		result_origin := ctx.headers['Access-Control-Allow-Origin'] or { '' }
		
		if request_origin.starts_with('https') {
			if result_origin != request_origin {
				println('  Callback test failed: expected "${request_origin}", got "${result_origin}"')
				return false
			}
		} else {
			if result_origin != '' {
				println('  Callback test failed: expected empty for non-https, got "${result_origin}"')
				return false
			}
		}
	}
	
	return true
}

// ============================================================================
// Property 2: CORS Preflight Response
// Feature: builtin-middleware, Property 2: CORS Preflight Response
// Validates: Requirements 1.2, 1.7, 1.8, 1.9, 1.10, 1.11
// 
// *For any* OPTIONS preflight request with Origin header, the CORS middleware 
// SHALL return status 204 with all configured CORS headers (Allow-Methods, 
// Allow-Headers, Expose-Headers, Max-Age, Credentials).
// ============================================================================
fn test_property_2_cors_preflight_response() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for _ in 0 .. test_iterations {
		origin := generate_cors_random_origin()
		allow_methods := ['GET', 'POST', 'PUT', 'DELETE']
		allow_headers := generate_cors_random_headers()
		expose_headers := ['X-Custom-Response', 'X-Request-ID']
		max_age := rand.int_in_range(60, 86400) or { 3600 }
		credentials := rand.int_in_range(0, 2) or { 0 } == 1
		
		mut ctx := create_cors_preflight_context(origin, allow_headers.join(', '))
		
		cors_mw := hono.cors(hono.CorsOptions{
			origin: '*'
			allow_methods: allow_methods
			allow_headers: allow_headers
			expose_headers: expose_headers
			max_age: max_age
			credentials: credentials
		})
		
		response := cors_mw(mut ctx, cors_mock_next)
		
		// Check status code is 204
		if response.status_code != 204 {
			println('  Preflight status test failed: expected 204, got ${response.status_code}')
			return false
		}
		
		// Check Access-Control-Allow-Origin
		allowed_origin := ctx.headers['Access-Control-Allow-Origin'] or { '' }
		if allowed_origin != '*' {
			println('  Preflight origin test failed: expected "*", got "${allowed_origin}"')
			return false
		}
		
		// Check Access-Control-Allow-Methods
		allowed_methods := ctx.headers['Access-Control-Allow-Methods'] or { '' }
		if allowed_methods != allow_methods.join(', ') {
			println('  Preflight methods test failed: expected "${allow_methods.join(', ')}", got "${allowed_methods}"')
			return false
		}
		
		// Check Access-Control-Allow-Headers
		result_headers := ctx.headers['Access-Control-Allow-Headers'] or { '' }
		if result_headers != allow_headers.join(', ') {
			println('  Preflight headers test failed: expected "${allow_headers.join(', ')}", got "${result_headers}"')
			return false
		}
		
		// Check Access-Control-Expose-Headers
		result_expose := ctx.headers['Access-Control-Expose-Headers'] or { '' }
		if result_expose != expose_headers.join(', ') {
			println('  Preflight expose headers test failed: expected "${expose_headers.join(', ')}", got "${result_expose}"')
			return false
		}
		
		// Check Access-Control-Max-Age
		result_max_age := ctx.headers['Access-Control-Max-Age'] or { '' }
		if result_max_age != max_age.str() {
			println('  Preflight max-age test failed: expected "${max_age}", got "${result_max_age}"')
			return false
		}
		
		// Check Access-Control-Allow-Credentials
		result_credentials := ctx.headers['Access-Control-Allow-Credentials'] or { '' }
		if credentials {
			if result_credentials != 'true' {
				println('  Preflight credentials test failed: expected "true", got "${result_credentials}"')
				return false
			}
		} else {
			if result_credentials != '' {
				println('  Preflight credentials test failed: expected empty, got "${result_credentials}"')
				return false
			}
		}
	}
	
	return true
}

fn main() {
	println('🚀 开始 CORS Middleware 属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := CorsTestStats{}

	// 运行属性测试
	// Feature: builtin-middleware, Property 1: CORS Origin Header Consistency
	// Validates: Requirements 1.1, 1.3, 1.4, 1.5, 1.6
	stats.run_property_test('Property 1: CORS Origin Header Consistency', test_property_1_cors_origin_header_consistency)
	
	// Feature: builtin-middleware, Property 2: CORS Preflight Response
	// Validates: Requirements 1.2, 1.7, 1.8, 1.9, 1.10, 1.11
	stats.run_property_test('Property 2: CORS Preflight Response', test_property_2_cors_preflight_response)

	// 打印测试总结
	stats.print_summary()
}
