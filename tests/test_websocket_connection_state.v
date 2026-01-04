// test_websocket_connection_state.v - Property test for WebSocket connection state tracking
// Feature: websocket-helper, Property 7: Connection State Tracking
// Validates: Requirements 3.5
//
// *For any* WSContext, the `ready_state` property SHALL accurately reflect the current 
// connection state: `connecting` during handshake, `open` after successful handshake, 
// `closing` after close initiated, and `closed` after connection terminated.
module main

import rand
import time

const test_iterations = 100

// WebSocket Ready State (copied from websocket.v for testing)
enum WSReadyState {
	connecting = 0
	open       = 1
	closing    = 2
	closed     = 3
}

// State change event for tracking
struct WSStateChangeEvent {
	previous_state WSReadyState
	new_state      WSReadyState
	timestamp      i64
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
	println('\n=== WebSocket Connection State Property Test Summary ===')
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
// State Transition Validation (copied from websocket.v for testing)
// ============================================================================

// Valid state transitions according to WebSocket protocol:
// connecting -> open (handshake successful)
// connecting -> closed (handshake failed)
// open -> closing (close initiated)
// open -> closed (abrupt close)
// closing -> closed (close handshake complete)

fn is_valid_state_transition(from WSReadyState, to WSReadyState) bool {
	match from {
		.connecting {
			return to == .open || to == .closed
		}
		.open {
			return to == .closing || to == .closed
		}
		.closing {
			return to == .closed
		}
		.closed {
			return false
		}
	}
}

// ============================================================================
// Mock WSContext for testing state transitions
// ============================================================================

struct MockWSContext {
mut:
	ready_state   WSReadyState
	state_history []WSStateChangeEvent
}

fn create_mock_ws_context() MockWSContext {
	return MockWSContext{
		ready_state: .connecting
		state_history: []WSStateChangeEvent{}
	}
}

fn (mut ws MockWSContext) transition_state(new_state WSReadyState) bool {
	old_state := ws.ready_state
	
	if !is_valid_state_transition(old_state, new_state) {
		return false
	}
	
	ws.ready_state = new_state
	ws.state_history << WSStateChangeEvent{
		previous_state: old_state
		new_state: new_state
		timestamp: time.now().unix()
	}
	
	return true
}

fn (ws MockWSContext) is_open() bool {
	return ws.ready_state == .open
}

fn (ws MockWSContext) is_closed() bool {
	return ws.ready_state == .closed || ws.ready_state == .closing
}

fn (ws MockWSContext) can_send() bool {
	return ws.ready_state == .open
}

// ============================================================================
// Random State Generators
// ============================================================================

fn get_all_states() []WSReadyState {
	return [WSReadyState.connecting, .open, .closing, .closed]
}

fn generate_random_state() WSReadyState {
	states := get_all_states()
	idx := rand.int_in_range(0, states.len) or { 0 }
	return states[idx]
}

fn generate_valid_transition_sequence() []WSReadyState {
	// Generate a valid sequence of state transitions
	mut sequence := []WSReadyState{}
	mut current := WSReadyState.connecting
	sequence << current
	
	// Randomly decide the path
	choice := rand.int_in_range(0, 4) or { 0 }
	
	match choice {
		0 {
			// connecting -> open -> closing -> closed
			sequence << WSReadyState.open
			sequence << WSReadyState.closing
			sequence << WSReadyState.closed
		}
		1 {
			// connecting -> open -> closed (abrupt)
			sequence << WSReadyState.open
			sequence << WSReadyState.closed
		}
		2 {
			// connecting -> closed (handshake failed)
			sequence << WSReadyState.closed
		}
		else {
			// connecting -> open (stay open)
			sequence << WSReadyState.open
		}
	}
	
	return sequence
}

// ============================================================================
// Property 7: Connection State Tracking
// Feature: websocket-helper, Property 7: Connection State Tracking
// Validates: Requirements 3.5
//
// *For any* WSContext, the `ready_state` property SHALL accurately reflect 
// the current connection state.
// ============================================================================

fn test_property_7_initial_state_is_connecting() bool {
	// All new connections should start in connecting state
	for _ in 0 .. test_iterations {
		ws := create_mock_ws_context()
		
		if ws.ready_state != .connecting {
			println('  New connection should start in connecting state')
			return false
		}
	}
	return true
}

fn test_property_7_valid_transitions_succeed() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		sequence := generate_valid_transition_sequence()
		mut ws := create_mock_ws_context()
		
		// Apply all transitions in sequence (skip first as it's initial state)
		for j := 1; j < sequence.len; j++ {
			target_state := sequence[j]
			success := ws.transition_state(target_state)
			
			if !success {
				println('  Iteration ${i}: Valid transition from ${sequence[j-1]} to ${target_state} should succeed')
				return false
			}
			
			if ws.ready_state != target_state {
				println('  Iteration ${i}: State should be ${target_state} after transition, got ${ws.ready_state}')
				return false
			}
		}
		
		// Verify history was recorded
		if ws.state_history.len != sequence.len - 1 {
			println('  Iteration ${i}: State history should have ${sequence.len - 1} entries, got ${ws.state_history.len}')
			return false
		}
	}
	return true
}

fn test_property_7_invalid_transitions_fail() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	// Test invalid transitions
	invalid_transitions := [
		// From closed, no transitions are valid
		[WSReadyState.closed, WSReadyState.connecting],
		[WSReadyState.closed, WSReadyState.open],
		[WSReadyState.closed, WSReadyState.closing],
		// From closing, can only go to closed
		[WSReadyState.closing, WSReadyState.connecting],
		[WSReadyState.closing, WSReadyState.open],
		// From connecting, cannot go to closing
		[WSReadyState.connecting, WSReadyState.closing],
		// From open, cannot go back to connecting
		[WSReadyState.open, WSReadyState.connecting],
	]
	
	for transition in invalid_transitions {
		from_state := transition[0]
		to_state := transition[1]
		
		mut ws := create_mock_ws_context()
		
		// Set up initial state (may need intermediate transitions)
		if from_state == .open {
			ws.transition_state(.open)
		} else if from_state == .closing {
			ws.transition_state(.open)
			ws.transition_state(.closing)
		} else if from_state == .closed {
			ws.transition_state(.closed)
		}
		
		// Try invalid transition
		old_state := ws.ready_state
		success := ws.transition_state(to_state)
		
		if success {
			println('  Invalid transition from ${from_state} to ${to_state} should fail')
			return false
		}
		
		// State should remain unchanged
		if ws.ready_state != old_state {
			println('  State should remain ${old_state} after failed transition, got ${ws.ready_state}')
			return false
		}
	}
	return true
}

fn test_property_7_state_reflects_connection_lifecycle() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		mut ws := create_mock_ws_context()
		
		// Initial: connecting state
		if ws.ready_state != .connecting {
			println('  Iteration ${i}: Initial state should be connecting')
			return false
		}
		if ws.is_open() {
			println('  Iteration ${i}: is_open() should be false in connecting state')
			return false
		}
		if ws.can_send() {
			println('  Iteration ${i}: can_send() should be false in connecting state')
			return false
		}
		
		// Handshake success: open state
		ws.transition_state(.open)
		if ws.ready_state != .open {
			println('  Iteration ${i}: State should be open after handshake')
			return false
		}
		if !ws.is_open() {
			println('  Iteration ${i}: is_open() should be true in open state')
			return false
		}
		if !ws.can_send() {
			println('  Iteration ${i}: can_send() should be true in open state')
			return false
		}
		
		// Close initiated: closing state
		ws.transition_state(.closing)
		if ws.ready_state != .closing {
			println('  Iteration ${i}: State should be closing after close initiated')
			return false
		}
		if ws.is_open() {
			println('  Iteration ${i}: is_open() should be false in closing state')
			return false
		}
		if ws.can_send() {
			println('  Iteration ${i}: can_send() should be false in closing state')
			return false
		}
		if !ws.is_closed() {
			println('  Iteration ${i}: is_closed() should be true in closing state')
			return false
		}
		
		// Connection terminated: closed state
		ws.transition_state(.closed)
		if ws.ready_state != .closed {
			println('  Iteration ${i}: State should be closed after termination')
			return false
		}
		if ws.is_open() {
			println('  Iteration ${i}: is_open() should be false in closed state')
			return false
		}
		if ws.can_send() {
			println('  Iteration ${i}: can_send() should be false in closed state')
			return false
		}
		if !ws.is_closed() {
			println('  Iteration ${i}: is_closed() should be true in closed state')
			return false
		}
	}
	return true
}

fn test_property_7_state_history_tracking() bool {
	rand.seed([u32(time.now().unix()), u32(77777)])
	
	for i in 0 .. test_iterations {
		sequence := generate_valid_transition_sequence()
		mut ws := create_mock_ws_context()
		
		// Apply transitions
		for j := 1; j < sequence.len; j++ {
			ws.transition_state(sequence[j])
		}
		
		// Verify history
		for j, event in ws.state_history {
			expected_from := sequence[j]
			expected_to := sequence[j + 1]
			
			if event.previous_state != expected_from {
				println('  Iteration ${i}: History[${j}] previous_state should be ${expected_from}, got ${event.previous_state}')
				return false
			}
			if event.new_state != expected_to {
				println('  Iteration ${i}: History[${j}] new_state should be ${expected_to}, got ${event.new_state}')
				return false
			}
			if event.timestamp <= 0 {
				println('  Iteration ${i}: History[${j}] should have valid timestamp')
				return false
			}
		}
	}
	return true
}

fn main() {
	println('🚀 Starting WebSocket Connection State Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 7: Connection State Tracking
	// Validates: Requirements 3.5
	stats.run_property_test('Property 7: Initial State is Connecting', test_property_7_initial_state_is_connecting)
	stats.run_property_test('Property 7: Valid Transitions Succeed', test_property_7_valid_transitions_succeed)
	stats.run_property_test('Property 7: Invalid Transitions Fail', test_property_7_invalid_transitions_fail)
	stats.run_property_test('Property 7: State Reflects Connection Lifecycle', test_property_7_state_reflects_connection_lifecycle)
	stats.run_property_test('Property 7: State History Tracking', test_property_7_state_history_tracking)

	// Print test summary
	stats.print_summary()
}
