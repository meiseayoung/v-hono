// test_websocket_frame_encoding.v - Property test for WebSocket frame encoding
// Feature: websocket-helper, Property 5: Frame Encoding
// Validates: Requirements 3.1, 3.2, 7.3
//
// *For any* string data sent via ws.send(data), the resulting WebSocket frame 
// SHALL have opcode 0x1 (text) and contain the exact string bytes.
// *For any* binary data sent via ws.send_bytes(data), the resulting frame 
// SHALL have opcode 0x2 (binary) and contain the exact byte sequence.
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
	println('\n=== WebSocket Frame Encoding Property Test Summary ===')
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

fn generate_random_string() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !@#$%^&*()_+-=[]{}|;:,.<>?'
	len := rand.int_in_range(0, 200) or { 50 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

fn generate_random_bytes() []u8 {
	len := rand.int_in_range(0, 200) or { 50 }
	mut result := []u8{cap: len}
	for _ in 0 .. len {
		result << u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

fn generate_large_payload() []u8 {
	// Generate payload between 126 and 1000 bytes to test extended length encoding
	len := rand.int_in_range(126, 1000) or { 200 }
	mut result := []u8{cap: len}
	for _ in 0 .. len {
		result << u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

// ============================================================================
// Property 5: Frame Encoding
// Feature: websocket-helper, Property 5: Frame Encoding
// Validates: Requirements 3.1, 3.2, 7.3
//
// *For any* string data sent via ws.send(data), the resulting WebSocket frame 
// SHALL have opcode 0x1 (text) and contain the exact string bytes.
// ============================================================================
fn test_property_5_text_frame_encoding() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random string data
		text_data := generate_random_string()
		
		// Encode as text frame (simulating ws.send(data))
		frame := encode_ws_frame(ws_opcode_text, text_data.bytes(), false)
		
		// Decode the frame
		decoded := decode_ws_frame(frame) or {
			println('  Iteration ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		// Verify opcode is text (0x1)
		if decoded.opcode != ws_opcode_text {
			println('  Iteration ${i}: Expected text opcode (0x1), got 0x${decoded.opcode:02x}')
			return false
		}
		
		// Verify payload contains exact string bytes
		received := decoded.payload.bytestr()
		if received != text_data {
			println('  Iteration ${i}: Payload mismatch')
			println('    Expected: ${text_data}')
			println('    Got: ${received}')
			return false
		}
		
		// Verify FIN bit is set (single frame message)
		if !decoded.fin {
			println('  Iteration ${i}: FIN bit should be set')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 5: Frame Encoding (Binary)
// *For any* binary data sent via ws.send_bytes(data), the resulting frame 
// SHALL have opcode 0x2 (binary) and contain the exact byte sequence.
// ============================================================================
fn test_property_5_binary_frame_encoding() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate random binary data
		binary_data := generate_random_bytes()
		
		// Encode as binary frame (simulating ws.send_bytes(data))
		frame := encode_ws_frame(ws_opcode_binary, binary_data, false)
		
		// Decode the frame
		decoded := decode_ws_frame(frame) or {
			println('  Iteration ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		// Verify opcode is binary (0x2)
		if decoded.opcode != ws_opcode_binary {
			println('  Iteration ${i}: Expected binary opcode (0x2), got 0x${decoded.opcode:02x}')
			return false
		}
		
		// Verify payload contains exact byte sequence
		if decoded.payload != binary_data {
			println('  Iteration ${i}: Binary payload mismatch')
			println('    Expected length: ${binary_data.len}')
			println('    Got length: ${decoded.payload.len}')
			return false
		}
		
		// Verify FIN bit is set
		if !decoded.fin {
			println('  Iteration ${i}: FIN bit should be set')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Additional test: Extended payload length encoding (126-65535 bytes)
// ============================================================================
fn test_extended_payload_length() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. 20 {
		// Generate payload that requires extended length encoding
		payload := generate_large_payload()
		
		// Encode as text frame
		frame := encode_ws_frame(ws_opcode_text, payload, false)
		
		// Decode the frame
		decoded := decode_ws_frame(frame) or {
			println('  Iteration ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		// Verify payload is preserved
		if decoded.payload != payload {
			println('  Iteration ${i}: Payload mismatch for extended length')
			println('    Expected length: ${payload.len}')
			println('    Got length: ${decoded.payload.len}')
			return false
		}
		
		// Verify payload length is correctly decoded
		if decoded.payload_len != u64(payload.len) {
			println('  Iteration ${i}: Payload length mismatch')
			println('    Expected: ${payload.len}')
			println('    Got: ${decoded.payload_len}')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Additional test: Empty payload handling
// ============================================================================
fn test_empty_payload() bool {
	// Test empty text frame
	empty_text := ''
	text_frame := encode_ws_frame(ws_opcode_text, empty_text.bytes(), false)
	decoded_text := decode_ws_frame(text_frame) or {
		println('  Failed to decode empty text frame: ${err}')
		return false
	}
	if decoded_text.payload.len != 0 {
		println('  Empty text frame should have empty payload')
		return false
	}
	
	// Test empty binary frame
	empty_binary := []u8{}
	binary_frame := encode_ws_frame(ws_opcode_binary, empty_binary, false)
	decoded_binary := decode_ws_frame(binary_frame) or {
		println('  Failed to decode empty binary frame: ${err}')
		return false
	}
	if decoded_binary.payload.len != 0 {
		println('  Empty binary frame should have empty payload')
		return false
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Frame Encoding Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 5: Frame Encoding
	// Validates: Requirements 3.1, 3.2, 7.3
	stats.run_property_test('Property 5: Text Frame Encoding', test_property_5_text_frame_encoding)
	stats.run_property_test('Property 5: Binary Frame Encoding', test_property_5_binary_frame_encoding)
	stats.run_property_test('Extended Payload Length', test_extended_payload_length)
	stats.run_property_test('Empty Payload Handling', test_empty_payload)

	// Print test summary
	stats.print_summary()
}
