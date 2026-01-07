// test_openapi_optional_fields_property.v - Property-Based Test for Optional Fields Omission
// **Feature: swagger-ui, Property 8: Optional Fields Omission in JSON**
// **Validates: Requirements 3.4**
//
// Property: For any OpenAPI document with optional fields not set, 
// the serialized JSON SHALL NOT contain those fields.
module main

import hono
import rand
import time

const property_test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
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

// Test 1: Empty description should not appear in JSON
fn test_empty_description_omitted() bool {
	info := hono.OpenAPIInfo{
		title: random_string(5, 15)
		version: '1.0.0'
		// description is empty - should be omitted
	}
	
	json_str := info.to_json().str()
	return !json_str.contains('"description"')
}

// Test 2: Empty contact should not appear in JSON
fn test_empty_contact_omitted() bool {
	info := hono.OpenAPIInfo{
		title: random_string(5, 15)
		version: '1.0.0'
		// contact is empty - should be omitted
	}
	
	json_str := info.to_json().str()
	return !json_str.contains('"contact"')
}

// Test 3: Empty license should not appear in JSON
fn test_empty_license_omitted() bool {
	info := hono.OpenAPIInfo{
		title: random_string(5, 15)
		version: '1.0.0'
		// license is empty - should be omitted
	}
	
	json_str := info.to_json().str()
	return !json_str.contains('"license"')
}

// Test 4: Empty servers array should not appear in JSON
fn test_empty_servers_omitted() bool {
	doc := hono.OpenAPIDocument{
		openapi: '3.0.0'
		info: hono.OpenAPIInfo{
			title: random_string(5, 15)
			version: '1.0.0'
		}
		paths: {}
		// servers is empty - should be omitted
	}
	
	json_str := doc.to_json_str()
	return !json_str.contains('"servers"')
}

// Test 5: Empty tags array should not appear in JSON
fn test_empty_tags_omitted() bool {
	doc := hono.OpenAPIDocument{
		openapi: '3.0.0'
		info: hono.OpenAPIInfo{
			title: random_string(5, 15)
			version: '1.0.0'
		}
		paths: {}
		// tags is empty - should be omitted
	}
	
	json_str := doc.to_json_str()
	return !json_str.contains('"tags"')
}

// Test 6: Empty components should not appear in JSON
fn test_empty_components_omitted() bool {
	doc := hono.OpenAPIDocument{
		openapi: '3.0.0'
		info: hono.OpenAPIInfo{
			title: random_string(5, 15)
			version: '1.0.0'
		}
		paths: {}
		// components is empty - should be omitted
	}
	
	json_str := doc.to_json_str()
	return !json_str.contains('"components"')
}

// Test 7: False boolean values should not appear in JSON (for optional booleans)
fn test_false_boolean_omitted() bool {
	param := hono.OpenAPIParameter{
		name: random_string(3, 10)
		in_location: 'query'
		required: false  // should be omitted
		deprecated: false  // should be omitted
	}
	
	json_str := param.to_json().str()
	no_required := !json_str.contains('"required"')
	no_deprecated := !json_str.contains('"deprecated"')
	return no_required && no_deprecated
}

// Test 8: True boolean values SHOULD appear in JSON
fn test_true_boolean_included() bool {
	param := hono.OpenAPIParameter{
		name: random_string(3, 10)
		in_location: 'query'
		required: true  // should be included
		deprecated: true  // should be included
	}
	
	json_str := param.to_json().str()
	has_required := json_str.contains('"required":true')
	has_deprecated := json_str.contains('"deprecated":true')
	return has_required && has_deprecated
}

// Test 9: Empty operation should not appear in path item
fn test_empty_operation_omitted() bool {
	path_item := hono.OpenAPIPathItem{
		summary: random_string(5, 15)
		get: hono.OpenAPIOperation{
			summary: 'Get'
			responses: {
				'200': hono.OpenAPIResponse{description: 'OK'}
			}
		}
		// post, put, delete, etc. are empty - should be omitted
	}
	
	json_str := path_item.to_json().str()
	has_get := json_str.contains('"get"')
	no_post := !json_str.contains('"post"')
	no_put := !json_str.contains('"put"')
	no_delete := !json_str.contains('"delete"')
	return has_get && no_post && no_put && no_delete
}

// Test 10: Empty parameters array should not appear in operation
fn test_empty_parameters_omitted() bool {
	op := hono.OpenAPIOperation{
		summary: random_string(5, 15)
		responses: {
			'200': hono.OpenAPIResponse{description: 'OK'}
		}
		// parameters is empty - should be omitted
	}
	
	json_str := op.to_json().str()
	return !json_str.contains('"parameters"')
}

// Test 11: Empty request body should not appear in operation
fn test_empty_request_body_omitted() bool {
	op := hono.OpenAPIOperation{
		summary: random_string(5, 15)
		responses: {
			'200': hono.OpenAPIResponse{description: 'OK'}
		}
		// request_body is empty - should be omitted
	}
	
	json_str := op.to_json().str()
	return !json_str.contains('"requestBody"')
}

// Test 12: Zero numeric values should not appear (for optional numerics)
fn test_zero_numeric_omitted() bool {
	schema := hono.OpenAPISchema{
		schema_type: 'integer'
		// minimum, maximum, min_length, max_length are 0 - should be omitted
	}
	
	json_str := schema.to_json().str()
	no_minimum := !json_str.contains('"minimum"')
	no_maximum := !json_str.contains('"maximum"')
	no_min_length := !json_str.contains('"minLength"')
	no_max_length := !json_str.contains('"maxLength"')
	return no_minimum && no_maximum && no_min_length && no_max_length
}

// Test 13: Non-zero numeric values SHOULD appear
fn test_nonzero_numeric_included() bool {
	schema := hono.OpenAPISchema{
		schema_type: 'integer'
		minimum: 1
		maximum: 100
		min_length: 5
		max_length: 50
	}
	
	json_str := schema.to_json().str()
	has_minimum := json_str.contains('"minimum"')
	has_maximum := json_str.contains('"maximum"')
	has_min_length := json_str.contains('"minLength"')
	has_max_length := json_str.contains('"maxLength"')
	return has_minimum && has_maximum && has_min_length && has_max_length
}

// Property test: Optional fields omission
fn test_optional_fields_property() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Running Property 8: Optional Fields Omission in JSON')
	println('Iterations: ${property_test_iterations}')
	println('')
	
	for i in 0 .. property_test_iterations {
		// Test 1: Empty description
		if test_empty_description_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty description was not omitted')
		}
		
		// Test 2: Empty contact
		if test_empty_contact_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty contact was not omitted')
		}
		
		// Test 3: Empty license
		if test_empty_license_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty license was not omitted')
		}
		
		// Test 4: Empty servers
		if test_empty_servers_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty servers was not omitted')
		}
		
		// Test 5: Empty tags
		if test_empty_tags_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty tags was not omitted')
		}
		
		// Test 6: Empty components
		if test_empty_components_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty components was not omitted')
		}
		
		// Test 7: False boolean omitted
		if test_false_boolean_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: False boolean was not omitted')
		}
		
		// Test 8: True boolean included
		if test_true_boolean_included() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: True boolean was not included')
		}
		
		// Test 9: Empty operation omitted
		if test_empty_operation_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty operation was not omitted')
		}
		
		// Test 10: Empty parameters omitted
		if test_empty_parameters_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty parameters was not omitted')
		}
		
		// Test 11: Empty request body omitted
		if test_empty_request_body_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Empty request body was not omitted')
		}
		
		// Test 12: Zero numeric omitted
		if test_zero_numeric_omitted() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Zero numeric was not omitted')
		}
		
		// Test 13: Non-zero numeric included
		if test_nonzero_numeric_included() {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Non-zero numeric was not included')
		}
		
		// Progress indicator
		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')
	
	return stats
}

fn main() {
	println('🧪 Property-Based Test: Optional Fields Omission')
	println('=================================================')
	println('')
	
	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])
	
	stats := test_optional_fields_property()
	stats.print_summary()
	
	// Exit with appropriate code
	if stats.failed_tests > 0 {
		exit(1)
	}
}
