// test_openapi_invalid_path_property.v - Property-Based Test for Invalid Path Error Identification
// **Feature: swagger-ui, Property 9: Invalid Path Error Identification**
// **Validates: Requirements 8.3**
//
// Property: For any OpenAPI document with an invalid path definition,
// the validation error message SHALL identify the problematic path.
module main

import hono
import rand
import time

const property_test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests    int
	passed_tests   int
	failed_tests   int
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
			if i >= 5 {
				println('... and ${stats.failed_examples.len - 5} more')
				break
			}
			println('  ${example}')
		}
	}
}

// Random string generator
fn random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
	len := rand.int_in_range(min_len, max_len + 1) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx..idx + 1]
	}
	return result
}

// Random OpenAPI version
fn random_openapi_version() string {
	versions := ['3.0.0', '3.0.1', '3.0.2', '3.0.3', '3.1.0']
	return versions[rand.int_in_range(0, versions.len) or { 0 }]
}

// Generate a valid path item
fn generate_valid_path_item() hono.OpenAPIPathItem {
	return hono.OpenAPIPathItem{
		get: hono.OpenAPIOperation{
			summary: random_string(5, 20)
			responses: {
				'200': hono.OpenAPIResponse{description: 'Success'}
			}
		}
	}
}

// Generate a document with a specific invalid path
fn generate_doc_with_invalid_path(invalid_path string) hono.OpenAPIDocument {
	return hono.OpenAPIDocument{
		openapi: random_openapi_version()
		info: hono.OpenAPIInfo{
			title: random_string(5, 20)
			version: '1.0.0'
		}
		paths: {
			invalid_path: generate_valid_path_item()
		}
	}
}

// Test 1: Path not starting with '/' should return error mentioning the path
fn test_path_not_starting_with_slash() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 1: Path not starting with slash validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate invalid path (not starting with /)
		invalid_path := random_string(3, 15)  // e.g., "users" instead of "/users"
		
		doc := generate_doc_with_invalid_path(invalid_path)
		
		// Validate should fail
		doc.validate() or {
			// Check that error message contains the invalid path
			if err.msg().contains(invalid_path) {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't contain invalid path '${invalid_path}': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail("Validation passed for invalid path '${invalid_path}'")
	}
	
	return stats
}

// Test 2: Path with unmatched '{' should return error mentioning the path
fn test_path_with_unmatched_open_brace() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 2: Path with unmatched open brace validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate invalid path with unmatched '{'
		param_name := random_string(3, 10)
		invalid_path := '/${random_string(3, 10)}/{${param_name}'  // e.g., "/users/{id" (missing closing brace)
		
		doc := generate_doc_with_invalid_path(invalid_path)
		
		// Validate should fail
		doc.validate() or {
			// Check that error message contains the invalid path
			if err.msg().contains(invalid_path) {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't contain invalid path '${invalid_path}': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail("Validation passed for invalid path '${invalid_path}'")
	}
	
	return stats
}

// Test 3: Path with unmatched '}' should return error mentioning the path
fn test_path_with_unmatched_close_brace() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 3: Path with unmatched close brace validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate invalid path with unmatched '}'
		param_name := random_string(3, 10)
		invalid_path := '/${random_string(3, 10)}/${param_name}}'  // e.g., "/users/id}" (extra closing brace)
		
		doc := generate_doc_with_invalid_path(invalid_path)
		
		// Validate should fail
		doc.validate() or {
			// Check that error message contains the invalid path
			if err.msg().contains(invalid_path) {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't contain invalid path '${invalid_path}': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail("Validation passed for invalid path '${invalid_path}'")
	}
	
	return stats
}

// Test 4: Path with empty parameter '{}' should return error mentioning the path
fn test_path_with_empty_parameter() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 4: Path with empty parameter validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate invalid path with empty parameter
		invalid_path := '/${random_string(3, 10)}/{}'  // e.g., "/users/{}" (empty parameter)
		
		doc := generate_doc_with_invalid_path(invalid_path)
		
		// Validate should fail
		doc.validate() or {
			// Check that error message contains the invalid path
			if err.msg().contains(invalid_path) {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't contain invalid path '${invalid_path}': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail("Validation passed for invalid path '${invalid_path}'")
	}
	
	return stats
}

// Test 5: Path with consecutive slashes should return error mentioning the path
fn test_path_with_consecutive_slashes() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 5: Path with consecutive slashes validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate invalid path with consecutive slashes
		invalid_path := '/${random_string(3, 10)}//${random_string(3, 10)}'  // e.g., "/users//profile"
		
		doc := generate_doc_with_invalid_path(invalid_path)
		
		// Validate should fail
		doc.validate() or {
			// Check that error message contains the invalid path
			if err.msg().contains(invalid_path) {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't contain invalid path '${invalid_path}': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail("Validation passed for invalid path '${invalid_path}'")
	}
	
	return stats
}

// Test 6: Valid paths should pass validation
fn test_valid_paths_pass() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 6: Valid paths pass validation')
	
	valid_path_patterns := [
		'/users',
		'/users/{id}',
		'/api/v1/users',
		'/api/v1/users/{userId}/posts/{postId}',
		'/{resource}',
		'/health',
		'/api/v2/items/{itemId}/details',
	]
	
	for _ in 0 .. property_test_iterations {
		// Pick a random valid path pattern
		valid_path := valid_path_patterns[rand.int_in_range(0, valid_path_patterns.len) or { 0 }]
		
		doc := hono.OpenAPIDocument{
			openapi: random_openapi_version()
			info: hono.OpenAPIInfo{
				title: random_string(5, 20)
				version: '1.0.0'
			}
			paths: {
				valid_path: generate_valid_path_item()
			}
		}
		
		// Validate should pass
		doc.validate() or {
			stats.record_fail("Validation failed for valid path '${valid_path}': ${err.msg()}")
			continue
		}
		
		stats.record_pass()
	}
	
	return stats
}

fn main() {
	println('🧪 Property-Based Test: Invalid Path Error Identification')
	println('==========================================================')
	println('')
	
	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])
	
	mut total_stats := PropertyTestStats{}
	
	// Run all tests
	stats1 := test_path_not_starting_with_slash()
	total_stats.total_tests += stats1.total_tests
	total_stats.passed_tests += stats1.passed_tests
	total_stats.failed_tests += stats1.failed_tests
	total_stats.failed_examples << stats1.failed_examples
	
	stats2 := test_path_with_unmatched_open_brace()
	total_stats.total_tests += stats2.total_tests
	total_stats.passed_tests += stats2.passed_tests
	total_stats.failed_tests += stats2.failed_tests
	total_stats.failed_examples << stats2.failed_examples
	
	stats3 := test_path_with_unmatched_close_brace()
	total_stats.total_tests += stats3.total_tests
	total_stats.passed_tests += stats3.passed_tests
	total_stats.failed_tests += stats3.failed_tests
	total_stats.failed_examples << stats3.failed_examples
	
	stats4 := test_path_with_empty_parameter()
	total_stats.total_tests += stats4.total_tests
	total_stats.passed_tests += stats4.passed_tests
	total_stats.failed_tests += stats4.failed_tests
	total_stats.failed_examples << stats4.failed_examples
	
	stats5 := test_path_with_consecutive_slashes()
	total_stats.total_tests += stats5.total_tests
	total_stats.passed_tests += stats5.passed_tests
	total_stats.failed_tests += stats5.failed_tests
	total_stats.failed_examples << stats5.failed_examples
	
	stats6 := test_valid_paths_pass()
	total_stats.total_tests += stats6.total_tests
	total_stats.passed_tests += stats6.passed_tests
	total_stats.failed_tests += stats6.failed_tests
	total_stats.failed_examples << stats6.failed_examples
	
	total_stats.print_summary()
	
	// Exit with appropriate code
	if total_stats.failed_tests > 0 {
		exit(1)
	}
}
