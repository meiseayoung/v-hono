// test_openapi_http_methods_property.v - Property-Based Test for HTTP Methods Support
// **Feature: swagger-ui, Property 4: HTTP Methods Support in Path Items**
// **Validates: Requirements 2.3**
//
// Property: For any HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS),
// adding an operation with that method to a path item SHALL succeed and be preserved in the document.
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

// Random string generator
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

// Random path generator
fn random_path() string {
	segments := rand.int_in_range(1, 4) or { 1 }
	mut path := ''
	for _ in 0 .. segments {
		path += '/' + random_string(3, 10)
	}
	return path
}

// All supported HTTP methods
const http_methods = ['get', 'post', 'put', 'delete', 'patch', 'head', 'options']

// Generate a random operation with a unique summary for identification
fn generate_operation(method string) hono.OpenAPIOperation {
	return hono.OpenAPIOperation{
		summary: 'Test ${method} operation - ${random_string(5, 10)}'
		description: 'Description for ${method}'
		operation_id: '${method}_${random_string(5, 10)}'
		responses: {
			'200': hono.OpenAPIResponse{
				description: 'Success response for ${method}'
			}
		}
	}
}

// Check if an operation is set (has responses)
fn is_operation_set(op hono.OpenAPIOperation) bool {
	return op.responses.len > 0
}

// Get operation from path item by method name
fn get_operation_by_method(path_item hono.OpenAPIPathItem, method string) hono.OpenAPIOperation {
	return match method {
		'get' { path_item.get }
		'post' { path_item.post }
		'put' { path_item.put }
		'delete' { path_item.delete }
		'patch' { path_item.patch }
		'head' { path_item.head }
		'options' { path_item.options }
		else { hono.OpenAPIOperation{} }
	}
}

// Test that each HTTP method can be added via the builder and is preserved
fn test_http_method_via_builder(method string) bool {
	path := random_path()
	op := generate_operation(method)

	// Build document using the builder - step by step
	mut builder := hono.OpenAPIBuilder.new()
	builder.openapi('3.0.0')
	builder.title('Test API')
	builder.version('1.0.0')

	// Add operation using the path builder
	mut path_builder := builder.path(path)

	match method {
		'get' { path_builder.get(op) }
		'post' { path_builder.post(op) }
		'put' { path_builder.put(op) }
		'delete' { path_builder.delete(op) }
		'patch' { path_builder.patch(op) }
		'head' { path_builder.head(op) }
		'options' { path_builder.options(op) }
		else {}
	}

	path_builder.done()

	// Build the document
	doc := builder.build() or { return false }

	// Verify the path exists
	if path !in doc.paths {
		return false
	}

	// Verify the operation is preserved
	path_item := doc.paths[path] or { return false }
	stored_op := get_operation_by_method(path_item, method)

	// Check operation is set and has correct summary
	if !is_operation_set(stored_op) {
		return false
	}

	if stored_op.summary != op.summary {
		return false
	}

	if stored_op.operation_id != op.operation_id {
		return false
	}

	return true
}

// Property test: All HTTP methods are supported
fn test_http_methods_property() PropertyTestStats {
	mut stats := PropertyTestStats{}

	println('Running Property 4: HTTP Methods Support in Path Items')
	println('Iterations: ${property_test_iterations}')
	println('')

	for i in 0 .. property_test_iterations {
		// Pick a random HTTP method
		method_idx := rand.int_in_range(0, http_methods.len) or { 0 }
		method := http_methods[method_idx]

		if test_http_method_via_builder(method) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Method ${method} was not preserved in document')
		}

		// Progress indicator
		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')

	return stats
}


// Additional test: All methods can be added to the same path
fn test_all_methods_on_same_path() PropertyTestStats {
	mut stats := PropertyTestStats{}

	println('\nRunning additional test: All HTTP methods on same path')
	println('Iterations: ${property_test_iterations}')
	println('')

	for i in 0 .. property_test_iterations {
		path := random_path()

		// Create operations for all methods
		get_op := generate_operation('get')
		post_op := generate_operation('post')
		put_op := generate_operation('put')
		delete_op := generate_operation('delete')
		patch_op := generate_operation('patch')
		head_op := generate_operation('head')
		options_op := generate_operation('options')

		// Build document with all methods on the same path
		mut builder := hono.OpenAPIBuilder.new()
		builder.openapi('3.0.0')
		builder.title('Test API')
		builder.version('1.0.0')

		mut path_builder := builder.path(path)
		path_builder.get(get_op)
		path_builder.post(post_op)
		path_builder.put(put_op)
		path_builder.delete(delete_op)
		path_builder.patch(patch_op)
		path_builder.head(head_op)
		path_builder.options(options_op)
		path_builder.done()

		doc := builder.build() or {
			stats.record_fail('Iteration ${i}: Build failed - ${err}')
			continue
		}

		// Verify all methods are preserved
		path_item := doc.paths[path] or {
			stats.record_fail('Iteration ${i}: Path not found')
			continue
		}

		mut all_preserved := true
		
		// Check each method
		if !is_operation_set(path_item.get) || path_item.get.summary != get_op.summary {
			all_preserved = false
		}
		if !is_operation_set(path_item.post) || path_item.post.summary != post_op.summary {
			all_preserved = false
		}
		if !is_operation_set(path_item.put) || path_item.put.summary != put_op.summary {
			all_preserved = false
		}
		if !is_operation_set(path_item.delete) || path_item.delete.summary != delete_op.summary {
			all_preserved = false
		}
		if !is_operation_set(path_item.patch) || path_item.patch.summary != patch_op.summary {
			all_preserved = false
		}
		if !is_operation_set(path_item.head) || path_item.head.summary != head_op.summary {
			all_preserved = false
		}
		if !is_operation_set(path_item.options) || path_item.options.summary != options_op.summary {
			all_preserved = false
		}

		if all_preserved {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Not all methods preserved on path ${path}')
		}

		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')

	return stats
}

fn main() {
	println('🧪 Property-Based Test: HTTP Methods Support in Path Items')
	println('============================================================')
	println('')

	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])

	// Run main property test
	stats1 := test_http_methods_property()
	stats1.print_summary()

	// Run additional test
	stats2 := test_all_methods_on_same_path()
	stats2.print_summary()

	// Exit with appropriate code
	if stats1.failed_tests > 0 || stats2.failed_tests > 0 {
		exit(1)
	}
}
