// test_openapi_param_locations_property.v - Property-Based Test for Parameter Locations Support
// **Feature: swagger-ui, Property 5: Parameter Locations Support**
// **Validates: Requirements 2.5**
//
// Property: For any parameter location (path, query, header, cookie),
// adding a parameter with that location SHALL succeed and be preserved in the document.
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

// All supported parameter locations
const param_locations = ['path', 'query', 'header', 'cookie']

// Generate a random parameter with a specific location
fn generate_parameter(location string) hono.OpenAPIParameter {
	return hono.OpenAPIParameter{
		name: random_string(3, 10)
		in_location: location
		description: 'Test ${location} parameter - ${random_string(5, 10)}'
		required: location == 'path' || rand.int_in_range(0, 2) or { 0 } == 1
		schema: hono.OpenAPISchema{
			schema_type: 'string'
		}
	}
}


// Test that each parameter location can be added and is preserved
fn test_param_location_via_builder(location string) bool {
	path := random_path()
	param := generate_parameter(location)

	// Create an operation with the parameter
	op := hono.OpenAPIOperation{
		summary: 'Test operation with ${location} parameter'
		parameters: [param]
		responses: {
			'200': hono.OpenAPIResponse{
				description: 'Success'
			}
		}
	}

	// Build document using the builder
	mut builder := hono.OpenAPIBuilder.new()
	builder.openapi('3.0.0')
	builder.title('Test API')
	builder.version('1.0.0')

	mut path_builder := builder.path(path)
	path_builder.get(op)
	path_builder.done()

	// Build the document
	doc := builder.build() or { return false }

	// Verify the path exists
	if path !in doc.paths {
		return false
	}

	// Verify the parameter is preserved
	path_item := doc.paths[path] or { return false }
	
	if path_item.get.parameters.len == 0 {
		return false
	}

	stored_param := path_item.get.parameters[0]

	// Check parameter location is preserved
	if stored_param.in_location != location {
		return false
	}

	// Check parameter name is preserved
	if stored_param.name != param.name {
		return false
	}

	return true
}

// Property test: All parameter locations are supported
fn test_param_locations_property() PropertyTestStats {
	mut stats := PropertyTestStats{}

	println('Running Property 5: Parameter Locations Support')
	println('Iterations: ${property_test_iterations}')
	println('')

	for i in 0 .. property_test_iterations {
		// Pick a random parameter location
		location_idx := rand.int_in_range(0, param_locations.len) or { 0 }
		location := param_locations[location_idx]

		if test_param_location_via_builder(location) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Location ${location} was not preserved in document')
		}

		// Progress indicator
		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')

	return stats
}

// Additional test: All locations can be used in the same operation
fn test_all_locations_in_same_operation() PropertyTestStats {
	mut stats := PropertyTestStats{}

	println('\nRunning additional test: All parameter locations in same operation')
	println('Iterations: ${property_test_iterations}')
	println('')

	for i in 0 .. property_test_iterations {
		path := random_path()

		// Create parameters for all locations
		path_param := generate_parameter('path')
		query_param := generate_parameter('query')
		header_param := generate_parameter('header')
		cookie_param := generate_parameter('cookie')

		// Create an operation with all parameters
		op := hono.OpenAPIOperation{
			summary: 'Test operation with all parameter locations'
			parameters: [path_param, query_param, header_param, cookie_param]
			responses: {
				'200': hono.OpenAPIResponse{
					description: 'Success'
				}
			}
		}

		// Build document
		mut builder := hono.OpenAPIBuilder.new()
		builder.openapi('3.0.0')
		builder.title('Test API')
		builder.version('1.0.0')

		mut path_builder := builder.path(path)
		path_builder.get(op)
		path_builder.done()

		doc := builder.build() or {
			stats.record_fail('Iteration ${i}: Build failed - ${err}')
			continue
		}

		// Verify all parameters are preserved
		path_item := doc.paths[path] or {
			stats.record_fail('Iteration ${i}: Path not found')
			continue
		}

		if path_item.get.parameters.len != 4 {
			stats.record_fail('Iteration ${i}: Expected 4 parameters, got ${path_item.get.parameters.len}')
			continue
		}

		// Check each location is present
		mut found_locations := map[string]bool{}
		for param in path_item.get.parameters {
			found_locations[param.in_location] = true
		}

		mut all_found := true
		for loc in param_locations {
			if loc !in found_locations {
				all_found = false
				break
			}
		}

		if all_found {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Not all parameter locations preserved')
		}

		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')

	return stats
}

fn main() {
	println('🧪 Property-Based Test: Parameter Locations Support')
	println('====================================================')
	println('')

	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])

	// Run main property test
	stats1 := test_param_locations_property()
	stats1.print_summary()

	// Run additional test
	stats2 := test_all_locations_in_same_operation()
	stats2.print_summary()

	// Exit with appropriate code
	if stats1.failed_tests > 0 || stats2.failed_tests > 0 {
		exit(1)
	}
}
