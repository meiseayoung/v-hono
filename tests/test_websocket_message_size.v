// test_websocket_message_size.v - Property test for WebSocket message size limit
// Feature: websocket-helper, Property 8: Message Size Limit
// Validates: Requirements 4.2
//
// *For any* incoming WebSocket message exceeding the configured max_message_size,
// the server SHALL close the connection with status code 1009 (Message Too Big)
// and invoke the on_error callback.
module main

import rand
import time

const test_iterations = 100

// WebSocket opcodes (RFC 6455)
const ws_opcode_text = u8(0x1)
const ws_opcode_binary = u8(0x2)
const ws_opcode_close = u8(0x8)
const ws_opcode_ping = u8(0x9)
const ws_opcode_pong = u8(0xA)

// WebSocket close codes
const ws_close_message_too_big = 1009

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
	println('\n=== WebSocket Message Size Limit Property Test Summary ===')
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
// WebSocket Frame Structure (copied from websocket.v for testing)
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

// WSReadyState - WebSocket connection state enumeration
enum WSReadyState {
	connecting = 0
	open       = 1
	closing    = 2
	closed     = 3
}

// WSStateChangeEvent - Event structure for state change notifications
struct WSStateChangeEvent {
pub:
	previous_state WSReadyState
	new_state      WSReadyState
	timestamp      i64
}

// WSContext - Simplified WebSocket context for testing
struct WSContext {
pub mut:
	ready_state      WSReadyState
	state_history    []WSStateChangeEvent
	close_code       int
	close_reason     string
	error_messages   []string
}

fn (mut ws WSContext) force_close(code int, reason string) {
	ws.close_code = code
	ws.close_reason = reason
	ws.ready_state = .closed
	ws.state_history << WSStateChangeEvent{
		previous_state: .open
		new_state: .closed
		timestamp: time.now().unix()
	}
}

// WSMessageEvent - Message event structure
struct WSMessageEvent {
pub:
	data       string
	data_bytes []u8
	is_binary  bool
}

// WSCloseEvent - Close event structure
struct WSCloseEvent {
pub:
	code      int
	reason    string
	was_clean bool
}

// Event handler types
type WSOpenHandler = fn (mut ws WSContext)
type WSMessageHandler = fn (event WSMessageEvent, mut ws WSContext)
type WSCloseHandler = fn (event WSCloseEvent, mut ws WSContext)
type WSErrorHandler = fn (error string, mut ws WSContext)

// WSEvents - WebSocket event handlers configuration
struct WSEvents {
pub:
	on_open    ?WSOpenHandler
	on_message ?WSMessageHandler
	on_close   ?WSCloseHandler
	on_error   ?WSErrorHandler
}


// ============================================================================
// Message Size Validation Function (copied from websocket.v for testing)
// ============================================================================

fn validate_message_size(frame WSFrame, max_message_size int, events WSEvents, mut ws WSContext) bool {
	// Only validate data frames (text and binary)
	if frame.opcode != ws_opcode_text && frame.opcode != ws_opcode_binary {
		return true
	}
	
	// Check if message size exceeds the limit
	if max_message_size > 0 && int(frame.payload_len) > max_message_size {
		// Invoke on_error callback
		error_msg := 'Message size ${frame.payload_len} exceeds maximum allowed size ${max_message_size}'
		if on_error := events.on_error {
			on_error(error_msg, mut ws)
		}
		
		// Close connection with 1009 (Message Too Big)
		ws.force_close(ws_close_message_too_big, 'Message too big')
		
		return false
	}
	
	return true
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn generate_random_payload(size int) []u8 {
	mut result := []u8{cap: size}
	for _ in 0 .. size {
		result << u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

fn generate_random_text_payload(size int) []u8 {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	mut result := []u8{cap: size}
	for _ in 0 .. size {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result << chars[idx]
	}
	return result
}

fn create_test_frame(opcode u8, payload []u8) WSFrame {
	return WSFrame{
		fin: true
		opcode: opcode
		masked: false
		mask_key: [4]u8{}
		payload_len: u64(payload.len)
		payload: payload
	}
}

fn create_test_ws_context() WSContext {
	return WSContext{
		ready_state: .open
		state_history: []
		close_code: 0
		close_reason: ''
		error_messages: []
	}
}


// ============================================================================
// Property 8: Message Size Limit
// Feature: websocket-helper, Property 8: Message Size Limit
// Validates: Requirements 4.2
//
// *For any* incoming WebSocket message exceeding the configured max_message_size,
// the server SHALL close the connection with status code 1009 (Message Too Big)
// and invoke the on_error callback.
// ============================================================================

fn test_property_8_oversized_messages_rejected() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random max_message_size between 100 and 10000
		max_size := rand.int_in_range(100, 10000) or { 1000 }
		
		// Generate a payload that exceeds the max size
		excess := rand.int_in_range(1, 1000) or { 100 }
		oversized_payload := generate_random_payload(max_size + excess)
		
		// Create a text frame with oversized payload
		frame := create_test_frame(ws_opcode_text, oversized_payload)
		
		// Create test context
		mut ws := create_test_ws_context()
		
		// Create events with error handler that stores error in ws.error_messages
		events := WSEvents{
			on_error: fn (err string, mut ws WSContext) {
				ws.error_messages << err
			}
		}
		
		// Validate message size
		result := validate_message_size(frame, max_size, events, mut ws)
		
		// Verify validation returns false for oversized message
		if result {
			println('  Iteration ${i}: Expected validation to return false for oversized message')
			println('    Max size: ${max_size}, Payload size: ${oversized_payload.len}')
			return false
		}
		
		// Verify connection was closed with 1009
		if ws.close_code != ws_close_message_too_big {
			println('  Iteration ${i}: Expected close code 1009, got ${ws.close_code}')
			return false
		}
		
		// Verify connection state is closed
		if ws.ready_state != .closed {
			println('  Iteration ${i}: Expected connection state to be closed')
			return false
		}
		
		// Verify on_error was invoked by checking error_messages
		if ws.error_messages.len == 0 {
			println('  Iteration ${i}: Expected on_error callback to be invoked')
			return false
		}
	}
	
	return true
}

fn test_property_8_valid_messages_accepted() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate random max_message_size between 100 and 10000
		max_size := rand.int_in_range(100, 10000) or { 1000 }
		
		// Generate a payload that is within the limit
		payload_size := rand.int_in_range(0, max_size) or { 50 }
		valid_payload := generate_random_payload(payload_size)
		
		// Create a text frame with valid payload
		frame := create_test_frame(ws_opcode_text, valid_payload)
		
		// Create test context
		mut ws := create_test_ws_context()
		
		// Create events with error handler
		events := WSEvents{
			on_error: fn (err string, mut ws WSContext) {
				ws.error_messages << err
			}
		}
		
		// Validate message size
		result := validate_message_size(frame, max_size, events, mut ws)
		
		// Verify validation returns true for valid message
		if !result {
			println('  Iteration ${i}: Expected validation to return true for valid message')
			println('    Max size: ${max_size}, Payload size: ${valid_payload.len}')
			return false
		}
		
		// Verify connection was NOT closed
		if ws.close_code != 0 {
			println('  Iteration ${i}: Connection should not be closed for valid message')
			return false
		}
		
		// Verify connection state is still open
		if ws.ready_state != .open {
			println('  Iteration ${i}: Connection state should remain open')
			return false
		}
		
		// Verify on_error was NOT invoked
		if ws.error_messages.len > 0 {
			println('  Iteration ${i}: on_error should not be invoked for valid message')
			return false
		}
	}
	
	return true
}


fn test_property_8_binary_messages_validated() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		// Generate random max_message_size
		max_size := rand.int_in_range(100, 5000) or { 500 }
		
		// Randomly decide if message should be oversized or valid
		is_oversized := rand.int_in_range(0, 2) or { 0 } == 1
		
		payload_size := if is_oversized {
			max_size + rand.int_in_range(1, 500) or { 100 }
		} else {
			rand.int_in_range(0, max_size) or { 50 }
		}
		
		payload := generate_random_payload(payload_size)
		
		// Create a binary frame
		frame := create_test_frame(ws_opcode_binary, payload)
		
		// Create test context
		mut ws := create_test_ws_context()
		
		events := WSEvents{
			on_error: fn (err string, mut ws WSContext) {
				ws.error_messages << err
			}
		}
		
		// Validate message size
		result := validate_message_size(frame, max_size, events, mut ws)
		
		// Verify result matches expectation
		if is_oversized {
			if result {
				println('  Iteration ${i}: Expected false for oversized binary message')
				return false
			}
			if ws.close_code != ws_close_message_too_big {
				println('  Iteration ${i}: Expected close code 1009 for oversized binary')
				return false
			}
		} else {
			if !result {
				println('  Iteration ${i}: Expected true for valid binary message')
				return false
			}
			if ws.close_code != 0 {
				println('  Iteration ${i}: Should not close for valid binary message')
				return false
			}
		}
	}
	
	return true
}

fn test_property_8_control_frames_not_validated() bool {
	rand.seed([u32(time.now().unix()), u32(77777)])
	
	// Control frames (ping, pong, close) should not be subject to message size validation
	control_opcodes := [ws_opcode_ping, ws_opcode_pong, ws_opcode_close]
	
	for i in 0 .. test_iterations {
		// Use a very small max_message_size
		max_size := 10
		
		// Generate payload larger than max_size
		payload := generate_random_payload(50)
		
		// Pick a random control opcode
		opcode := control_opcodes[rand.int_in_range(0, control_opcodes.len) or { 0 }]
		
		// Create a control frame with "oversized" payload
		frame := create_test_frame(opcode, payload)
		
		// Create test context
		mut ws := create_test_ws_context()
		
		events := WSEvents{
			on_error: fn (err string, mut ws WSContext) {
				ws.error_messages << err
			}
		}
		
		// Validate message size - should pass for control frames
		result := validate_message_size(frame, max_size, events, mut ws)
		
		// Control frames should always pass validation
		if !result {
			println('  Iteration ${i}: Control frame (opcode 0x${opcode:02x}) should not be size-validated')
			return false
		}
		
		// Connection should remain open
		if ws.ready_state != .open {
			println('  Iteration ${i}: Connection should remain open for control frames')
			return false
		}
		
		// No error should be raised
		if ws.error_messages.len > 0 {
			println('  Iteration ${i}: No error should be raised for control frames')
			return false
		}
	}
	
	return true
}

fn test_property_8_exact_boundary() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])
	
	for i in 0 .. test_iterations {
		// Generate random max_message_size
		max_size := rand.int_in_range(100, 5000) or { 500 }
		
		// Test exact boundary - message exactly at max_size should be accepted
		exact_payload := generate_random_payload(max_size)
		frame := create_test_frame(ws_opcode_text, exact_payload)
		
		mut ws := create_test_ws_context()
		events := WSEvents{}
		
		result := validate_message_size(frame, max_size, events, mut ws)
		
		// Exact boundary should be accepted
		if !result {
			println('  Iteration ${i}: Message at exact boundary (${max_size}) should be accepted')
			return false
		}
		
		// Test one byte over - should be rejected
		over_payload := generate_random_payload(max_size + 1)
		over_frame := create_test_frame(ws_opcode_text, over_payload)
		
		mut ws2 := create_test_ws_context()
		result2 := validate_message_size(over_frame, max_size, events, mut ws2)
		
		if result2 {
			println('  Iteration ${i}: Message one byte over (${max_size + 1}) should be rejected')
			return false
		}
	}
	
	return true
}

fn test_property_8_zero_max_size_disables_validation() bool {
	rand.seed([u32(time.now().unix()), u32(22222)])
	
	for i in 0 .. test_iterations {
		// Generate a large payload
		payload_size := rand.int_in_range(1000, 100000) or { 10000 }
		payload := generate_random_payload(payload_size)
		
		frame := create_test_frame(ws_opcode_text, payload)
		
		mut ws := create_test_ws_context()
		events := WSEvents{}
		
		// With max_size = 0, validation should be disabled
		result := validate_message_size(frame, 0, events, mut ws)
		
		if !result {
			println('  Iteration ${i}: With max_size=0, all messages should be accepted')
			return false
		}
		
		if ws.ready_state != .open {
			println('  Iteration ${i}: Connection should remain open when validation disabled')
			return false
		}
	}
	
	return true
}


fn main() {
	println('🚀 Starting WebSocket Message Size Limit Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 8: Message Size Limit
	// Validates: Requirements 4.2
	stats.run_property_test('Property 8: Oversized Messages Rejected', test_property_8_oversized_messages_rejected)
	stats.run_property_test('Property 8: Valid Messages Accepted', test_property_8_valid_messages_accepted)
	stats.run_property_test('Property 8: Binary Messages Validated', test_property_8_binary_messages_validated)
	stats.run_property_test('Property 8: Control Frames Not Validated', test_property_8_control_frames_not_validated)
	stats.run_property_test('Property 8: Exact Boundary', test_property_8_exact_boundary)
	stats.run_property_test('Property 8: Zero Max Size Disables Validation', test_property_8_zero_max_size_disables_validation)

	// Print test summary
	stats.print_summary()
}
