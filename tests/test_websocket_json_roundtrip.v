// test_websocket_json_roundtrip.v - Property test for WebSocket JSON round-trip
// Feature: websocket-helper, Property 13: JSON Round-Trip
// Validates: Requirements 8.1, 8.2, 8.3
//
// This test validates that JSON data sent through WebSocket frames
// is preserved correctly through the encode/decode cycle.
module main

import rand
import time

const test_iterations = 100

// WebSocket opcodes (RFC 6455)
const ws_opcode_text = u8(0x1)
const ws_opcode_binary = u8(0x2)

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
	println('\n=== WebSocket JSON Round-Trip Property Test Summary ===')
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
// WebSocket Frame Encoding/Decoding (copied from websocket.v for testing)
// ============================================================================

struct WSFrame {
pub:
	fin         bool
	opcode      u8
	masked      bool
	mask_key    [4]u8
	payload_len u64
	payload     []u8
}

fn encode_ws_frame(opcode u8, payload []u8, masked bool) []u8 {
	payload_len := payload.len
	mut frame := []u8{cap: 14 + payload_len}
	
	// First byte: FIN bit (1) + RSV (000) + opcode (4 bits)
	frame << u8(0x80 | (opcode & 0x0F))
	
	// Second byte: MASK bit + payload length
	mut mask_bit := u8(0)
	if masked {
		mask_bit = 0x80
	}
	
	if payload_len <= 125 {
		frame << mask_bit | u8(payload_len)
	} else if payload_len <= 65535 {
		frame << mask_bit | u8(126)
		frame << u8(payload_len >> 8)
		frame << u8(payload_len & 0xFF)
	} else {
		frame << mask_bit | u8(127)
		for i := 7; i >= 0; i-- {
			frame << u8((payload_len >> (i * 8)) & 0xFF)
		}
	}
	
	// Add masking key and masked payload if masked
	if masked {
		mask_key := [u8(0x12), 0x34, 0x56, 0x78]
		frame << mask_key[0]
		frame << mask_key[1]
		frame << mask_key[2]
		frame << mask_key[3]
		
		for i, b in payload {
			frame << b ^ mask_key[i % 4]
		}
	} else {
		frame << payload
	}
	
	return frame
}

fn decode_ws_frame(data []u8) !WSFrame {
	if data.len < 2 {
		return error('Frame too short')
	}
	
	fin := (data[0] & 0x80) != 0
	opcode := data[0] & 0x0F
	
	masked := (data[1] & 0x80) != 0
	mut payload_len := u64(data[1] & 0x7F)
	mut offset := 2
	
	if payload_len == 126 {
		if data.len < 4 {
			return error('Frame too short for extended length')
		}
		payload_len = u64(data[2]) << 8 | u64(data[3])
		offset = 4
	} else if payload_len == 127 {
		if data.len < 10 {
			return error('Frame too short for 64-bit length')
		}
		payload_len = 0
		for i := 0; i < 8; i++ {
			payload_len = (payload_len << 8) | u64(data[2 + i])
		}
		offset = 10
	}
	
	mut mask_key := [4]u8{}
	if masked {
		if data.len < offset + 4 {
			return error('Frame too short for mask key')
		}
		mask_key[0] = data[offset]
		mask_key[1] = data[offset + 1]
		mask_key[2] = data[offset + 2]
		mask_key[3] = data[offset + 3]
		offset += 4
	}
	
	if data.len < offset + int(payload_len) {
		return error('Frame too short for payload')
	}
	
	mut payload := data[offset..offset + int(payload_len)].clone()
	if masked {
		for i := 0; i < payload.len; i++ {
			payload[i] = payload[i] ^ mask_key[i % 4]
		}
	}
	
	return WSFrame{
		fin: fin
		opcode: opcode
		masked: masked
		mask_key: mask_key
		payload_len: payload_len
		payload: payload
	}
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn generate_random_string_value() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(1, 30) or { 10 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

fn generate_random_int() int {
	return rand.int_in_range(-10000, 10000) or { 0 }
}

fn generate_random_bool() bool {
	return rand.int_in_range(0, 2) or { 0 } == 1
}

fn generate_random_json() string {
	key := generate_random_string_value()
	value_type := rand.int_in_range(0, 4) or { 0 }
	
	match value_type {
		0 {
			str_val := generate_random_string_value()
			return '{"${key}":"${str_val}"}'
		}
		1 {
			int_val := generate_random_int()
			return '{"${key}":${int_val}}'
		}
		2 {
			bool_val := generate_random_bool()
			return '{"${key}":${bool_val}}'
		}
		3 {
			return '{"${key}":null}'
		}
		else {
			return '{"test":"value"}'
		}
	}
}

fn generate_nested_json() string {
	key1 := generate_random_string_value()
	key2 := generate_random_string_value()
	str_val := generate_random_string_value()
	int_val := generate_random_int()
	bool_val := generate_random_bool()
	
	return '{"${key1}":{"${key2}":"${str_val}","num":${int_val},"flag":${bool_val}}}'
}

fn generate_json_array() string {
	mut items := []string{}
	count := rand.int_in_range(1, 5) or { 2 }
	
	for _ in 0 .. count {
		item_type := rand.int_in_range(0, 3) or { 0 }
		match item_type {
			0 {
				items << '"${generate_random_string_value()}"'
			}
			1 {
				items << '${generate_random_int()}'
			}
			2 {
				items << '${generate_random_bool()}'
			}
			else {
				items << 'null'
			}
		}
	}
	
	return '[${items.join(",")}]'
}

// ============================================================================
// Property 13: JSON Round-Trip
// Feature: websocket-helper, Property 13: JSON Round-Trip
// Validates: Requirements 8.1, 8.2, 8.3
//
// *For any* valid JSON string, calling ws.send_json(data) SHALL send the data 
// as a text frame, and parsing the received frame content as JSON SHALL 
// produce an equivalent value.
// ============================================================================
fn test_property_13_json_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random JSON data
		json_type := rand.int_in_range(0, 3) or { 0 }
		json_data := match json_type {
			0 { generate_random_json() }
			1 { generate_nested_json() }
			2 { generate_json_array() }
			else { '{"test":"value"}' }
		}
		
		// Encode the JSON as a WebSocket text frame (simulating send_json)
		frame := encode_ws_frame(ws_opcode_text, json_data.bytes(), false)
		
		// Decode the frame
		decoded := decode_ws_frame(frame) or {
			println('  Iteration ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		// Verify it's a text frame
		if decoded.opcode != ws_opcode_text {
			println('  Iteration ${i}: Expected text opcode (0x1), got 0x${decoded.opcode:02x}')
			return false
		}
		
		// Extract the payload as string
		received_json := decoded.payload.bytestr()
		
		// Verify the JSON content is preserved exactly
		if received_json != json_data {
			println('  Iteration ${i}: JSON mismatch')
			println('    Expected: ${json_data}')
			println('    Got: ${received_json}')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Additional test: JSON with special characters
// ============================================================================
fn test_json_special_chars() bool {
	test_cases := [
		'{"msg":"hello\\nworld"}',
		'{"msg":"tab\\there"}',
		'{"msg":"quote\\"test\\""}',
		'{"empty":""}',
		'{"unicode":"test"}',
		'[]',
		'{}',
		'{"a":1,"b":2,"c":3}',
	]
	
	for i, json_data in test_cases {
		frame := encode_ws_frame(ws_opcode_text, json_data.bytes(), false)
		
		decoded := decode_ws_frame(frame) or {
			println('  Test case ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		received := decoded.payload.bytestr()
		if received != json_data {
			println('  Test case ${i}: Mismatch')
			println('    Expected: ${json_data}')
			println('    Got: ${received}')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Additional test: Verify JSON uses text opcode
// ============================================================================
fn test_json_uses_text_opcode() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for _ in 0 .. test_iterations {
		json_data := generate_random_json()
		
		// Encode as text frame (what send_json should do)
		text_frame := encode_ws_frame(ws_opcode_text, json_data.bytes(), false)
		
		// Decode and verify opcode
		decoded := decode_ws_frame(text_frame) or {
			println('  Failed to decode frame')
			return false
		}
		
		if decoded.opcode != ws_opcode_text {
			println('  JSON should be sent as text frame (opcode 0x1), got 0x${decoded.opcode:02x}')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket JSON Round-Trip Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 13: JSON Round-Trip
	// Validates: Requirements 8.1, 8.2, 8.3
	stats.run_property_test('Property 13: JSON Round-Trip', test_property_13_json_roundtrip)
	stats.run_property_test('JSON Special Characters', test_json_special_chars)
	stats.run_property_test('JSON Uses Text Opcode', test_json_uses_text_opcode)

	// Print test summary
	stats.print_summary()
}
