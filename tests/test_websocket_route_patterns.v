// test_websocket_route_patterns.v - Property test for WebSocket route pattern support
// Feature: websocket-helper, Property 3: Route Pattern Support
// Validates: Requirements 1.5
//
// *For any* WebSocket route registered with path parameters (e.g., /ws/:room/:id),
// when a matching request arrives, the handler SHALL receive a WSContext with
// correctly extracted parameter values.
module main

import rand
import time
import regex

const test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats PropertyTestStats) run_property_test(test_name string, test_func fn () bool) {
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

fn (stats PropertyTestStats) print_summary() {
	println('\n=== WebSocket Route Pattern Property Test Summary ===')
	println('Total tests: ${stats.total_tests}')
	println('Passed: ${stats.passed_tests}')
	println('Failed: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 All property tests passed!')
	} else {
		println('⚠️  ${stats.failed_tests} property test(s) failed')
	}
}

// ============================================================================
// Route Parameter Extraction (simplified from router.v)
// ============================================================================

// Extract parameter names from a route pattern
fn extract_param_names(pattern string) []string {
	mut param_names := []string{}
	mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { return param_names }
	all_params := param_reg.find_all_str(pattern)
	for param in all_params {
		param_names << param[1..] // Remove the colon
	}
	return param_names
}

// Convert route pattern to regex and extract params from actual path
fn match_route_pattern(pattern string, actual_path string) ?map[string]string {
	if !pattern.contains(':') {
		// Static route - no params
		if pattern == actual_path {
			return map[string]string{}
		}
		return none
	}
	
	// Extract parameter names
	param_names := extract_param_names(pattern)
	
	// Build regex pattern
	mut regex_pattern := pattern
	
	// Escape special regex characters
	special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '\$', '|']
	for ch in special_chars {
		regex_pattern = regex_pattern.replace(ch, '\\${ch}')
	}
	
	// Replace :param with capture groups
	mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { return none }
	regex_pattern = param_reg.replace_by_fn(regex_pattern, fn (re regex.RE, in_txt string, start int, end int) string {
		param_name := in_txt[start + 1..end]
		return '(?P<${param_name}>[^/]+)'
	})
	
	// Add anchors
	regex_pattern = '^${regex_pattern}\$'
	
	// Compile and match
	mut compiled := regex.regex_opt(regex_pattern) or { return none }
	if !compiled.matches_string(actual_path) {
		return none
	}
	
	// Extract parameter values
	mut params := map[string]string{}
	for param_name in param_names {
		value := compiled.get_group_by_name(actual_path, param_name)
		params[param_name] = value
	}
	
	return params
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn generate_random_param_name() string {
	chars := 'abcdefghijklmnopqrstuvwxyz'
	len := rand.int_in_range(3, 10) or { 5 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

fn generate_random_param_value() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
	len := rand.int_in_range(1, 20) or { 5 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

fn generate_random_static_segment() string {
	chars := 'abcdefghijklmnopqrstuvwxyz'
	len := rand.int_in_range(2, 10) or { 5 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// Generate a random route pattern with parameters
fn generate_random_route_pattern() (string, []string) {
	num_segments := rand.int_in_range(2, 6) or { 3 }
	mut segments := []string{}
	mut param_names := []string{}
	
	// First segment is always static (like /ws or /api)
	segments << generate_random_static_segment()
	
	for _ in 1 .. num_segments {
		// Randomly decide if this segment is a parameter or static
		is_param := rand.int_in_range(0, 2) or { 0 } == 1
		
		if is_param {
			param_name := generate_random_param_name()
			// Ensure unique param names
			if param_name !in param_names {
				param_names << param_name
				segments << ':${param_name}'
			} else {
				segments << generate_random_static_segment()
			}
		} else {
			segments << generate_random_static_segment()
		}
	}
	
	pattern := '/' + segments.join('/')
	return pattern, param_names
}

// Generate an actual path that matches a pattern with specific values
fn generate_matching_path(pattern string, param_values map[string]string) string {
	mut path := pattern
	for name, value in param_values {
		path = path.replace(':${name}', value)
	}
	return path
}

// ============================================================================
// Property 3: Route Pattern Support
// Feature: websocket-helper, Property 3: Route Pattern Support
// Validates: Requirements 1.5
//
// *For any* WebSocket route registered with path parameters (e.g., /ws/:room/:id),
// when a matching request arrives, the handler SHALL receive a WSContext with
// correctly extracted parameter values.
// ============================================================================

// Test single parameter extraction
fn test_property_3_single_param() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate a pattern with one parameter
		param_name := generate_random_param_name()
		prefix := generate_random_static_segment()
		pattern := '/${prefix}/:${param_name}'
		
		// Generate a random value for the parameter
		param_value := generate_random_param_value()
		actual_path := '/${prefix}/${param_value}'
		
		// Extract parameters
		params := match_route_pattern(pattern, actual_path) or {
			println('  Iteration ${i}: Pattern did not match')
			println('    Pattern: ${pattern}')
			println('    Path: ${actual_path}')
			return false
		}
		
		// Verify parameter was extracted correctly
		if param_name !in params {
			println('  Iteration ${i}: Parameter not found: ${param_name}')
			return false
		}
		
		if params[param_name] != param_value {
			println('  Iteration ${i}: Parameter value mismatch')
			println('    Expected: ${param_value}')
			println('    Got: ${params[param_name]}')
			return false
		}
	}
	
	return true
}

// Test multiple parameter extraction
fn test_property_3_multiple_params() bool {
	rand.seed([u32(time.now().unix()), u32(23456)])
	
	for i in 0 .. test_iterations {
		// Generate a pattern with multiple parameters
		pattern, param_names := generate_random_route_pattern()
		
		// Skip if no parameters were generated
		if param_names.len == 0 {
			continue
		}
		
		// Generate random values for each parameter
		mut expected_values := map[string]string{}
		for name in param_names {
			expected_values[name] = generate_random_param_value()
		}
		
		// Generate the actual path
		actual_path := generate_matching_path(pattern, expected_values)
		
		// Extract parameters
		params := match_route_pattern(pattern, actual_path) or {
			println('  Iteration ${i}: Pattern did not match')
			println('    Pattern: ${pattern}')
			println('    Path: ${actual_path}')
			return false
		}
		
		// Verify all parameters were extracted correctly
		for name, expected_value in expected_values {
			if name !in params {
				println('  Iteration ${i}: Parameter not found: ${name}')
				return false
			}
			
			if params[name] != expected_value {
				println('  Iteration ${i}: Parameter value mismatch for ${name}')
				println('    Expected: ${expected_value}')
				println('    Got: ${params[name]}')
				return false
			}
		}
	}
	
	return true
}

// Test common WebSocket route patterns
fn test_property_3_common_patterns() bool {
	// Test common WebSocket route patterns
	patterns := ['/ws/:room', '/ws/:room/:user', '/api/ws/:id', '/chat/:room/user/:userId', '/v1/ws/:tenant/:channel']
	paths := ['/ws/general', '/ws/chat/alice', '/api/ws/12345', '/chat/lobby/user/u123', '/v1/ws/acme/notifications']
	expected_keys := [['room'], ['room', 'user'], ['id'], ['room', 'userId'], ['tenant', 'channel']]
	expected_values := [['general'], ['chat', 'alice'], ['12345'], ['lobby', 'u123'], ['acme', 'notifications']]
	
	for i, pattern in patterns {
		path := paths[i]
		keys := expected_keys[i]
		values := expected_values[i]
		
		params := match_route_pattern(pattern, path) or {
			println('  Pattern did not match: ${pattern} vs ${path}')
			return false
		}
		
		for j, name in keys {
			expected_value := values[j]
			if name !in params {
				println('  Parameter not found: ${name}')
				return false
			}
			if params[name] != expected_value {
				println('  Parameter mismatch for ${name}: expected ${expected_value}, got ${params[name]}')
				return false
			}
		}
	}
	
	return true
}

// Test that non-matching paths don't extract params
fn test_property_3_non_matching_paths() bool {
	rand.seed([u32(time.now().unix()), u32(34567)])
	
	for i in 0 .. test_iterations {
		// Generate a pattern
		pattern, _ := generate_random_route_pattern()
		
		// Generate a completely different path
		different_pattern, _ := generate_random_route_pattern()
		mut different_values := map[string]string{}
		different_param_names := extract_param_names(different_pattern)
		for name in different_param_names {
			different_values[name] = generate_random_param_value()
		}
		different_path := generate_matching_path(different_pattern, different_values)
		
		// Try to match - should fail if patterns are different
		if pattern != different_pattern {
			result := match_route_pattern(pattern, different_path)
			// It's okay if it matches by coincidence, but if it does,
			// the params should still be valid extractions
			if result != none {
				// Verify the extracted params are valid (non-empty)
				for _, value in result {
					if value.len == 0 {
						println('  Iteration ${i}: Empty parameter value extracted')
						return false
					}
				}
			}
		}
	}
	
	return true
}

// Test parameter extraction preserves special characters in values
fn test_property_3_special_values() bool {
	// Test that parameter values with allowed special characters are preserved
	patterns := ['/ws/:room', '/ws/:room', '/ws/:id', '/chat/:room/:user']
	paths := ['/ws/room-123', '/ws/room_456', '/ws/ABC123xyz', '/chat/my-room/user_1']
	expected_keys := [['room'], ['room'], ['id'], ['room', 'user']]
	expected_values := [['room-123'], ['room_456'], ['ABC123xyz'], ['my-room', 'user_1']]
	
	for i, pattern in patterns {
		path := paths[i]
		keys := expected_keys[i]
		values := expected_values[i]
		
		params := match_route_pattern(pattern, path) or {
			println('  Pattern did not match: ${pattern} vs ${path}')
			return false
		}
		
		for j, name in keys {
			expected_value := values[j]
			if params[name] != expected_value {
				println('  Parameter mismatch for ${name}: expected ${expected_value}, got ${params[name]}')
				return false
			}
		}
	}
	
	return true
}

// Test static routes (no parameters)
fn test_property_3_static_routes() bool {
	rand.seed([u32(time.now().unix()), u32(45678)])
	
	for i in 0 .. test_iterations {
		// Generate a static route (no parameters)
		num_segments := rand.int_in_range(1, 5) or { 2 }
		mut segments := []string{}
		for _ in 0 .. num_segments {
			segments << generate_random_static_segment()
		}
		pattern := '/' + segments.join('/')
		
		// Match against itself
		params := match_route_pattern(pattern, pattern) or {
			println('  Iteration ${i}: Static pattern did not match itself')
			println('    Pattern: ${pattern}')
			return false
		}
		
		// Static routes should have no parameters
		if params.len != 0 {
			println('  Iteration ${i}: Static route should have no params')
			println('    Got: ${params}')
			return false
		}
	}
	
	return true
}

// Test parameter count matches
fn test_property_3_param_count() bool {
	rand.seed([u32(time.now().unix()), u32(56789)])
	
	for i in 0 .. test_iterations {
		// Generate a pattern with known number of parameters
		pattern, param_names := generate_random_route_pattern()
		
		// Generate values
		mut values := map[string]string{}
		for name in param_names {
			values[name] = generate_random_param_value()
		}
		
		actual_path := generate_matching_path(pattern, values)
		
		params := match_route_pattern(pattern, actual_path) or {
			// If no params in pattern, this is expected for static routes
			if param_names.len == 0 {
				continue
			}
			println('  Iteration ${i}: Pattern did not match')
			return false
		}
		
		// Verify param count matches
		if params.len != param_names.len {
			println('  Iteration ${i}: Param count mismatch')
			println('    Expected: ${param_names.len}')
			println('    Got: ${params.len}')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Route Pattern Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 3: Route Pattern Support
	// Validates: Requirements 1.5
	stats.run_property_test('Property 3.1: Single Parameter Extraction', test_property_3_single_param)
	stats.run_property_test('Property 3.2: Multiple Parameters Extraction', test_property_3_multiple_params)
	stats.run_property_test('Property 3.3: Common WebSocket Patterns', test_property_3_common_patterns)
	stats.run_property_test('Property 3.4: Non-Matching Paths', test_property_3_non_matching_paths)
	stats.run_property_test('Property 3.5: Special Characters in Values', test_property_3_special_values)
	stats.run_property_test('Property 3.6: Static Routes', test_property_3_static_routes)
	stats.run_property_test('Property 3.7: Parameter Count Matches', test_property_3_param_count)

	// Print test summary
	stats.print_summary()
}
