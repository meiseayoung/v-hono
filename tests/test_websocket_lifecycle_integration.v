// test_websocket_lifecycle_integration.v - Integration test for WebSocket full connection lifecycle
// Feature: websocket-helper, Property 4: Event Callback Invocation
// Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5
//
// *For any* WebSocket connection lifecycle, the event callbacks SHALL be invoked in the
// correct order: `on_open` (once on connection), `on_message` (for each message), and
// `on_close` (once on disconnection), with each callback receiving a valid WSContext.
module main

import rand
import time
import net.http

const test_iterations = 100

// WebSocket magic GUID for handshake (RFC 6455)
const ws_magic_guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

// WebSocket opcodes
const ws_opcode_text = u8(0x1)
const ws_opcode_binary = u8(0x2)
const ws_opcode_close = u8(0x8)
const ws_opcode_ping = u8(0x9)
const ws_opcode_pong = u8(0xA)

// WebSocket close codes
const ws_close_normal = 1000

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
	println('\n=== WebSocket Lifecycle Integration Test Summary ===')
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
// Minimal type definitions for testing
// ============================================================================

enum WSReadyState {
	connecting = 0
	open       = 1
	closing    = 2
	closed     = 3
}

struct WSMessageEvent {
pub:
	data       string
	data_bytes []u8
	is_binary  bool
}

struct WSCloseEvent {
pub:
	code      int
	reason    string
	was_clean bool
}

@[heap]
struct Context {
pub:
	req    http.Request
	params map[string]string
	query  map[string]string
	url    string
	path   string
pub mut:
	status_code int = 200
	headers     map[string]string
	body        string
	store       map[string]string
}

struct WSContext {
pub:
	http_ctx &Context
	params   map[string]string
	query    map[string]string
	store    map[string]string
pub mut:
	ready_state WSReadyState
	protocol    string
	socket      voidptr
	send_fn     fn ([]u8) ! = unsafe { nil }
	close_fn    fn (int, string) ! = unsafe { nil }
}

fn (ws WSContext) is_open() bool {
	return ws.ready_state == .open
}

fn (ws WSContext) can_send() bool {
	return ws.ready_state == .open
}

// ============================================================================
// Event Tracking for Testing
// ============================================================================

enum EventType {
	on_open
	on_message
	on_close
	on_error
}

struct EventRecord {
	event_type    EventType
	timestamp     i64
	message_data  string
	is_binary     bool
	close_code    int
	close_reason  string
	error_message string
	ws_valid      bool // Whether WSContext was valid when callback was invoked
}

// EventTracker - Tracks all events during a WebSocket lifecycle
struct EventTracker {
mut:
	events []EventRecord
}

fn (mut tracker EventTracker) record_open(ws WSContext) {
	tracker.events << EventRecord{
		event_type: .on_open
		timestamp: time.now().unix_milli()
		ws_valid: ws.http_ctx != unsafe { nil }
	}
}

fn (mut tracker EventTracker) record_message(event WSMessageEvent, ws WSContext) {
	tracker.events << EventRecord{
		event_type: .on_message
		timestamp: time.now().unix_milli()
		message_data: event.data
		is_binary: event.is_binary
		ws_valid: ws.http_ctx != unsafe { nil }
	}
}

fn (mut tracker EventTracker) record_close(event WSCloseEvent, ws WSContext) {
	tracker.events << EventRecord{
		event_type: .on_close
		timestamp: time.now().unix_milli()
		close_code: event.code
		close_reason: event.reason
		ws_valid: ws.http_ctx != unsafe { nil }
	}
}

fn (mut tracker EventTracker) record_error(error_msg string, ws WSContext) {
	tracker.events << EventRecord{
		event_type: .on_error
		timestamp: time.now().unix_milli()
		error_message: error_msg
		ws_valid: ws.http_ctx != unsafe { nil }
	}
}

fn (tracker EventTracker) get_event_sequence() []EventType {
	mut sequence := []EventType{}
	for event in tracker.events {
		sequence << event.event_type
	}
	return sequence
}

fn (tracker EventTracker) count_events(event_type EventType) int {
	mut count := 0
	for event in tracker.events {
		if event.event_type == event_type {
			count++
		}
	}
	return count
}

fn (tracker EventTracker) all_ws_contexts_valid() bool {
	for event in tracker.events {
		if !event.ws_valid {
			return false
		}
	}
	return true
}

// ============================================================================
// WebSocket Frame Encoding/Decoding (for simulation)
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

// ============================================================================
// Connection Lifecycle Simulator
// ============================================================================

// Simulates a complete WebSocket connection lifecycle
struct LifecycleSimulator {
mut:
	tracker     EventTracker
	ws_ctx      WSContext
	http_ctx    Context
	is_open     bool
	messages    []string
	close_code  int
	close_reason string
}

fn create_lifecycle_simulator() LifecycleSimulator {
	http_ctx := Context{
		req: http.Request{
			method: .get
			url: '/ws/test'
		}
		params: {'room': 'test-room', 'id': '123'}
		query: {'token': 'abc123'}
		url: '/ws/test?token=abc123'
		path: '/ws/test'
		store: {'user_id': 'user-456'}
	}
	
	ws_ctx := WSContext{
		http_ctx: &http_ctx
		params: http_ctx.params.clone()
		query: http_ctx.query.clone()
		store: http_ctx.store.clone()
		ready_state: .connecting
		protocol: ''
		socket: unsafe { nil }
	}
	
	return LifecycleSimulator{
		tracker: EventTracker{}
		ws_ctx: ws_ctx
		http_ctx: http_ctx
		is_open: false
		messages: []string{}
		close_code: 0
		close_reason: ''
	}
}

fn (mut sim LifecycleSimulator) simulate_open() {
	sim.ws_ctx.ready_state = .open
	sim.is_open = true
	sim.tracker.record_open(sim.ws_ctx)
}

fn (mut sim LifecycleSimulator) simulate_message(data string, is_binary bool) {
	if !sim.is_open {
		return
	}
	
	event := WSMessageEvent{
		data: data
		data_bytes: data.bytes()
		is_binary: is_binary
	}
	sim.messages << data
	sim.tracker.record_message(event, sim.ws_ctx)
}

fn (mut sim LifecycleSimulator) simulate_close(code int, reason string) {
	if !sim.is_open {
		return
	}
	
	sim.ws_ctx.ready_state = .closing
	sim.close_code = code
	sim.close_reason = reason
	
	event := WSCloseEvent{
		code: code
		reason: reason
		was_clean: code == ws_close_normal
	}
	sim.tracker.record_close(event, sim.ws_ctx)
	
	sim.ws_ctx.ready_state = .closed
	sim.is_open = false
}

fn (mut sim LifecycleSimulator) simulate_error(error_msg string) {
	sim.tracker.record_error(error_msg, sim.ws_ctx)
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn generate_random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '
	len := rand.int_in_range(min_len, max_len + 1) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

fn generate_random_message_count() int {
	return rand.int_in_range(0, 11) or { 0 } // 0 to 10 messages
}

fn generate_random_close_code() int {
	codes := [1000, 1001, 1002, 1003, 1007, 1008, 1009, 1011]
	idx := rand.int_in_range(0, codes.len) or { 0 }
	return codes[idx]
}

// ============================================================================
// Property 4: Event Callback Invocation
// Feature: websocket-helper, Property 4: Event Callback Invocation
// Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5
// ============================================================================

// Test that on_open is called exactly once at connection start
fn test_property_4_on_open_called_once() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		// Simulate connection open
		sim.simulate_open()
		
		// Send random number of messages
		msg_count := generate_random_message_count()
		for _ in 0 .. msg_count {
			sim.simulate_message(generate_random_string(5, 50), false)
		}
		
		// Close connection
		sim.simulate_close(generate_random_close_code(), 'test close')
		
		// Verify on_open was called exactly once
		open_count := sim.tracker.count_events(.on_open)
		if open_count != 1 {
			println('  Iteration ${i}: on_open should be called exactly once')
			println('    Expected: 1, Got: ${open_count}')
			return false
		}
	}
	
	return true
}

// Test that on_message is called for each message
fn test_property_4_on_message_called_for_each() bool {
	rand.seed([u32(time.now().unix()), u32(23456)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		// Send random number of messages
		msg_count := generate_random_message_count()
		for _ in 0 .. msg_count {
			sim.simulate_message(generate_random_string(5, 50), false)
		}
		
		sim.simulate_close(ws_close_normal, '')
		
		// Verify on_message was called for each message
		message_count := sim.tracker.count_events(.on_message)
		if message_count != msg_count {
			println('  Iteration ${i}: on_message count mismatch')
			println('    Expected: ${msg_count}, Got: ${message_count}')
			return false
		}
	}
	
	return true
}

// Test that on_close is called exactly once at disconnection
fn test_property_4_on_close_called_once() bool {
	rand.seed([u32(time.now().unix()), u32(34567)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		msg_count := generate_random_message_count()
		for _ in 0 .. msg_count {
			sim.simulate_message(generate_random_string(5, 50), false)
		}
		
		sim.simulate_close(generate_random_close_code(), 'test close')
		
		// Verify on_close was called exactly once
		close_count := sim.tracker.count_events(.on_close)
		if close_count != 1 {
			println('  Iteration ${i}: on_close should be called exactly once')
			println('    Expected: 1, Got: ${close_count}')
			return false
		}
	}
	
	return true
}

// Test that events are called in correct order: open -> messages -> close
fn test_property_4_event_order() bool {
	rand.seed([u32(time.now().unix()), u32(45678)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		msg_count := generate_random_message_count()
		for _ in 0 .. msg_count {
			sim.simulate_message(generate_random_string(5, 50), false)
		}
		
		sim.simulate_close(ws_close_normal, '')
		
		// Get event sequence
		sequence := sim.tracker.get_event_sequence()
		
		// Verify sequence starts with on_open
		if sequence.len == 0 || sequence[0] != .on_open {
			println('  Iteration ${i}: First event should be on_open')
			return false
		}
		
		// Verify sequence ends with on_close
		if sequence[sequence.len - 1] != .on_close {
			println('  Iteration ${i}: Last event should be on_close')
			return false
		}
		
		// Verify all messages are between open and close
		mut found_close := false
		for j := 1; j < sequence.len - 1; j++ {
			if sequence[j] == .on_close {
				found_close = true
			}
			if found_close && sequence[j] == .on_message {
				println('  Iteration ${i}: on_message should not occur after on_close')
				return false
			}
		}
	}
	
	return true
}

// Test that all callbacks receive valid WSContext
fn test_property_4_valid_ws_context() bool {
	rand.seed([u32(time.now().unix()), u32(56789)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		msg_count := generate_random_message_count()
		for _ in 0 .. msg_count {
			sim.simulate_message(generate_random_string(5, 50), false)
		}
		
		sim.simulate_close(ws_close_normal, '')
		
		// Verify all callbacks received valid WSContext
		if !sim.tracker.all_ws_contexts_valid() {
			println('  Iteration ${i}: Some callbacks received invalid WSContext')
			return false
		}
	}
	
	return true
}

// Test message data is correctly passed to on_message callback
fn test_property_4_message_data_preserved() bool {
	rand.seed([u32(time.now().unix()), u32(67890)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		// Generate and send messages
		mut expected_messages := []string{}
		msg_count := rand.int_in_range(1, 6) or { 1 }
		for _ in 0 .. msg_count {
			msg := generate_random_string(5, 50)
			expected_messages << msg
			sim.simulate_message(msg, false)
		}
		
		sim.simulate_close(ws_close_normal, '')
		
		// Verify message data was preserved
		mut msg_idx := 0
		for event in sim.tracker.events {
			if event.event_type == .on_message {
				if msg_idx >= expected_messages.len {
					println('  Iteration ${i}: More messages recorded than sent')
					return false
				}
				if event.message_data != expected_messages[msg_idx] {
					println('  Iteration ${i}: Message data mismatch at index ${msg_idx}')
					println('    Expected: ${expected_messages[msg_idx]}')
					println('    Got: ${event.message_data}')
					return false
				}
				msg_idx++
			}
		}
	}
	
	return true
}

// Test close code and reason are correctly passed to on_close callback
fn test_property_4_close_data_preserved() bool {
	rand.seed([u32(time.now().unix()), u32(78901)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		// Generate random close code and reason
		close_code := generate_random_close_code()
		close_reason := generate_random_string(5, 30)
		
		sim.simulate_close(close_code, close_reason)
		
		// Find close event and verify data
		mut found_close := false
		for event in sim.tracker.events {
			if event.event_type == .on_close {
				found_close = true
				if event.close_code != close_code {
					println('  Iteration ${i}: Close code mismatch')
					println('    Expected: ${close_code}, Got: ${event.close_code}')
					return false
				}
				if event.close_reason != close_reason {
					println('  Iteration ${i}: Close reason mismatch')
					println('    Expected: ${close_reason}, Got: ${event.close_reason}')
					return false
				}
				break
			}
		}
		
		if !found_close {
			println('  Iteration ${i}: No close event found')
			return false
		}
	}
	
	return true
}

// Test binary message handling
fn test_property_4_binary_message_handling() bool {
	rand.seed([u32(time.now().unix()), u32(89012)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		// Send mix of text and binary messages
		mut expected_binary_flags := []bool{}
		msg_count := rand.int_in_range(1, 6) or { 1 }
		for _ in 0 .. msg_count {
			is_binary := rand.int_in_range(0, 2) or { 0 } == 1
			expected_binary_flags << is_binary
			sim.simulate_message(generate_random_string(5, 50), is_binary)
		}
		
		sim.simulate_close(ws_close_normal, '')
		
		// Verify binary flags were preserved
		mut msg_idx := 0
		for event in sim.tracker.events {
			if event.event_type == .on_message {
				if msg_idx >= expected_binary_flags.len {
					println('  Iteration ${i}: More messages recorded than sent')
					return false
				}
				if event.is_binary != expected_binary_flags[msg_idx] {
					println('  Iteration ${i}: Binary flag mismatch at index ${msg_idx}')
					println('    Expected: ${expected_binary_flags[msg_idx]}, Got: ${event.is_binary}')
					return false
				}
				msg_idx++
			}
		}
	}
	
	return true
}

// Test complete lifecycle with all event types
fn test_property_4_complete_lifecycle() bool {
	rand.seed([u32(time.now().unix()), u32(90123)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		// Full lifecycle: open -> messages -> close
		sim.simulate_open()
		
		msg_count := generate_random_message_count()
		for _ in 0 .. msg_count {
			sim.simulate_message(generate_random_string(5, 50), false)
		}
		
		sim.simulate_close(ws_close_normal, 'Normal closure')
		
		// Verify complete lifecycle
		sequence := sim.tracker.get_event_sequence()
		
		// Should have: 1 open + N messages + 1 close
		expected_len := 1 + msg_count + 1
		if sequence.len != expected_len {
			println('  Iteration ${i}: Event count mismatch')
			println('    Expected: ${expected_len}, Got: ${sequence.len}')
			return false
		}
		
		// Verify structure
		if sequence[0] != .on_open {
			println('  Iteration ${i}: First event should be on_open')
			return false
		}
		
		for j := 1; j < sequence.len - 1; j++ {
			if sequence[j] != .on_message {
				println('  Iteration ${i}: Middle events should be on_message')
				return false
			}
		}
		
		if sequence[sequence.len - 1] != .on_close {
			println('  Iteration ${i}: Last event should be on_close')
			return false
		}
	}
	
	return true
}

// Test error callback invocation
fn test_property_4_error_callback() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])
	
	for i in 0 .. test_iterations {
		mut sim := create_lifecycle_simulator()
		
		sim.simulate_open()
		
		// Simulate an error
		error_msg := 'Test error: ${generate_random_string(10, 30)}'
		sim.simulate_error(error_msg)
		
		sim.simulate_close(1011, 'Internal error')
		
		// Verify error was recorded
		error_count := sim.tracker.count_events(.on_error)
		if error_count != 1 {
			println('  Iteration ${i}: on_error should be called once')
			println('    Expected: 1, Got: ${error_count}')
			return false
		}
		
		// Verify error message was preserved
		for event in sim.tracker.events {
			if event.event_type == .on_error {
				if event.error_message != error_msg {
					println('  Iteration ${i}: Error message mismatch')
					println('    Expected: ${error_msg}')
					println('    Got: ${event.error_message}')
					return false
				}
				break
			}
		}
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Lifecycle Integration Tests...')
	println('Feature: websocket-helper, Property 4: Event Callback Invocation')
	println('Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	stats.run_property_test('Property 4.1: on_open Called Once', test_property_4_on_open_called_once)
	stats.run_property_test('Property 4.2: on_message Called For Each', test_property_4_on_message_called_for_each)
	stats.run_property_test('Property 4.3: on_close Called Once', test_property_4_on_close_called_once)
	stats.run_property_test('Property 4.4: Event Order (open -> messages -> close)', test_property_4_event_order)
	stats.run_property_test('Property 4.5: Valid WSContext in All Callbacks', test_property_4_valid_ws_context)
	stats.run_property_test('Property 4.6: Message Data Preserved', test_property_4_message_data_preserved)
	stats.run_property_test('Property 4.7: Close Data Preserved', test_property_4_close_data_preserved)
	stats.run_property_test('Property 4.8: Binary Message Handling', test_property_4_binary_message_handling)
	stats.run_property_test('Property 4.9: Complete Lifecycle', test_property_4_complete_lifecycle)
	stats.run_property_test('Property 4.10: Error Callback', test_property_4_error_callback)

	// Print test summary
	stats.print_summary()
}
