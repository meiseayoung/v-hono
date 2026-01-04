// test_websocket_close_handshake.v - Property test for WebSocket close handshake
// Feature: websocket-helper, Property 6: Close Handshake
// Validates: Requirements 3.3, 7.5
//
// *For any* call to `ws.close(code, reason)`, the server SHALL send a close frame 
// with the specified status code and reason, and transition the connection state to `closing`.
module main

import rand
import time

const test_iterations = 100

// WebSocket opcodes (RFC 6455)
const ws_opcode_close = u8(0x8)

// WebSocket close codes (RFC 6455)
const ws_close_normal = 1000
const ws_close_going_away = 1001
const ws_close_protocol_error = 1002
const ws_close_unsupported_data = 1003
const ws_close_invalid_payload = 1007
const ws_close_policy_violation = 1008
const ws_close_message_too_big = 1009
const ws_close_internal_error = 1011

// WebSocket Ready State
enum WSReadyState {
	connecting = 0
	open       = 1
	closing    = 2
	closed     = 3
}

struct WSCloseEvent {
	code      int
	reason    string
	was_clean bool
}

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
	println('\n=== WebSocket Close Handshake Property Test Summary ===')
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
// Close Frame Functions (copied from websocket.v for testing)
// ============================================================================

fn encode_ws_frame(opcode u8, payload []u8, masked bool) []u8 {
	payload_len := payload.len
	mut frame := []u8{cap: 14 + payload_len}
	
	frame << u8(0x80 | (opcode & 0x0F))
	
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

fn build_close_frame(code int, reason string) []u8 {
	mut payload := []u8{cap: 2 + reason.len}
	payload << u8(code >> 8)
	payload << u8(code & 0xFF)
	if reason.len > 0 {
		payload << reason.bytes()
	}
	
	return encode_ws_frame(ws_opcode_close, payload, false)
}

fn parse_close_frame(payload []u8) (int, string) {
	mut code := ws_close_normal
	mut reason := ''
	
	if payload.len >= 2 {
		code = int(payload[0]) << 8 | int(payload[1])
		if payload.len > 2 {
			reason = payload[2..].bytestr()
		}
	}
	
	return code, reason
}

fn decode_ws_frame(data []u8) !(bool, u8, []u8) {
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
	
	return fin, opcode, payload
}

fn is_valid_close_code(code int) bool {
	if code < 1000 {
		return false
	}
	if code >= 1004 && code <= 1006 {
		return false
	}
	if code >= 1012 && code <= 2999 {
		return false
	}
	if code > 4999 {
		return false
	}
	return true
}

// ============================================================================
// Mock WSContext for testing
// ============================================================================

struct MockWSContext {
mut:
	ready_state   WSReadyState
	sent_frames   [][]u8
	close_called  bool
	close_code    int
	close_reason  string
}

fn create_mock_ws_context() MockWSContext {
	return MockWSContext{
		ready_state: .open
		sent_frames: [][]u8{}
		close_called: false
	}
}

fn (mut ws MockWSContext) close(code int, reason string) {
	if ws.ready_state == .closed || ws.ready_state == .closing {
		return
	}
	
	ws.ready_state = .closing
	ws.close_called = true
	ws.close_code = code
	ws.close_reason = reason
	
	// Build and "send" close frame
	close_frame := build_close_frame(code, reason)
	ws.sent_frames << close_frame
}

fn (mut ws MockWSContext) handle_close_frame(payload []u8) WSCloseEvent {
	code, reason := parse_close_frame(payload)
	was_clean := is_valid_close_code(code)
	
	if ws.ready_state == .open {
		ws.ready_state = .closing
		close_frame := build_close_frame(code, reason)
		ws.sent_frames << close_frame
	}
	
	ws.ready_state = .closed
	
	return WSCloseEvent{
		code: code
		reason: reason
		was_clean: was_clean
	}
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn get_valid_close_codes() []int {
	return [
		ws_close_normal,
		ws_close_going_away,
		ws_close_protocol_error,
		ws_close_unsupported_data,
		ws_close_invalid_payload,
		ws_close_policy_violation,
		ws_close_message_too_big,
		ws_close_internal_error,
		3000, 3500, 3999, // Library/framework codes
		4000, 4500, 4999, // Private use codes
	]
}

fn generate_random_close_code() int {
	codes := get_valid_close_codes()
	idx := rand.int_in_range(0, codes.len) or { 0 }
	return codes[idx]
}

fn generate_random_reason() string {
	reasons := [
		'',
		'Normal closure',
		'Server shutting down',
		'Protocol error detected',
		'Invalid data received',
		'Connection timeout',
		'User disconnected',
		'Session expired',
	]
	idx := rand.int_in_range(0, reasons.len) or { 0 }
	return reasons[idx]
}

// ============================================================================
// Property 6: Close Handshake
// Feature: websocket-helper, Property 6: Close Handshake
// Validates: Requirements 3.3, 7.5
// ============================================================================

fn test_property_6_close_sends_frame_with_code_and_reason() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		code := generate_random_close_code()
		reason := generate_random_reason()
		
		mut ws := create_mock_ws_context()
		ws.close(code, reason)
		
		// Verify a close frame was sent
		if ws.sent_frames.len != 1 {
			println('  Iteration ${i}: Expected 1 sent frame, got ${ws.sent_frames.len}')
			return false
		}
		
		// Decode the sent frame
		fin, opcode, payload := decode_ws_frame(ws.sent_frames[0]) or {
			println('  Iteration ${i}: Failed to decode close frame: ${err}')
			return false
		}
		
		// Verify it's a close frame
		if opcode != ws_opcode_close {
			println('  Iteration ${i}: Expected close opcode (0x8), got 0x${opcode:02x}')
			return false
		}
		
		// Verify FIN bit is set
		if !fin {
			println('  Iteration ${i}: FIN bit should be set for close frame')
			return false
		}
		
		// Parse the close frame payload
		parsed_code, parsed_reason := parse_close_frame(payload)
		
		// Verify code matches
		if parsed_code != code {
			println('  Iteration ${i}: Expected code ${code}, got ${parsed_code}')
			return false
		}
		
		// Verify reason matches
		if parsed_reason != reason {
			println('  Iteration ${i}: Expected reason "${reason}", got "${parsed_reason}"')
			return false
		}
	}
	return true
}

fn test_property_6_close_transitions_to_closing_state() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		code := generate_random_close_code()
		reason := generate_random_reason()
		
		mut ws := create_mock_ws_context()
		
		// Verify initial state is open
		if ws.ready_state != .open {
			println('  Iteration ${i}: Initial state should be open')
			return false
		}
		
		ws.close(code, reason)
		
		// Verify state transitioned to closing
		if ws.ready_state != .closing {
			println('  Iteration ${i}: State should be closing after close(), got ${ws.ready_state}')
			return false
		}
	}
	return true
}

fn test_property_6_close_is_idempotent() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		code := generate_random_close_code()
		reason := generate_random_reason()
		
		mut ws := create_mock_ws_context()
		
		// First close
		ws.close(code, reason)
		frames_after_first := ws.sent_frames.len
		state_after_first := ws.ready_state
		
		// Second close (should be no-op)
		ws.close(code, reason)
		
		// Verify no additional frames were sent
		if ws.sent_frames.len != frames_after_first {
			println('  Iteration ${i}: Second close should not send additional frames')
			return false
		}
		
		// Verify state didn't change
		if ws.ready_state != state_after_first {
			println('  Iteration ${i}: State should remain ${state_after_first} after second close')
			return false
		}
	}
	return true
}

fn test_property_6_handle_incoming_close_frame() bool {
	rand.seed([u32(time.now().unix()), u32(77777)])
	
	for i in 0 .. test_iterations {
		code := generate_random_close_code()
		reason := generate_random_reason()
		
		// Build incoming close frame payload
		mut payload := []u8{cap: 2 + reason.len}
		payload << u8(code >> 8)
		payload << u8(code & 0xFF)
		if reason.len > 0 {
			payload << reason.bytes()
		}
		
		mut ws := create_mock_ws_context()
		
		// Handle incoming close frame
		close_event := ws.handle_close_frame(payload)
		
		// Verify close event has correct code
		if close_event.code != code {
			println('  Iteration ${i}: Close event code should be ${code}, got ${close_event.code}')
			return false
		}
		
		// Verify close event has correct reason
		if close_event.reason != reason {
			println('  Iteration ${i}: Close event reason should be "${reason}", got "${close_event.reason}"')
			return false
		}
		
		// Verify was_clean is correct
		expected_clean := is_valid_close_code(code)
		if close_event.was_clean != expected_clean {
			println('  Iteration ${i}: was_clean should be ${expected_clean}, got ${close_event.was_clean}')
			return false
		}
		
		// Verify state is closed
		if ws.ready_state != .closed {
			println('  Iteration ${i}: State should be closed after handling close frame')
			return false
		}
		
		// Verify echo close frame was sent
		if ws.sent_frames.len != 1 {
			println('  Iteration ${i}: Should send echo close frame')
			return false
		}
	}
	return true
}

fn test_property_6_valid_close_codes() bool {
	// Test all standard valid close codes
	valid_codes := [
		ws_close_normal,
		ws_close_going_away,
		ws_close_protocol_error,
		ws_close_unsupported_data,
		ws_close_invalid_payload,
		ws_close_policy_violation,
		ws_close_message_too_big,
		ws_close_internal_error,
	]
	
	for code in valid_codes {
		if !is_valid_close_code(code) {
			println('  Standard code ${code} should be valid')
			return false
		}
	}
	
	// Test library/framework codes (3000-3999)
	for code in [3000, 3500, 3999] {
		if !is_valid_close_code(code) {
			println('  Library code ${code} should be valid')
			return false
		}
	}
	
	// Test private use codes (4000-4999)
	for code in [4000, 4500, 4999] {
		if !is_valid_close_code(code) {
			println('  Private code ${code} should be valid')
			return false
		}
	}
	
	// Test invalid codes
	invalid_codes := [0, 999, 1004, 1005, 1006, 1012, 2000, 2999, 5000, 6000]
	for code in invalid_codes {
		if is_valid_close_code(code) {
			println('  Code ${code} should be invalid')
			return false
		}
	}
	
	return true
}

fn test_close_frame_round_trip() bool {
	rand.seed([u32(time.now().unix()), u32(55555)])
	
	for i in 0 .. test_iterations {
		code := generate_random_close_code()
		reason := generate_random_reason()
		
		// Build close frame
		frame := build_close_frame(code, reason)
		
		// Decode frame
		_, opcode, payload := decode_ws_frame(frame) or {
			println('  Iteration ${i}: Failed to decode frame: ${err}')
			return false
		}
		
		if opcode != ws_opcode_close {
			println('  Iteration ${i}: Expected close opcode')
			return false
		}
		
		// Parse payload
		parsed_code, parsed_reason := parse_close_frame(payload)
		
		// Verify round-trip
		if parsed_code != code {
			println('  Iteration ${i}: Code mismatch: ${code} vs ${parsed_code}')
			return false
		}
		if parsed_reason != reason {
			println('  Iteration ${i}: Reason mismatch: "${reason}" vs "${parsed_reason}"')
			return false
		}
	}
	return true
}

fn main() {
	println('🚀 Starting WebSocket Close Handshake Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 6: Close Handshake
	// Validates: Requirements 3.3, 7.5
	stats.run_property_test('Property 6: Close Sends Frame with Code and Reason', test_property_6_close_sends_frame_with_code_and_reason)
	stats.run_property_test('Property 6: Close Transitions to Closing State', test_property_6_close_transitions_to_closing_state)
	stats.run_property_test('Property 6: Close is Idempotent', test_property_6_close_is_idempotent)
	stats.run_property_test('Property 6: Handle Incoming Close Frame', test_property_6_handle_incoming_close_frame)
	stats.run_property_test('Property 6: Valid Close Codes', test_property_6_valid_close_codes)
	stats.run_property_test('Close Frame Round Trip', test_close_frame_round_trip)

	// Print test summary
	stats.print_summary()
}
