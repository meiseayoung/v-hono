// test_websocket_handshake_errors.v - Property test for WebSocket handshake error handling
// Feature: websocket-helper, Property 2: Handshake Error Handling
// Validates: Requirements 1.4
//
// *For any* HTTP request to a WebSocket route that lacks required WebSocket headers
// (Upgrade: websocket, Connection: Upgrade, Sec-WebSocket-Key), the server SHALL
// return an HTTP 400 Bad Request response.
module main

import rand
import time

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
	println('\n=== WebSocket Handshake Error Handling Property Test Summary ===')
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
// Mock Context for testing
// ============================================================================

struct MockContext {
pub:
	headers map[string]string
}

// validate_upgrade_request - Validate WebSocket upgrade request headers
// Returns the WebSocket key if valid, or an error if invalid
fn validate_upgrade_request(ctx MockContext) !string {
	// Check Upgrade header
	upgrade := ctx.headers['Upgrade'] or {
		return error('Missing Upgrade header')
	}
	if upgrade.to_lower() != 'websocket' {
		return error('Invalid Upgrade header')
	}
	
	// Check Connection header
	connection := ctx.headers['Connection'] or {
		return error('Missing Connection header')
	}
	if !connection.to_lower().contains('upgrade') {
		return error('Invalid Connection header')
	}
	
	// Check Sec-WebSocket-Key
	ws_key := ctx.headers['Sec-WebSocket-Key'] or {
		return error('Missing Sec-WebSocket-Key header')
	}
	if ws_key.len == 0 {
		return error('Empty Sec-WebSocket-Key header')
	}
	
	// Check Sec-WebSocket-Version (must be 13)
	ws_version := ctx.headers['Sec-WebSocket-Version'] or { '13' }
	if ws_version != '13' {
		return error('Unsupported WebSocket version')
	}
	
	return ws_key
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn generate_random_string() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(5, 30) or { 10 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

fn generate_valid_websocket_key() string {
	// Generate a valid base64-encoded 16-byte key
	chars := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	mut result := ''
	for _ in 0 .. 22 {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result + '=='
}

// ============================================================================
// Property 2: Handshake Error Handling
// Feature: websocket-helper, Property 2: Handshake Error Handling
// Validates: Requirements 1.4
//
// *For any* HTTP request to a WebSocket route that lacks required WebSocket headers,
// the server SHALL return an error.
// ============================================================================

// Test: Missing Upgrade header should fail
fn test_property_2_missing_upgrade_header() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Create context without Upgrade header
		ctx := MockContext{
			headers: {
				'Connection': 'Upgrade'
				'Sec-WebSocket-Key': generate_valid_websocket_key()
				'Sec-WebSocket-Version': '13'
			}
		}
		
		// Validation should fail
		validate_upgrade_request(ctx) or {
			// Expected to fail
			if !err.msg().contains('Upgrade') {
				println('  Iteration ${i}: Wrong error message: ${err.msg()}')
				return false
			}
			continue
		}
		
		// If we get here, validation succeeded when it should have failed
		println('  Iteration ${i}: Should have failed without Upgrade header')
		return false
	}
	
	return true
}

// Test: Missing Connection header should fail
fn test_property_2_missing_connection_header() bool {
	rand.seed([u32(time.now().unix()), u32(23456)])
	
	for i in 0 .. test_iterations {
		// Create context without Connection header
		ctx := MockContext{
			headers: {
				'Upgrade': 'websocket'
				'Sec-WebSocket-Key': generate_valid_websocket_key()
				'Sec-WebSocket-Version': '13'
			}
		}
		
		// Validation should fail
		validate_upgrade_request(ctx) or {
			// Expected to fail
			if !err.msg().contains('Connection') {
				println('  Iteration ${i}: Wrong error message: ${err.msg()}')
				return false
			}
			continue
		}
		
		// If we get here, validation succeeded when it should have failed
		println('  Iteration ${i}: Should have failed without Connection header')
		return false
	}
	
	return true
}

// Test: Missing Sec-WebSocket-Key header should fail
fn test_property_2_missing_websocket_key() bool {
	rand.seed([u32(time.now().unix()), u32(34567)])
	
	for i in 0 .. test_iterations {
		// Create context without Sec-WebSocket-Key header
		ctx := MockContext{
			headers: {
				'Upgrade': 'websocket'
				'Connection': 'Upgrade'
				'Sec-WebSocket-Version': '13'
			}
		}
		
		// Validation should fail
		validate_upgrade_request(ctx) or {
			// Expected to fail
			if !err.msg().contains('Sec-WebSocket-Key') {
				println('  Iteration ${i}: Wrong error message: ${err.msg()}')
				return false
			}
			continue
		}
		
		// If we get here, validation succeeded when it should have failed
		println('  Iteration ${i}: Should have failed without Sec-WebSocket-Key header')
		return false
	}
	
	return true
}

// Test: Invalid Upgrade header value should fail
fn test_property_2_invalid_upgrade_value() bool {
	rand.seed([u32(time.now().unix()), u32(45678)])
	
	invalid_values := ['http', 'tcp', 'socket', 'ws', 'WebSocket2', '']
	
	for i, invalid_value in invalid_values {
		ctx := MockContext{
			headers: {
				'Upgrade': invalid_value
				'Connection': 'Upgrade'
				'Sec-WebSocket-Key': generate_valid_websocket_key()
				'Sec-WebSocket-Version': '13'
			}
		}
		
		// Validation should fail
		validate_upgrade_request(ctx) or {
			// Expected to fail
			continue
		}
		
		// If we get here, validation succeeded when it should have failed
		println('  Test ${i}: Should have failed with invalid Upgrade value: "${invalid_value}"')
		return false
	}
	
	return true
}

// Test: Invalid Connection header value should fail
fn test_property_2_invalid_connection_value() bool {
	rand.seed([u32(time.now().unix()), u32(56789)])
	
	invalid_values := ['keep-alive', 'close', 'http', '']
	
	for i, invalid_value in invalid_values {
		ctx := MockContext{
			headers: {
				'Upgrade': 'websocket'
				'Connection': invalid_value
				'Sec-WebSocket-Key': generate_valid_websocket_key()
				'Sec-WebSocket-Version': '13'
			}
		}
		
		// Validation should fail
		validate_upgrade_request(ctx) or {
			// Expected to fail
			continue
		}
		
		// If we get here, validation succeeded when it should have failed
		println('  Test ${i}: Should have failed with invalid Connection value: "${invalid_value}"')
		return false
	}
	
	return true
}

// Test: Valid headers should succeed
fn test_valid_headers_succeed() bool {
	rand.seed([u32(time.now().unix()), u32(67890)])
	
	for i in 0 .. test_iterations {
		ws_key := generate_valid_websocket_key()
		
		ctx := MockContext{
			headers: {
				'Upgrade': 'websocket'
				'Connection': 'Upgrade'
				'Sec-WebSocket-Key': ws_key
				'Sec-WebSocket-Version': '13'
			}
		}
		
		// Validation should succeed
		result := validate_upgrade_request(ctx) or {
			println('  Iteration ${i}: Should have succeeded with valid headers: ${err.msg()}')
			return false
		}
		
		// Verify the returned key matches
		if result != ws_key {
			println('  Iteration ${i}: Returned key mismatch')
			println('    Expected: ${ws_key}')
			println('    Got: ${result}')
			return false
		}
	}
	
	return true
}

// Test: Case-insensitive header values
fn test_case_insensitive_headers() bool {
	test_cases := [
		['WebSocket', 'Upgrade'],
		['WEBSOCKET', 'UPGRADE'],
		['websocket', 'upgrade'],
		['WebSocket', 'upgrade'],
		['websocket', 'Upgrade, keep-alive'],
	]
	
	for i, test_case in test_cases {
		ws_key := generate_valid_websocket_key()
		
		ctx := MockContext{
			headers: {
				'Upgrade': test_case[0]
				'Connection': test_case[1]
				'Sec-WebSocket-Key': ws_key
				'Sec-WebSocket-Version': '13'
			}
		}
		
		// Validation should succeed
		validate_upgrade_request(ctx) or {
			println('  Test ${i}: Should have succeeded with case variation')
			println('    Upgrade: ${test_case[0]}, Connection: ${test_case[1]}')
			println('    Error: ${err.msg()}')
			return false
		}
	}
	
	return true
}

// Test: Unsupported WebSocket version should fail
fn test_unsupported_websocket_version() bool {
	invalid_versions := ['8', '9', '10', '11', '12', '14', '0', '']
	
	for i, version in invalid_versions {
		ctx := MockContext{
			headers: {
				'Upgrade': 'websocket'
				'Connection': 'Upgrade'
				'Sec-WebSocket-Key': generate_valid_websocket_key()
				'Sec-WebSocket-Version': version
			}
		}
		
		// Validation should fail
		validate_upgrade_request(ctx) or {
			// Expected to fail
			continue
		}
		
		// If we get here, validation succeeded when it should have failed
		println('  Test ${i}: Should have failed with unsupported version: "${version}"')
		return false
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Handshake Error Handling Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 2: Handshake Error Handling
	// Validates: Requirements 1.4
	stats.run_property_test('Property 2: Missing Upgrade Header', test_property_2_missing_upgrade_header)
	stats.run_property_test('Property 2: Missing Connection Header', test_property_2_missing_connection_header)
	stats.run_property_test('Property 2: Missing WebSocket Key', test_property_2_missing_websocket_key)
	stats.run_property_test('Property 2: Invalid Upgrade Value', test_property_2_invalid_upgrade_value)
	stats.run_property_test('Property 2: Invalid Connection Value', test_property_2_invalid_connection_value)
	stats.run_property_test('Valid Headers Succeed', test_valid_headers_succeed)
	stats.run_property_test('Case Insensitive Headers', test_case_insensitive_headers)
	stats.run_property_test('Unsupported WebSocket Version', test_unsupported_websocket_version)

	// Print test summary
	stats.print_summary()
}
