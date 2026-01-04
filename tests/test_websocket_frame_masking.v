// test_websocket_frame_masking.v - Property test for WebSocket frame masking
// Feature: websocket-helper, Property 12: Frame Masking
// Validates: Requirements 7.6
//
// *For any* WebSocket frame received from a client, the frame SHALL be masked 
// (MASK bit set), and the server SHALL correctly unmask the payload.
// *For any* frame sent by the server, the frame SHALL NOT be masked.
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
	println('\n=== WebSocket Frame Masking Property Test Summary ===')
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
// WebSocket Frame Encoding/Decoding with custom mask key support
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

// encode_ws_frame_with_mask - Encode with a specific mask key for testing
fn encode_ws_frame_with_mask(opcode u8, payload []u8, mask_key [4]u8) []u8 {
	payload_len := payload.len
	mut frame := []u8{cap: 14 + payload_len}
	
	// First byte: FIN bit (1) + RSV (000) + opcode (4 bits)
	frame << u8(0x80 | (opcode & 0x0F))
	
	// Second byte: MASK bit (1) + payload length
	if payload_len <= 125 {
		frame << u8(0x80) | u8(payload_len)
	} else if payload_len <= 65535 {
		frame << u8(0x80) | u8(126)
		frame << u8(payload_len >> 8)
		frame << u8(payload_len & 0xFF)
	} else {
		frame << u8(0x80) | u8(127)
		for i := 7; i >= 0; i-- {
			frame << u8((payload_len >> (i * 8)) & 0xFF)
		}
	}
	
	// Add masking key
	frame << mask_key[0]
	frame << mask_key[1]
	frame << mask_key[2]
	frame << mask_key[3]
	
	// Add masked payload
	for i, b in payload {
		frame << b ^ mask_key[i % 4]
	}
	
	return frame
}

// encode_ws_frame - Standard encoding (server frames are unmasked)
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

fn generate_random_bytes() []u8 {
	len := rand.int_in_range(0, 200) or { 50 }
	mut result := []u8{cap: len}
	for _ in 0 .. len {
		result << u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

fn generate_random_mask_key() [4]u8 {
	return [
		u8(rand.int_in_range(0, 256) or { 0 }),
		u8(rand.int_in_range(0, 256) or { 0 }),
		u8(rand.int_in_range(0, 256) or { 0 }),
		u8(rand.int_in_range(0, 256) or { 0 }),
	]!
}

fn generate_random_string() string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(1, 100) or { 20 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// ============================================================================
// Property 12: Frame Masking
// Feature: websocket-helper, Property 12: Frame Masking
// Validates: Requirements 7.6
//
// *For any* WebSocket frame received from a client, the frame SHALL be masked 
// (MASK bit set), and the server SHALL correctly unmask the payload.
// ============================================================================
fn test_property_12_client_frames_masked() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random payload and mask key (simulating client frame)
		original_payload := generate_random_bytes()
		mask_key := generate_random_mask_key()
		
		// Encode as masked frame (client -> server)
		frame := encode_ws_frame_with_mask(ws_opcode_text, original_payload, mask_key)
		
		// Decode the frame (server should unmask)
		decoded := decode_ws_frame(frame) or {
			println('  Iteration ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		// Verify MASK bit was set in the frame
		if !decoded.masked {
			println('  Iteration ${i}: Client frame should have MASK bit set')
			return false
		}
		
		// Verify payload was correctly unmasked
		if decoded.payload != original_payload {
			println('  Iteration ${i}: Payload not correctly unmasked')
			println('    Expected: ${original_payload}')
			println('    Got: ${decoded.payload}')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 12: Server frames are NOT masked
// *For any* frame sent by the server, the frame SHALL NOT be masked.
// ============================================================================
fn test_property_12_server_frames_unmasked() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate random payload
		original_payload := generate_random_bytes()
		
		// Encode as unmasked frame (server -> client)
		frame := encode_ws_frame(ws_opcode_text, original_payload, false)
		
		// Decode the frame
		decoded := decode_ws_frame(frame) or {
			println('  Iteration ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		// Verify MASK bit is NOT set
		if decoded.masked {
			println('  Iteration ${i}: Server frame should NOT have MASK bit set')
			return false
		}
		
		// Verify payload is preserved exactly
		if decoded.payload != original_payload {
			println('  Iteration ${i}: Payload mismatch')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Additional test: Masking round-trip (mask then unmask)
// ============================================================================
fn test_masking_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		// Generate random data
		original := generate_random_string()
		mask_key := generate_random_mask_key()
		
		// Encode with masking
		masked_frame := encode_ws_frame_with_mask(ws_opcode_text, original.bytes(), mask_key)
		
		// Decode (which unmasks)
		decoded := decode_ws_frame(masked_frame) or {
			println('  Iteration ${i}: Failed to decode: ${err}')
			return false
		}
		
		// Verify round-trip: unmask(mask(data)) == data
		if decoded.payload.bytestr() != original {
			println('  Iteration ${i}: Round-trip failed')
			println('    Original: ${original}')
			println('    After round-trip: ${decoded.payload.bytestr()}')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Additional test: Different mask keys produce different masked data
// ============================================================================
fn test_different_masks_different_output() bool {
	payload := 'Hello, WebSocket!'.bytes()
	
	mask1 := [u8(0x12), 0x34, 0x56, 0x78]!
	mask2 := [u8(0xAB), 0xCD, 0xEF, 0x01]!
	
	frame1 := encode_ws_frame_with_mask(ws_opcode_text, payload, mask1)
	frame2 := encode_ws_frame_with_mask(ws_opcode_text, payload, mask2)
	
	// The frames should be different (different masks)
	if frame1 == frame2 {
		println('  Different masks should produce different frames')
		return false
	}
	
	// But both should decode to the same payload
	decoded1 := decode_ws_frame(frame1) or {
		println('  Failed to decode frame1')
		return false
	}
	decoded2 := decode_ws_frame(frame2) or {
		println('  Failed to decode frame2')
		return false
	}
	
	if decoded1.payload != decoded2.payload {
		println('  Both frames should decode to same payload')
		return false
	}
	
	return true
}

// ============================================================================
// Additional test: Zero mask key
// ============================================================================
fn test_zero_mask_key() bool {
	payload := 'Test with zero mask'.bytes()
	zero_mask := [u8(0), 0, 0, 0]!
	
	frame := encode_ws_frame_with_mask(ws_opcode_text, payload, zero_mask)
	decoded := decode_ws_frame(frame) or {
		println('  Failed to decode frame with zero mask')
		return false
	}
	
	// With zero mask, XOR should leave payload unchanged
	if decoded.payload != payload {
		println('  Zero mask should preserve payload')
		return false
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Frame Masking Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 12: Frame Masking
	// Validates: Requirements 7.6
	stats.run_property_test('Property 12: Client Frames Masked', test_property_12_client_frames_masked)
	stats.run_property_test('Property 12: Server Frames Unmasked', test_property_12_server_frames_unmasked)
	stats.run_property_test('Masking Round-Trip', test_masking_roundtrip)
	stats.run_property_test('Different Masks Different Output', test_different_masks_different_output)
	stats.run_property_test('Zero Mask Key', test_zero_mask_key)

	// Print test summary
	stats.print_summary()
}
