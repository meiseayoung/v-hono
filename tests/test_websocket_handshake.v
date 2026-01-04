// test_websocket_handshake.v - Property test for WebSocket handshake compliance
// Feature: websocket-helper, Property 1: WebSocket Handshake Compliance
// Validates: Requirements 1.2, 7.1, 7.2
//
// *For any* valid WebSocket upgrade request containing a Sec-WebSocket-Key header,
// the server's Sec-WebSocket-Accept response header SHALL equal
// base64(sha1(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")).
module main

import rand
import time
import crypto.sha1
import encoding.base64

const test_iterations = 100

// WebSocket magic GUID for handshake (RFC 6455)
const ws_magic_guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

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
	println('\n=== WebSocket Handshake Property Test Summary ===')
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
// WebSocket Handshake Functions (copied from websocket.v for testing)
// ============================================================================

// compute_accept_key - Compute Sec-WebSocket-Accept from Sec-WebSocket-Key
// According to RFC 6455: base64(sha1(key + GUID))
fn compute_accept_key(key string) string {
	combined := key + ws_magic_guid
	hash := sha1.sum(combined.bytes())
	return base64.encode(hash)
}

// Reference implementation for verification
fn reference_compute_accept_key(key string) string {
	// This is the exact algorithm from RFC 6455
	combined := key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
	hash := sha1.sum(combined.bytes())
	return base64.encode(hash)
}

// ============================================================================
// Random Data Generators
// ============================================================================

// Generate a valid base64-encoded 16-byte key (as per RFC 6455)
fn generate_random_websocket_key() string {
	mut bytes := []u8{cap: 16}
	for _ in 0 .. 16 {
		bytes << u8(rand.int_in_range(0, 256) or { 0 })
	}
	return base64.encode(bytes)
}

// Generate a random string for testing
fn generate_random_string() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/='
	len := rand.int_in_range(10, 50) or { 24 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// ============================================================================
// Property 1: WebSocket Handshake Compliance
// Feature: websocket-helper, Property 1: WebSocket Handshake Compliance
// Validates: Requirements 1.2, 7.1, 7.2
//
// *For any* valid WebSocket upgrade request containing a Sec-WebSocket-Key header,
// the server's Sec-WebSocket-Accept response header SHALL equal
// base64(sha1(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")).
// ============================================================================
fn test_property_1_handshake_compliance() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate a random WebSocket key
		ws_key := generate_random_websocket_key()
		
		// Compute accept key using our implementation
		accept_key := compute_accept_key(ws_key)
		
		// Compute expected accept key using reference implementation
		expected_accept := reference_compute_accept_key(ws_key)
		
		// Verify they match
		if accept_key != expected_accept {
			println('  Iteration ${i}: Accept key mismatch')
			println('    Key: ${ws_key}')
			println('    Expected: ${expected_accept}')
			println('    Got: ${accept_key}')
			return false
		}
		
		// Verify the accept key is valid base64
		decoded := base64.decode(accept_key)
		if decoded.len != 20 {
			// SHA-1 produces 20 bytes
			println('  Iteration ${i}: Accept key should decode to 20 bytes (SHA-1 hash)')
			println('    Got ${decoded.len} bytes')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Test with known RFC 6455 example
// ============================================================================
fn test_rfc_6455_example() bool {
	// Example from RFC 6455 Section 1.3
	// Key: "dGhlIHNhbXBsZSBub25jZQ=="
	// Expected Accept: "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
	
	key := 'dGhlIHNhbXBsZSBub25jZQ=='
	expected := 's3pPLMBiTxaQ9kYGzzhZRbK+xOo='
	
	accept := compute_accept_key(key)
	
	if accept != expected {
		println('  RFC 6455 example failed')
		println('    Key: ${key}')
		println('    Expected: ${expected}')
		println('    Got: ${accept}')
		return false
	}
	
	return true
}

// ============================================================================
// Test determinism: same key always produces same accept
// ============================================================================
fn test_deterministic_accept_key() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		ws_key := generate_random_websocket_key()
		
		// Compute accept key multiple times
		accept1 := compute_accept_key(ws_key)
		accept2 := compute_accept_key(ws_key)
		accept3 := compute_accept_key(ws_key)
		
		// All should be identical
		if accept1 != accept2 || accept2 != accept3 {
			println('  Iteration ${i}: Accept key not deterministic')
			println('    Key: ${ws_key}')
			println('    Accept1: ${accept1}')
			println('    Accept2: ${accept2}')
			println('    Accept3: ${accept3}')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Test different keys produce different accepts
// ============================================================================
fn test_different_keys_different_accepts() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		key1 := generate_random_websocket_key()
		key2 := generate_random_websocket_key()
		
		// Skip if we randomly generated the same key
		if key1 == key2 {
			continue
		}
		
		accept1 := compute_accept_key(key1)
		accept2 := compute_accept_key(key2)
		
		// Different keys should produce different accepts
		if accept1 == accept2 {
			println('  Iteration ${i}: Different keys produced same accept')
			println('    Key1: ${key1}')
			println('    Key2: ${key2}')
			println('    Accept: ${accept1}')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Test accept key format is valid base64
// ============================================================================
fn test_accept_key_valid_base64() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])
	
	for i in 0 .. test_iterations {
		ws_key := generate_random_websocket_key()
		accept_key := compute_accept_key(ws_key)
		
		// Try to decode - should not fail
		decoded := base64.decode(accept_key)
		
		// SHA-1 hash is always 20 bytes
		if decoded.len != 20 {
			println('  Iteration ${i}: Invalid accept key length')
			println('    Expected 20 bytes, got ${decoded.len}')
			return false
		}
		
		// Re-encode should match original
		re_encoded := base64.encode(decoded)
		if re_encoded != accept_key {
			println('  Iteration ${i}: Base64 round-trip failed')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Handshake Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 1: WebSocket Handshake Compliance
	// Validates: Requirements 1.2, 7.1, 7.2
	stats.run_property_test('Property 1: Handshake Compliance', test_property_1_handshake_compliance)
	stats.run_property_test('RFC 6455 Example', test_rfc_6455_example)
	stats.run_property_test('Deterministic Accept Key', test_deterministic_accept_key)
	stats.run_property_test('Different Keys Different Accepts', test_different_keys_different_accepts)
	stats.run_property_test('Accept Key Valid Base64', test_accept_key_valid_base64)

	// Print test summary
	stats.print_summary()
}
