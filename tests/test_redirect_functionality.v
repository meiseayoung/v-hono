import hono
import net.http

// 重定向功能测试
fn redirect_basic_test() bool {
	mut c := hono.Context.new(
		http.Request{
			method: .get
			url: '/test'
		},
		map[string]string{},
		map[string]string{},
		''
	)
	
	response := c.redirect('https://example.com')
	
	if response.status_code != 302 {
		return false
	}
	
	location := response.header.get_custom('Location') or { '' }
	if location != 'https://example.com' {
		return false
	}
	
	if response.body != '' {
		return false
	}
	
	return true
}

fn redirect_with_status_test() bool {
	mut c := hono.Context.new(
		http.Request{
			method: .get
			url: '/test'
		},
		map[string]string{},
		map[string]string{},
		''
	)
	
	response := c.redirect('https://example.com', 301)
	
	if response.status_code != 301 {
		return false
	}
	
	location := response.header.get_custom('Location') or { '' }
	if location != 'https://example.com' {
		return false
	}
	
	if response.body != '' {
		return false
	}
	
	return true
}

fn redirect_multiple_status_codes_test() bool {
	status_codes := [301, 302, 303, 307, 308]
	
	for code in status_codes {
		mut c := hono.Context.new(
			http.Request{
				method: .get
				url: '/test'
			},
			map[string]string{},
			map[string]string{},
			''
		)
		
		response := c.redirect('https://example.com', code)
		
		if response.status_code != code {
			return false
		}
		
		location := response.header.get_custom('Location') or { '' }
		if location != 'https://example.com' {
			return false
		}
		
		if response.body != '' {
			return false
		}
	}
	
	return true
}

fn redirect_relative_url_test() bool {
	mut c := hono.Context.new(
		http.Request{
			method: .get
			url: '/test'
		},
		map[string]string{},
		map[string]string{},
		''
	)
	
	response := c.redirect('/relative-path')
	
	if response.status_code != 302 {
		return false
	}
	
	location := response.header.get_custom('Location') or { '' }
	if location != '/relative-path' {
		return false
	}
	
	return true
}

fn redirect_with_existing_headers_test() bool {
	mut c := hono.Context.new(
		http.Request{
			method: .get
			url: '/test'
		},
		map[string]string{},
		map[string]string{},
		''
	)
	
	// Set some existing headers
	c.headers['X-Custom-Header'] = 'custom-value'
	c.headers['Cache-Control'] = 'no-cache'
	
	response := c.redirect('https://example.com')
	
	if response.status_code != 302 {
		return false
	}
	
	location := response.header.get_custom('Location') or { '' }
	if location != 'https://example.com' {
		return false
	}
	
	custom_header := response.header.get_custom('X-Custom-Header') or { '' }
	if custom_header != 'custom-value' {
		return false
	}
	
	cache_control := response.header.get_custom('Cache-Control') or { '' }
	if cache_control != 'no-cache' {
		return false
	}
	
	return true
}

// 测试统计结构
struct TestStats {
mut:
	total_tests int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) run_test(test_name string, test_func fn() bool) {
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
	println('\n=== 重定向测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')
	
	if stats.failed_tests == 0 {
		println('🎉 所有重定向测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

fn main() {
	println('🚀 开始重定向功能测试...\n')
	
	mut stats := TestStats{}
	
	// 运行所有重定向测试
	stats.run_test('基本重定向 (302)', redirect_basic_test)
	stats.run_test('自定义状态码重定向 (301)', redirect_with_status_test)
	stats.run_test('多种状态码测试', redirect_multiple_status_codes_test)
	stats.run_test('相对路径重定向', redirect_relative_url_test)
	stats.run_test('保持现有头部信息', redirect_with_existing_headers_test)
	
	// 打印测试总结
	stats.print_summary()
}