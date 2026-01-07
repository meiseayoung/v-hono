// test_swagger_ui_options_property.v - Property-Based Test for Swagger UI Options
// **Feature: swagger-ui, Property 2: Swagger UI Options Appear in Generated HTML**
// **Validates: Requirements 1.5, 4.2, 4.3, 4.5**
//
// Property: For any SwaggerUIOptions configuration, all non-default option values 
// SHALL appear in the generated HTML output in the appropriate locations 
// (title in <title> tag, url in SwaggerUIBundle config, etc.).
module main

import hono
import rand
import time

const property_test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests     int
	passed_tests    int
	failed_tests    int
	failed_examples []string
}

fn (mut stats PropertyTestStats) record_pass() {
	stats.total_tests++
	stats.passed_tests++
}

fn (mut stats PropertyTestStats) record_fail(example string) {
	stats.total_tests++
	stats.failed_tests++
	stats.failed_examples << example
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== Property Test Summary ===')
	println('Total iterations: ${stats.total_tests}')
	println('Passed: ${stats.passed_tests}')
	println('Failed: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 Property test PASSED!')
	} else {
		println('❌ Property test FAILED!')
		println('\nFailing examples:')
		for i, example in stats.failed_examples {
			if i >= 3 {
				println('... and ${stats.failed_examples.len - 3} more')
				break
			}
			println('  ${example}')
		}
	}
}

// Random string generator for safe HTML content
fn random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(min_len, max_len + 1) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx..idx + 1]
	}
	return result
}

// Random URL path generator
fn random_url_path() string {
	return '/' + random_string(3, 10)
}

// Random doc expansion value
fn random_doc_expansion() string {
	values := ['list', 'full', 'none']
	idx := rand.int_in_range(0, values.len) or { 0 }
	return values[idx]
}

// Random integer in range
fn random_int(min int, max int) int {
	return rand.int_in_range(min, max + 1) or { min }
}

// Generate random SwaggerUIOptions
fn generate_random_options() hono.SwaggerUIOptions {
	return hono.SwaggerUIOptions{
		url:                         random_url_path()
		title:                       random_string(5, 20)
		deep_linking:                rand.int_in_range(0, 2) or { 0 } == 1
		display_request_duration:    rand.int_in_range(0, 2) or { 0 } == 1
		default_models_expand_depth: random_int(-1, 5)
		doc_expansion:               random_doc_expansion()
		filter:                      rand.int_in_range(0, 2) or { 0 } == 1
		show_extensions:             rand.int_in_range(0, 2) or { 0 } == 1
		show_common_extensions:      rand.int_in_range(0, 2) or { 0 } == 1
		try_it_out_enabled:          rand.int_in_range(0, 2) or { 0 } == 1
	}
}

// Test: Title appears in HTML <title> tag
fn test_title_in_html(options hono.SwaggerUIOptions, html string) bool {
	expected := '<title>${options.title}</title>'
	return html.contains(expected)
}

// Test: URL appears in SwaggerUIBundle config
fn test_url_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected := 'url: "${options.url}"'
	return html.contains(expected)
}

// Test: deepLinking option appears correctly
fn test_deep_linking_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected_value := if options.deep_linking { 'true' } else { 'false' }
	expected := 'deepLinking: ${expected_value}'
	return html.contains(expected)
}

// Test: displayRequestDuration option appears correctly
fn test_display_request_duration_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected_value := if options.display_request_duration { 'true' } else { 'false' }
	expected := 'displayRequestDuration: ${expected_value}'
	return html.contains(expected)
}

// Test: defaultModelsExpandDepth option appears correctly
fn test_default_models_expand_depth_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected := 'defaultModelsExpandDepth: ${options.default_models_expand_depth}'
	return html.contains(expected)
}

// Test: docExpansion option appears correctly
fn test_doc_expansion_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected := 'docExpansion: "${options.doc_expansion}"'
	return html.contains(expected)
}

// Test: filter option appears correctly
fn test_filter_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected_value := if options.filter { 'true' } else { 'false' }
	expected := 'filter: ${expected_value}'
	return html.contains(expected)
}

// Test: showExtensions option appears correctly
fn test_show_extensions_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected_value := if options.show_extensions { 'true' } else { 'false' }
	expected := 'showExtensions: ${expected_value}'
	return html.contains(expected)
}

// Test: showCommonExtensions option appears correctly
fn test_show_common_extensions_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected_value := if options.show_common_extensions { 'true' } else { 'false' }
	expected := 'showCommonExtensions: ${expected_value}'
	return html.contains(expected)
}

// Test: tryItOutEnabled option appears correctly
fn test_try_it_out_enabled_in_config(options hono.SwaggerUIOptions, html string) bool {
	expected_value := if options.try_it_out_enabled { 'true' } else { 'false' }
	expected := 'tryItOutEnabled: ${expected_value}'
	return html.contains(expected)
}

// Test: HTML is valid HTML5 document
fn test_valid_html5_document(html string) bool {
	has_doctype := html.contains('<!DOCTYPE html>')
	has_html_tag := html.contains('<html') && html.contains('</html>')
	has_head := html.contains('<head>') && html.contains('</head>')
	has_body := html.contains('<body>') && html.contains('</body>')
	has_charset := html.contains('charset="UTF-8"') || html.contains("charset='UTF-8'")
	return has_doctype && has_html_tag && has_head && has_body && has_charset
}

// Test: Swagger UI CDN resources are included
fn test_cdn_resources_included(html string) bool {
	has_css := html.contains('https://unpkg.com/swagger-ui-dist@5/swagger-ui.css')
	has_bundle_js := html.contains('https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js')
	has_standalone_js := html.contains('https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js')
	return has_css && has_bundle_js && has_standalone_js
}

// Test: Custom CSS URL appears when provided
fn test_custom_css_url_included() bool {
	custom_url := 'https://example.com/custom.css'
	options := hono.SwaggerUIOptions{
		url:            '/doc'
		title:          'Test API'
		custom_css_url: custom_url
	}

	handler := hono.swagger_ui(options)
	mut ctx := hono.Context{}
	response := handler(mut ctx)
	html := response.body

	return html.contains('href="${custom_url}"')
}

// Test: Custom JS URL appears when provided
fn test_custom_js_url_included() bool {
	custom_url := 'https://example.com/custom.js'
	options := hono.SwaggerUIOptions{
		url:           '/doc'
		title:         'Test API'
		custom_js_url: custom_url
	}

	handler := hono.swagger_ui(options)
	mut ctx := hono.Context{}
	response := handler(mut ctx)
	html := response.body

	return html.contains('src="${custom_url}"')
}

// Test: Custom CSS inline appears when provided
fn test_custom_css_inline_included() bool {
	custom_css := '.swagger-ui { background: red; }'
	options := hono.SwaggerUIOptions{
		url:        '/doc'
		title:      'Test API'
		custom_css: custom_css
	}

	handler := hono.swagger_ui(options)
	mut ctx := hono.Context{}
	response := handler(mut ctx)
	html := response.body

	return html.contains(custom_css)
}

// Test: Custom JS inline appears when provided
fn test_custom_js_inline_included() bool {
	custom_js := 'console.log("Custom JS loaded");'
	options := hono.SwaggerUIOptions{
		url:       '/doc'
		title:     'Test API'
		custom_js: custom_js
	}

	handler := hono.swagger_ui(options)
	mut ctx := hono.Context{}
	response := handler(mut ctx)
	html := response.body

	return html.contains(custom_js)
}

// Test: Response has correct Content-Type
fn test_response_content_type() bool {
	options := hono.SwaggerUIOptions{
		url:   '/doc'
		title: 'Test API'
	}

	handler := hono.swagger_ui(options)
	mut ctx := hono.Context{}
	response := handler(mut ctx)

	content_type := response.header.get(.content_type) or { '' }
	return content_type.contains('text/html')
}

// Test: Response status code is 200
fn test_response_status_code() bool {
	options := hono.SwaggerUIOptions{
		url:   '/doc'
		title: 'Test API'
	}

	handler := hono.swagger_ui(options)
	mut ctx := hono.Context{}
	response := handler(mut ctx)

	return response.status_code == 200
}

// Property test: Swagger UI Options appear in generated HTML
fn test_swagger_ui_options_property() PropertyTestStats {
	mut stats := PropertyTestStats{}

	println('Running Property 2: Swagger UI Options Appear in Generated HTML')
	println('Iterations: ${property_test_iterations}')
	println('')

	for i in 0 .. property_test_iterations {
		// Generate random options
		options := generate_random_options()

		// Generate HTML using the swagger_ui handler
		handler := hono.swagger_ui(options)
		mut ctx := hono.Context{}
		response := handler(mut ctx)
		html := response.body

		// Test 1: Title in HTML
		if test_title_in_html(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Title "${options.title}" not found in HTML')
		}

		// Test 2: URL in config
		if test_url_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: URL "${options.url}" not found in config')
		}

		// Test 3: deepLinking
		if test_deep_linking_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: deepLinking=${options.deep_linking} not found')
		}

		// Test 4: displayRequestDuration
		if test_display_request_duration_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: displayRequestDuration=${options.display_request_duration} not found')
		}

		// Test 5: defaultModelsExpandDepth
		if test_default_models_expand_depth_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: defaultModelsExpandDepth=${options.default_models_expand_depth} not found')
		}

		// Test 6: docExpansion
		if test_doc_expansion_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: docExpansion="${options.doc_expansion}" not found')
		}

		// Test 7: filter
		if test_filter_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: filter=${options.filter} not found')
		}

		// Test 8: showExtensions
		if test_show_extensions_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: showExtensions=${options.show_extensions} not found')
		}

		// Test 9: showCommonExtensions
		if test_show_common_extensions_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: showCommonExtensions=${options.show_common_extensions} not found')
		}

		// Test 10: tryItOutEnabled
		if test_try_it_out_enabled_in_config(options, html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: tryItOutEnabled=${options.try_it_out_enabled} not found')
		}

		// Test 11: Valid HTML5 document
		if test_valid_html5_document(html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Generated HTML is not a valid HTML5 document')
		}

		// Test 12: CDN resources included
		if test_cdn_resources_included(html) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: CDN resources not included')
		}

		// Progress indicator
		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')

	// Additional specific tests (run once)
	println('\nRunning additional specific tests...')

	// Test custom CSS URL
	if test_custom_css_url_included() {
		stats.record_pass()
	} else {
		stats.record_fail('Custom CSS URL not included when provided')
	}

	// Test custom JS URL
	if test_custom_js_url_included() {
		stats.record_pass()
	} else {
		stats.record_fail('Custom JS URL not included when provided')
	}

	// Test custom CSS inline
	if test_custom_css_inline_included() {
		stats.record_pass()
	} else {
		stats.record_fail('Custom CSS inline not included when provided')
	}

	// Test custom JS inline
	if test_custom_js_inline_included() {
		stats.record_pass()
	} else {
		stats.record_fail('Custom JS inline not included when provided')
	}

	// Test response Content-Type
	if test_response_content_type() {
		stats.record_pass()
	} else {
		stats.record_fail('Response Content-Type is not text/html')
	}

	// Test response status code
	if test_response_status_code() {
		stats.record_pass()
	} else {
		stats.record_fail('Response status code is not 200')
	}

	return stats
}

fn main() {
	println('🧪 Property-Based Test: Swagger UI Options Appear in Generated HTML')
	println('====================================================================')
	println('')

	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])

	stats := test_swagger_ui_options_property()
	stats.print_summary()

	// Exit with appropriate code
	if stats.failed_tests > 0 {
		exit(1)
	}
}
