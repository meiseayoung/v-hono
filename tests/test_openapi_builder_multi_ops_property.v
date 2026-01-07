// test_openapi_builder_multi_ops_property.v - Property-Based Test for Builder Multiple Operations
// **Feature: swagger-ui, Property 7: OpenAPI Builder Supports Multiple Operations Per Path**
// **Validates: Requirements 6.2, 6.3, 6.4**
//
// Property: For any path, adding multiple different HTTP method operations using the builder
// SHALL result in all operations being present in the final document.
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

// Generate a random operation with a unique identifier
fn generate_operation(method string, id string) hono.OpenAPIOperation {
	return hono.OpenAPIOperation{
		summary: 'Test ${method} operation - ${id}'
		description: 'Description for ${method} - ${id}'
		operation_id: '${method}_${id}'
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


// Randomly select a subset of HTTP methods
fn random_method_subset() []string {
	// Select between 2 and 7 methods
	num_methods := rand.int_in_range(2, http_methods.len + 1) or { 2 }
	
	mut selected := []string{}
	mut available := http_methods.clone()
	
	for _ in 0 .. num_methods {
		if available.len == 0 {
			break
		}
		idx := rand.int_in_range(0, available.len) or { 0 }
		selected << available[idx]
		available.delete(idx)
	}
	
	return selected
}

// Test that multiple operations can be added to the same path
fn test_multiple_operations_on_path() PropertyTestStats {
	mut stats := PropertyTestStats{}

	println('Running Property 7: OpenAPI Builder Supports Multiple Operations Per Path')
	println('Iterations: ${property_test_iterations}')
	println('')

	for i in 0 .. property_test_iterations {
		path := random_path()
		methods := random_method_subset()
		unique_id := random_string(5, 10)

		// Create operations for selected methods
		mut operations := map[string]hono.OpenAPIOperation{}
		for method in methods {
			operations[method] = generate_operation(method, unique_id)
		}

		// Build document using the builder
		mut builder := hono.OpenAPIBuilder.new()
		builder.openapi('3.0.0')
		builder.title('Test API')
		builder.version('1.0.0')

		mut path_builder := builder.path(path)

		// Add operations for each selected method
		for method in methods {
			op := operations[method] or { continue }
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
		}

		path_builder.done()

		// Build the document
		doc := builder.build() or {
			stats.record_fail('Iteration ${i}: Build failed - ${err}')
			continue
		}

		// Verify the path exists
		if path !in doc.paths {
			stats.record_fail('Iteration ${i}: Path ${path} not found in document')
			continue
		}

		path_item := doc.paths[path] or {
			stats.record_fail('Iteration ${i}: Could not get path item')
			continue
		}

		// Verify all selected methods are present
		mut all_preserved := true
		mut missing_methods := []string{}

		for method in methods {
			stored_op := get_operation_by_method(path_item, method)
			expected_op := operations[method] or { continue }

			if !is_operation_set(stored_op) {
				all_preserved = false
				missing_methods << method
				continue
			}

			if stored_op.summary != expected_op.summary {
				all_preserved = false
				missing_methods << '${method}(summary mismatch)'
			}
		}

		if all_preserved {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Methods not preserved: ${missing_methods.join(", ")}. Selected: ${methods.join(", ")}')
		}

		// Progress indicator
		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')

	return stats
}

// Test that operations on different paths don't interfere
fn test_multiple_paths_with_operations() PropertyTestStats {
	mut stats := PropertyTestStats{}

	println('\nRunning additional test: Multiple paths with different operations')
	println('Iterations: ${property_test_iterations}')
	println('')

	for i in 0 .. property_test_iterations {
		// Generate 2-3 different paths with fixed operations
		path1 := random_path()
		path2 := random_path()
		unique_id := random_string(5, 10)

		// Create operations for each path
		get_op1 := generate_operation('get', '${path1}_${unique_id}')
		post_op1 := generate_operation('post', '${path1}_${unique_id}')
		get_op2 := generate_operation('get', '${path2}_${unique_id}')
		put_op2 := generate_operation('put', '${path2}_${unique_id}')

		// Build document
		mut builder := hono.OpenAPIBuilder.new()
		builder.openapi('3.0.0')
		builder.title('Test API')
		builder.version('1.0.0')

		// Add path1 with GET and POST
		mut path_builder1 := builder.path(path1)
		path_builder1.get(get_op1)
		path_builder1.post(post_op1)
		path_builder1.done()

		// Add path2 with GET and PUT
		mut path_builder2 := builder.path(path2)
		path_builder2.get(get_op2)
		path_builder2.put(put_op2)
		path_builder2.done()

		doc := builder.build() or {
			stats.record_fail('Iteration ${i}: Build failed - ${err}')
			continue
		}

		// Verify all paths and their operations
		mut all_correct := true
		mut errors := []string{}

		// Check path1
		if path1 !in doc.paths {
			all_correct = false
			errors << 'Path ${path1} not found'
		} else {
			path_item1 := doc.paths[path1] or {
				all_correct = false
				errors << 'Could not get path item for ${path1}'
				hono.OpenAPIPathItem{}
			}
			if !is_operation_set(path_item1.get) || path_item1.get.summary != get_op1.summary {
				all_correct = false
				errors << '${path1}:get'
			}
			if !is_operation_set(path_item1.post) || path_item1.post.summary != post_op1.summary {
				all_correct = false
				errors << '${path1}:post'
			}
		}

		// Check path2
		if path2 !in doc.paths {
			all_correct = false
			errors << 'Path ${path2} not found'
		} else {
			path_item2 := doc.paths[path2] or {
				all_correct = false
				errors << 'Could not get path item for ${path2}'
				hono.OpenAPIPathItem{}
			}
			if !is_operation_set(path_item2.get) || path_item2.get.summary != get_op2.summary {
				all_correct = false
				errors << '${path2}:get'
			}
			if !is_operation_set(path_item2.put) || path_item2.put.summary != put_op2.summary {
				all_correct = false
				errors << '${path2}:put'
			}
		}

		if all_correct {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Errors: ${errors.join(", ")}')
		}

		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')

	return stats
}

fn main() {
	println('🧪 Property-Based Test: OpenAPI Builder Multiple Operations Per Path')
	println('=====================================================================')
	println('')

	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])

	// Run main property test
	stats1 := test_multiple_operations_on_path()
	stats1.print_summary()

	// Run additional test
	stats2 := test_multiple_paths_with_operations()
	stats2.print_summary()

	// Exit with appropriate code
	if stats1.failed_tests > 0 || stats2.failed_tests > 0 {
		exit(1)
	}
}
