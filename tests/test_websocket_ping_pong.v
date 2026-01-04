// test_websocket_ping_pong.v - Property test for WebSocket ping/pong handling
// Feature: websocket-helper, Property 11: Ping/Pong Handling
// Validates: Requirements 7.4
//
// *For any* ping frame received from a client, the server SHALL respond with 
// a pong frame containing the same payload data.
module main

import rand
import time

const test_iterations = 100

// WebSocket opcodes (RFC 6455)
const ws_opcode_ping = u8(0x9)
const ws_opcode_pong = u8(0xA)

// WebSocket Ready State
enum WSReadyState {
	connecting = 0
	open       = 1
	closing    = 2
	closed     = 3
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
	println('\n=== WebSocket Ping/Pong Property Test Summary ===')
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
// Frame Encoding/Decoding (copied from websocket.v for testing)
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

// ============================================================================
// Mock WSContext for testing
// ============================================================================

struct MockWSContext {
mut:
	ready_state        WSReadyState
	sent_frames        [][]u8
	ping_interval      int
	last_ping_sent     i64
	last_pong_received i64
	pong_timeout       int
	awaiting_pong      bool
}

fn create_mock_ws_context() MockWSContext {
	return MockWSContext{
		ready_state: .open
		sent_frames: [][]u8{}
		ping_interval: 30000
		pong_timeout: 10000
	}
}

fn (mut ws MockWSContext) send_ping(payload []u8) ![]u8 {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	if payload.len > 125 {
		return error('Ping payload too large (max 125 bytes)')
	}
	
	frame := encode_ws_frame(ws_opcode_ping, payload, false)
	ws.sent_frames << frame
	ws.last_ping_sent = time.now().unix()
	ws.awaiting_pong = true
	
	return frame
}

fn (mut ws MockWSContext) handle_ping(payload []u8) ![]u8 {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	// Build pong frame with same payload
	pong_frame := encode_ws_frame(ws_opcode_pong, payload, false)
	ws.sent_frames << pong_frame
	
	return pong_frame
}

fn (mut ws MockWSContext) handle_pong(payload []u8) {
	ws.last_pong_received = time.now().unix()
	ws.awaiting_pong = false
}

fn (ws MockWSContext) is_pong_timeout() bool {
	if !ws.awaiting_pong {
		return false
	}
	
	if ws.pong_timeout <= 0 {
		return false
	}
	
	elapsed := time.now().unix() - ws.last_ping_sent
	timeout_seconds := ws.pong_timeout / 1000
	
	return elapsed > timeout_seconds
}

fn (ws MockWSContext) should_send_ping() bool {
	if ws.ping_interval <= 0 {
		return false
	}
	
	if ws.ready_state != .open {
		return false
	}
	
	if ws.awaiting_pong {
		return false
	}
	
	elapsed := time.now().unix() - ws.last_ping_sent
	interval_seconds := ws.ping_interval / 1000
	
	return elapsed >= interval_seconds
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn generate_random_ping_payload() []u8 {
	// Ping payload must be 125 bytes or less per RFC 6455
	len := rand.int_in_range(0, 126) or { 50 }
	mut result := []u8{cap: len}
	for _ in 0 .. len {
		result << u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

fn generate_small_payload() []u8 {
	len := rand.int_in_range(0, 20) or { 10 }
	mut result := []u8{cap: len}
	for _ in 0 .. len {
		result << u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

// ============================================================================
// Property 11: Ping/Pong Handling
// Feature: websocket-helper, Property 11: Ping/Pong Handling
// Validates: Requirements 7.4
//
// *For any* ping frame received from a client, the server SHALL respond with 
// a pong frame containing the same payload data.
// ============================================================================

fn test_property_11_pong_echoes_ping_payload() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		ping_payload := generate_random_ping_payload()
		
		mut ws := create_mock_ws_context()
		
		// Handle incoming ping
		pong_frame := ws.handle_ping(ping_payload) or {
			println('  Iteration ${i}: Failed to handle ping: ${err}')
			return false
		}
		
		// Decode the pong frame
		fin, opcode, pong_payload := decode_ws_frame(pong_frame) or {
			println('  Iteration ${i}: Failed to decode pong frame: ${err}')
			return false
		}
		
		// Verify it's a pong frame
		if opcode != ws_opcode_pong {
			println('  Iteration ${i}: Expected pong opcode (0xA), got 0x${opcode:02x}')
			return false
		}
		
		// Verify FIN bit is set
		if !fin {
			println('  Iteration ${i}: FIN bit should be set for pong frame')
			return false
		}
		
		// Verify payload matches ping payload
		if pong_payload != ping_payload {
			println('  Iteration ${i}: Pong payload should match ping payload')
			println('    Ping payload length: ${ping_payload.len}')
			println('    Pong payload length: ${pong_payload.len}')
			return false
		}
	}
	return true
}

fn test_property_11_ping_sends_frame() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		payload := generate_small_payload()
		
		mut ws := create_mock_ws_context()
		
		// Send ping
		ping_frame := ws.send_ping(payload) or {
			println('  Iteration ${i}: Failed to send ping: ${err}')
			return false
		}
		
		// Decode the ping frame
		fin, opcode, decoded_payload := decode_ws_frame(ping_frame) or {
			println('  Iteration ${i}: Failed to decode ping frame: ${err}')
			return false
		}
		
		// Verify it's a ping frame
		if opcode != ws_opcode_ping {
			println('  Iteration ${i}: Expected ping opcode (0x9), got 0x${opcode:02x}')
			return false
		}
		
		// Verify FIN bit is set
		if !fin {
			println('  Iteration ${i}: FIN bit should be set for ping frame')
			return false
		}
		
		// Verify payload matches
		if decoded_payload != payload {
			println('  Iteration ${i}: Ping payload mismatch')
			return false
		}
		
		// Verify awaiting_pong is set
		if !ws.awaiting_pong {
			println('  Iteration ${i}: awaiting_pong should be true after sending ping')
			return false
		}
	}
	return true
}

fn test_property_11_pong_clears_awaiting_flag() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		payload := generate_small_payload()
		
		mut ws := create_mock_ws_context()
		
		// Send ping
		ws.send_ping(payload) or {
			println('  Iteration ${i}: Failed to send ping: ${err}')
			return false
		}
		
		// Verify awaiting_pong is set
		if !ws.awaiting_pong {
			println('  Iteration ${i}: awaiting_pong should be true after ping')
			return false
		}
		
		// Handle pong
		ws.handle_pong(payload)
		
		// Verify awaiting_pong is cleared
		if ws.awaiting_pong {
			println('  Iteration ${i}: awaiting_pong should be false after pong')
			return false
		}
		
		// Verify last_pong_received is updated
		if ws.last_pong_received <= 0 {
			println('  Iteration ${i}: last_pong_received should be updated')
			return false
		}
	}
	return true
}

fn test_property_11_ping_payload_size_limit() bool {
	// Test that ping payload > 125 bytes is rejected
	mut ws := create_mock_ws_context()
	
	// Create payload larger than 125 bytes
	large_payload := []u8{len: 126, init: u8(0x42)}
	
	// Should fail
	ws.send_ping(large_payload) or {
		// Expected error
		return true
	}
	
	println('  Large ping payload should be rejected')
	return false
}

fn test_property_11_ping_requires_open_connection() bool {
	// Test that ping fails on non-open connections
	states := [WSReadyState.connecting, .closing, .closed]
	
	for state in states {
		mut ws := create_mock_ws_context()
		ws.ready_state = state
		
		ws.send_ping([]u8{}) or {
			// Expected error
			continue
		}
		
		println('  Ping should fail in ${state} state')
		return false
	}
	
	return true
}

fn test_property_11_should_send_ping_logic() bool {
	// Test should_send_ping logic
	
	// Case 1: Ping disabled (interval = 0)
	mut ws1 := create_mock_ws_context()
	ws1.ping_interval = 0
	if ws1.should_send_ping() {
		println('  should_send_ping should be false when interval is 0')
		return false
	}
	
	// Case 2: Connection not open
	mut ws2 := create_mock_ws_context()
	ws2.ready_state = .closing
	if ws2.should_send_ping() {
		println('  should_send_ping should be false when not open')
		return false
	}
	
	// Case 3: Already awaiting pong
	mut ws3 := create_mock_ws_context()
	ws3.awaiting_pong = true
	if ws3.should_send_ping() {
		println('  should_send_ping should be false when awaiting pong')
		return false
	}
	
	// Case 4: Not enough time elapsed
	mut ws4 := create_mock_ws_context()
	ws4.ping_interval = 30000 // 30 seconds
	ws4.last_ping_sent = time.now().unix() // Just sent
	if ws4.should_send_ping() {
		println('  should_send_ping should be false when interval not elapsed')
		return false
	}
	
	return true
}

fn test_ping_pong_round_trip() bool {
	rand.seed([u32(time.now().unix()), u32(77777)])
	
	for i in 0 .. test_iterations {
		payload := generate_random_ping_payload()
		
		// Build ping frame
		ping_frame := encode_ws_frame(ws_opcode_ping, payload, false)
		
		// Decode ping frame
		_, ping_opcode, ping_payload := decode_ws_frame(ping_frame) or {
			println('  Iteration ${i}: Failed to decode ping frame: ${err}')
			return false
		}
		
		if ping_opcode != ws_opcode_ping {
			println('  Iteration ${i}: Expected ping opcode')
			return false
		}
		
		// Build pong frame with same payload
		pong_frame := encode_ws_frame(ws_opcode_pong, ping_payload, false)
		
		// Decode pong frame
		_, pong_opcode, pong_payload := decode_ws_frame(pong_frame) or {
			println('  Iteration ${i}: Failed to decode pong frame: ${err}')
			return false
		}
		
		if pong_opcode != ws_opcode_pong {
			println('  Iteration ${i}: Expected pong opcode')
			return false
		}
		
		// Verify payload round-trip
		if pong_payload != payload {
			println('  Iteration ${i}: Payload mismatch in round-trip')
			return false
		}
	}
	return true
}

fn test_empty_ping_payload() bool {
	mut ws := create_mock_ws_context()
	
	// Empty payload should work
	pong_frame := ws.handle_ping([]u8{}) or {
		println('  Empty ping payload should be handled')
		return false
	}
	
	// Decode and verify
	_, opcode, payload := decode_ws_frame(pong_frame) or {
		println('  Failed to decode pong frame')
		return false
	}
	
	if opcode != ws_opcode_pong {
		println('  Expected pong opcode')
		return false
	}
	
	if payload.len != 0 {
		println('  Pong payload should be empty')
		return false
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Ping/Pong Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 11: Ping/Pong Handling
	// Validates: Requirements 7.4
	stats.run_property_test('Property 11: Pong Echoes Ping Payload', test_property_11_pong_echoes_ping_payload)
	stats.run_property_test('Property 11: Ping Sends Frame', test_property_11_ping_sends_frame)
	stats.run_property_test('Property 11: Pong Clears Awaiting Flag', test_property_11_pong_clears_awaiting_flag)
	stats.run_property_test('Property 11: Ping Payload Size Limit', test_property_11_ping_payload_size_limit)
	stats.run_property_test('Property 11: Ping Requires Open Connection', test_property_11_ping_requires_open_connection)
	stats.run_property_test('Property 11: Should Send Ping Logic', test_property_11_should_send_ping_logic)
	stats.run_property_test('Ping/Pong Round Trip', test_ping_pong_round_trip)
	stats.run_property_test('Empty Ping Payload', test_empty_ping_payload)

	// Print test summary
	stats.print_summary()
}
