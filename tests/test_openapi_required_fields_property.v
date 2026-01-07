// test_openapi_required_fields_property.v - Property-Based Test for OpenAPI Required Fields Validation
// **Feature: swagger-ui, Property 3: OpenAPI Document Required Fields Validation**
// **Validates: Requirements 2.2, 8.1**
//
// Property: For any OpenAPI document missing a required field (openapi, info, or paths),
// the validate() method SHALL return an error identifying the missing field.
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

// Random path generator
fn random_path() string {
	segments := rand.int_in_range(1, 4) or { 1 }
	mut path := ''
	for _ in 0 .. segments {
		path += '/' + random_string(3, 10)
	}
	return path
}

// Random OpenAPI version
fn random_openapi_version() string {
	versions := ['3.0.0', '3.0.1', '3.0.2', '3.0.3', '3.1.0']
	return versions[rand.int_in_range(0, versions.len) or { 0 }]
}

// Generate a valid OpenAPIDocument
fn generate_valid_document() hono.OpenAPIDocument {
	return hono.OpenAPIDocument{
		openapi: random_openapi_version()
		info: hono.OpenAPIInfo{
			title: random_string(5, 20)
			version: '${rand.int_in_range(1, 10) or { 1 }}.${rand.int_in_range(0, 10) or { 0 }}.${rand.int_in_range(0, 10) or { 0 }}'
		}
		paths: {
			random_path(): hono.OpenAPIPathItem{
				get: hono.OpenAPIOperation{
					summary: random_string(5, 20)
					responses: {
						'200': hono.OpenAPIResponse{description: 'Success'}
					}
				}
			}
		}
	}
}

// Test 1: Missing 'openapi' field should return error
fn test_missing_openapi_field() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 1: Missing openapi field validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate document with missing openapi field
		doc := hono.OpenAPIDocument{
			openapi: ''  // Missing required field
			info: hono.OpenAPIInfo{
				title: random_string(5, 20)
				version: '1.0.0'
			}
			paths: {
				random_path(): hono.OpenAPIPathItem{
					get: hono.OpenAPIOperation{
						responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
					}
				}
			}
		}
		
		// Validate should fail
		doc.validate() or {
			// Check that error message mentions 'openapi'
			if err.msg().contains('openapi') {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't mention 'openapi': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail('Validation passed for document with missing openapi field')
	}
	
	return stats
}

// Test 2: Missing 'info.title' field should return error
fn test_missing_info_title_field() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 2: Missing info.title field validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate document with missing info.title field
		doc := hono.OpenAPIDocument{
			openapi: random_openapi_version()
			info: hono.OpenAPIInfo{
				title: ''  // Missing required field
				version: '1.0.0'
			}
			paths: {
				random_path(): hono.OpenAPIPathItem{
					get: hono.OpenAPIOperation{
						responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
					}
				}
			}
		}
		
		// Validate should fail
		doc.validate() or {
			// Check that error message mentions 'info.title'
			if err.msg().contains('info.title') {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't mention 'info.title': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail('Validation passed for document with missing info.title field')
	}
	
	return stats
}

// Test 3: Missing 'info.version' field should return error
fn test_missing_info_version_field() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 3: Missing info.version field validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate document with missing info.version field
		doc := hono.OpenAPIDocument{
			openapi: random_openapi_version()
			info: hono.OpenAPIInfo{
				title: random_string(5, 20)
				version: ''  // Missing required field
			}
			paths: {
				random_path(): hono.OpenAPIPathItem{
					get: hono.OpenAPIOperation{
						responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
					}
				}
			}
		}
		
		// Validate should fail
		doc.validate() or {
			// Check that error message mentions 'info.version'
			if err.msg().contains('info.version') {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't mention 'info.version': ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail('Validation passed for document with missing info.version field')
	}
	
	return stats
}

// Test 4: Valid document should pass validation
fn test_valid_document_passes() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 4: Valid document passes validation')
	
	for _ in 0 .. property_test_iterations {
		// Generate valid document
		doc := generate_valid_document()
		
		// Validate should pass
		doc.validate() or {
			stats.record_fail('Validation failed for valid document: ${err.msg()}')
			continue
		}
		
		stats.record_pass()
	}
	
	return stats
}

// Test 5: Unsupported OpenAPI version should return error
fn test_unsupported_openapi_version() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Test 5: Unsupported OpenAPI version validation')
	
	invalid_versions := ['2.0.0', '1.0.0', '4.0.0', '3.2.0', 'invalid', '']
	
	for _ in 0 .. property_test_iterations {
		// Pick a random invalid version
		invalid_version := invalid_versions[rand.int_in_range(0, invalid_versions.len - 1) or { 0 }]
		
		doc := hono.OpenAPIDocument{
			openapi: invalid_version
			info: hono.OpenAPIInfo{
				title: random_string(5, 20)
				version: '1.0.0'
			}
			paths: {
				random_path(): hono.OpenAPIPathItem{
					get: hono.OpenAPIOperation{
						responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
					}
				}
			}
		}
		
		// Validate should fail
		doc.validate() or {
			// Check that error message mentions version issue
			if err.msg().contains('openapi') || err.msg().contains('version') || err.msg().contains('Unsupported') {
				stats.record_pass()
				continue
			}
			stats.record_fail("Error message doesn't mention version issue: ${err.msg()}")
			continue
		}
		
		// If validation passed, that's a failure
		stats.record_fail('Validation passed for document with unsupported version: ${invalid_version}')
	}
	
	return stats
}

fn main() {
	println('🧪 Property-Based Test: OpenAPI Required Fields Validation')
	println('============================================================')
	println('')
	
	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])
	
	mut total_stats := PropertyTestStats{}
	
	// Run all tests
	stats1 := test_missing_openapi_field()
	total_stats.total_tests += stats1.total_tests
	total_stats.passed_tests += stats1.passed_tests
	total_stats.failed_tests += stats1.failed_tests
	total_stats.failed_examples << stats1.failed_examples
	
	stats2 := test_missing_info_title_field()
	total_stats.total_tests += stats2.total_tests
	total_stats.passed_tests += stats2.passed_tests
	total_stats.failed_tests += stats2.failed_tests
	total_stats.failed_examples << stats2.failed_examples
	
	stats3 := test_missing_info_version_field()
	total_stats.total_tests += stats3.total_tests
	total_stats.passed_tests += stats3.passed_tests
	total_stats.failed_tests += stats3.failed_tests
	total_stats.failed_examples << stats3.failed_examples
	
	stats4 := test_valid_document_passes()
	total_stats.total_tests += stats4.total_tests
	total_stats.passed_tests += stats4.passed_tests
	total_stats.failed_tests += stats4.failed_tests
	total_stats.failed_examples << stats4.failed_examples
	
	stats5 := test_unsupported_openapi_version()
	total_stats.total_tests += stats5.total_tests
	total_stats.passed_tests += stats5.passed_tests
	total_stats.failed_tests += stats5.failed_tests
	total_stats.failed_examples << stats5.failed_examples
	
	total_stats.print_summary()
	
	// Exit with appropriate code
	if total_stats.failed_tests > 0 {
		exit(1)
	}
}
