// test_stream_error_handling_properties.v
// Property-Based Testing for Error Handling in SSE Streaming
// Feature: sse-streaming-helper
// Property 8: 错误处理器调用
// Property 9: 流自动关闭
// Validates: Requirements 4.1, 1.5, 5.2
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
	println('\n=== 错误处理属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// ============================================================================
// Mock StreamWriter for Testing
// ============================================================================

// MockStreamWriter - A mock implementation of StreamWriter for testing
// Captures all written data for verification
struct MockStreamWriter {
mut:
	written_data []u8
	connected    bool
	closed       bool
	flush_count  int
}

fn MockStreamWriter.new() &MockStreamWriter {
	return &MockStreamWriter{
		written_data: []u8{}
		connected: true
		closed: false
		flush_count: 0
	}
}

fn (mut w MockStreamWriter) write(data []u8) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := '${data.len:x}\r\n'
	w.written_data << chunk_header.bytes()
	w.written_data << data
	w.written_data << '\r\n'.bytes()
}

fn (mut w MockStreamWriter) write_string(data string) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := '${data.len:x}\r\n'
	w.written_data << chunk_header.bytes()
	w.written_data << data.bytes()
	w.written_data << '\r\n'.bytes()
}

fn (mut w MockStreamWriter) flush() ! {
	w.flush_count++
}

fn (mut w MockStreamWriter) close() ! {
	if w.connected {
		// Write the final chunk (zero-length chunk) to signal end of stream
		w.written_data << '0\r\n\r\n'.bytes()
		w.connected = false
		w.closed = true
	}
}

fn (w MockStreamWriter) is_connected() bool {
	return w.connected
}

fn (w MockStreamWriter) get_written_string() string {
	return w.written_data.bytestr()
}

// ============================================================================
// StreamContext for Testing (simplified version)
// ============================================================================

// StreamContext - Context provided to streaming callbacks
@[heap]
struct StreamContext {
mut:
	writer    &MockStreamWriter
	is_closed bool
	abort_fn  ?fn ()
}

// StreamContext.new - Create a new StreamContext with the given writer
fn StreamContext.new(writer &MockStreamWriter) StreamContext {
	return StreamContext{
		writer: unsafe { writer }
		is_closed: false
		abort_fn: none
	}
}

// write - Write raw bytes to the stream
fn (mut ctx StreamContext) write(data []u8) ! {
	if ctx.is_closed {
		return error('Stream is closed')
	}
	if !ctx.writer.is_connected() {
		ctx.is_closed = true
		return error('Connection lost')
	}
	ctx.writer.write(data)!
}

// write_string - Write a string to the stream
fn (mut ctx StreamContext) write_string(data string) ! {
	if ctx.is_closed {
		return error('Stream is closed')
	}
	if !ctx.writer.is_connected() {
		ctx.is_closed = true
		return error('Connection lost')
	}
	ctx.writer.write_string(data)!
}

// close - Close the stream
fn (mut ctx StreamContext) close() {
	if !ctx.is_closed {
		ctx.is_closed = true
		ctx.writer.close() or {}
	}
}

// is_open - Check if the stream is still open
fn (ctx StreamContext) is_open() bool {
	return !ctx.is_closed && ctx.writer.is_connected()
}

// ============================================================================
// Callback and Error Handler Types
// ============================================================================

// StreamCallback - Callback function type for streaming
type StreamCallback = fn (mut StreamContext) !

// StreamErrorHandler - Error handler function type for streaming
type StreamErrorHandler = fn (err IError, mut ctx StreamContext)

// ============================================================================
// Stream Response Type
// ============================================================================

struct StreamResponse {
pub:
	status_code int = 200
	headers     map[string]string
	is_stream   bool = true
}

// ============================================================================
// Streaming Helper Functions (for testing)
// ============================================================================

// stream - Basic binary streaming function with error handling
fn stream(mut writer MockStreamWriter, callback StreamCallback, error_handler ...StreamErrorHandler) StreamResponse {
	// Create StreamContext with the writer
	mut ctx := StreamContext.new(writer)
	
	// Execute the callback and handle errors
	callback(mut ctx) or {
		// Handle error
		if error_handler.len > 0 {
			// Call custom error handler
			error_handler[0](err, mut ctx)
		} else {
			// Default: log error to console
			eprintln('[SSE Stream Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	ctx.close()
	
	// Return response headers for streaming
	return StreamResponse{
		status_code: 200
		headers: {
			'Transfer-Encoding': 'chunked'
			'Connection':        'keep-alive'
		}
		is_stream: true
	}
}

// ============================================================================
// Error Tracking for Tests
// ============================================================================

// Global variables to track error handler calls
__global error_handler_called = false
__global error_handler_error_msg = ''
__global error_handler_stream_open = false
__global error_handler_write_success = false

fn reset_error_tracking() {
	error_handler_called = false
	error_handler_error_msg = ''
	error_handler_stream_open = false
	error_handler_write_success = false
}

// ============================================================================
// Helper Functions
// ============================================================================

// Generate random error message
fn generate_random_error_message(max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-.'
	len := rand.int_in_range(5, max_len) or { 20 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// Generate random string for testing
fn generate_random_string(max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.'
	len := rand.int_in_range(1, max_len) or { 10 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// ============================================================================
// Property 8: 错误处理器调用
// Feature: sse-streaming-helper, Property 8
// Validates: Requirements 4.1
//
// *For any* callback that throws an error, if an error handler is provided,
// the error handler SHALL be called with the error and stream context.
// ============================================================================

// Test 8a: Custom error handler is called when callback throws error
fn test_property_8a_error_handler_called() bool {
	rand.seed([u32(time.now().unix()), u32(88881)])
	
	for i in 0 .. test_iterations {
		reset_error_tracking()
		
		// Generate random error message
		error_msg := generate_random_error_message(50)
		
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Define callback that throws an error
		callback := fn [error_msg] (mut ctx StreamContext) ! {
			return error(error_msg)
		}
		
		// Define error handler that tracks the call
		error_handler := fn (err IError, mut ctx StreamContext) {
			error_handler_called = true
			error_handler_error_msg = err.msg()
		}
		
		// Call stream with error handler
		_ := stream(mut writer, callback, error_handler)
		
		// Verify error handler was called
		if !error_handler_called {
			println('  Iteration ${i}: Error handler was not called')
			return false
		}
		
		// Verify error message was passed correctly
		if error_handler_error_msg != error_msg {
			println('  Iteration ${i}: Error message mismatch')
			println('    Expected: ${error_msg}')
			println('    Got: ${error_handler_error_msg}')
			return false
		}
	}
	
	return true
}

// Test 8b: Error handler receives valid stream context
fn test_property_8b_error_handler_receives_context() bool {
	rand.seed([u32(time.now().unix()), u32(88882)])
	
	for i in 0 .. test_iterations {
		reset_error_tracking()
		
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Define callback that throws an error
		callback := fn (mut ctx StreamContext) ! {
			return error('Test error')
		}
		
		// Define error handler that checks stream context
		error_handler := fn (err IError, mut ctx StreamContext) {
			error_handler_called = true
			error_handler_stream_open = ctx.is_open()
		}
		
		// Call stream with error handler
		_ := stream(mut writer, callback, error_handler)
		
		// Verify error handler was called
		if !error_handler_called {
			println('  Iteration ${i}: Error handler was not called')
			return false
		}
		
		// Verify stream was still open when error handler was called
		if !error_handler_stream_open {
			println('  Iteration ${i}: Stream should be open when error handler is called')
			return false
		}
	}
	
	return true
}

// Test 8c: Error handler can write to stream before it closes
fn test_property_8c_error_handler_can_write() bool {
	rand.seed([u32(time.now().unix()), u32(88883)])
	
	for i in 0 .. test_iterations {
		reset_error_tracking()
		
		// Generate random error response message
		error_response := generate_random_string(30)
		
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Define callback that throws an error
		callback := fn (mut ctx StreamContext) ! {
			return error('Test error')
		}
		
		// Define error handler that writes to stream
		error_handler := fn [error_response] (err IError, mut ctx StreamContext) {
			error_handler_called = true
			ctx.write_string(error_response) or {
				error_handler_write_success = false
				return
			}
			error_handler_write_success = true
		}
		
		// Call stream with error handler
		_ := stream(mut writer, callback, error_handler)
		
		// Verify error handler was called
		if !error_handler_called {
			println('  Iteration ${i}: Error handler was not called')
			return false
		}
		
		// Verify write was successful
		if !error_handler_write_success {
			println('  Iteration ${i}: Error handler failed to write to stream')
			return false
		}
		
		// Verify the error response was written
		written := writer.get_written_string()
		if !written.contains(error_response) {
			println('  Iteration ${i}: Error response not found in written data')
			return false
		}
	}
	
	return true
}

// Test 8d: Without error handler, error is logged (no crash)
fn test_property_8d_default_error_handling() bool {
	rand.seed([u32(time.now().unix()), u32(88884)])
	
	for i in 0 .. test_iterations {
		// Generate random error message
		error_msg := generate_random_error_message(50)
		
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Define callback that throws an error
		callback := fn [error_msg] (mut ctx StreamContext) ! {
			return error(error_msg)
		}
		
		// Call stream WITHOUT error handler - should not crash
		// Default behavior logs to console via eprintln
		response := stream(mut writer, callback)
		
		// Verify stream completed (no crash)
		if response.status_code != 200 {
			println('  Iteration ${i}: Unexpected status code ${response.status_code}')
			return false
		}
		
		// Verify stream was closed
		if !writer.closed {
			println('  Iteration ${i}: Stream should be closed after error')
			return false
		}
	}
	
	return true
}

// Test 8e: Error handler called with correct error type
fn test_property_8e_error_type_preserved() bool {
	rand.seed([u32(time.now().unix()), u32(88885)])
	
	for i in 0 .. test_iterations {
		reset_error_tracking()
		
		// Generate random error message
		error_msg := generate_random_error_message(50)
		
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Define callback that throws an error
		callback := fn [error_msg] (mut ctx StreamContext) ! {
			return error(error_msg)
		}
		
		// Define error handler that checks error type
		error_handler := fn [error_msg] (err IError, mut ctx StreamContext) {
			error_handler_called = true
			// Verify error message matches
			if err.msg() == error_msg {
				error_handler_write_success = true
			}
		}
		
		// Call stream with error handler
		_ := stream(mut writer, callback, error_handler)
		
		// Verify error handler was called with correct error
		if !error_handler_called {
			println('  Iteration ${i}: Error handler was not called')
			return false
		}
		
		if !error_handler_write_success {
			println('  Iteration ${i}: Error message was not preserved correctly')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 9: 流自动关闭
// Feature: sse-streaming-helper, Property 9
// Validates: Requirements 1.5, 5.2
//
// *For any* stream where the callback completes normally, the stream SHALL be
// automatically closed after callback execution.
// ============================================================================

// Test 9a: Stream is closed after successful callback completion
fn test_property_9a_stream_closed_after_success() bool {
	rand.seed([u32(time.now().unix()), u32(99991)])
	
	for i in 0 .. test_iterations {
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Generate random data to write
		data := generate_random_string(50)
		
		// Define callback that completes successfully
		callback := fn [data] (mut ctx StreamContext) ! {
			ctx.write_string(data)!
		}
		
		// Call stream
		_ := stream(mut writer, callback)
		
		// Verify stream was closed
		if !writer.closed {
			println('  Iteration ${i}: Stream should be closed after callback completes')
			return false
		}
		
		// Verify writer is disconnected
		if writer.connected {
			println('  Iteration ${i}: Writer should be disconnected after close')
			return false
		}
	}
	
	return true
}

// Test 9b: Stream is closed after callback throws error
fn test_property_9b_stream_closed_after_error() bool {
	rand.seed([u32(time.now().unix()), u32(99992)])
	
	for i in 0 .. test_iterations {
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Generate random error message
		error_msg := generate_random_error_message(30)
		
		// Define callback that throws an error
		callback := fn [error_msg] (mut ctx StreamContext) ! {
			return error(error_msg)
		}
		
		// Call stream (with or without error handler)
		_ := stream(mut writer, callback)
		
		// Verify stream was closed even after error
		if !writer.closed {
			println('  Iteration ${i}: Stream should be closed after error')
			return false
		}
		
		// Verify writer is disconnected
		if writer.connected {
			println('  Iteration ${i}: Writer should be disconnected after close')
			return false
		}
	}
	
	return true
}

// Test 9c: Final chunk marker is written when stream closes
fn test_property_9c_final_chunk_written() bool {
	rand.seed([u32(time.now().unix()), u32(99993)])
	
	for i in 0 .. test_iterations {
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Generate random data to write
		data := generate_random_string(50)
		
		// Define callback that completes successfully
		callback := fn [data] (mut ctx StreamContext) ! {
			ctx.write_string(data)!
		}
		
		// Call stream
		_ := stream(mut writer, callback)
		
		// Verify final chunk marker is present
		written := writer.get_written_string()
		if !written.ends_with('0\r\n\r\n') {
			println('  Iteration ${i}: Missing final chunk marker')
			return false
		}
	}
	
	return true
}

// Test 9d: Stream closed only once (idempotent close)
fn test_property_9d_idempotent_close() bool {
	rand.seed([u32(time.now().unix()), u32(99994)])
	
	for i in 0 .. test_iterations {
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Define callback that manually closes the stream
		callback := fn (mut ctx StreamContext) ! {
			ctx.write_string('test')!
			ctx.close() // Manual close
		}
		
		// Call stream (which will also try to close)
		_ := stream(mut writer, callback)
		
		// Verify stream was closed
		if !writer.closed {
			println('  Iteration ${i}: Stream should be closed')
			return false
		}
		
		// Count final chunk markers - should be exactly one
		written := writer.get_written_string()
		mut final_chunk_count := 0
		mut pos := 0
		for {
			idx := written[pos..].index('0\r\n\r\n') or { break }
			final_chunk_count++
			pos += idx + 5
		}
		
		if final_chunk_count != 1 {
			println('  Iteration ${i}: Expected 1 final chunk marker, got ${final_chunk_count}')
			return false
		}
	}
	
	return true
}

// Test 9e: Stream closed after error handler writes
fn test_property_9e_closed_after_error_handler_writes() bool {
	rand.seed([u32(time.now().unix()), u32(99995)])
	
	for i in 0 .. test_iterations {
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Generate random error response
		error_response := generate_random_string(30)
		
		// Define callback that throws an error
		callback := fn (mut ctx StreamContext) ! {
			return error('Test error')
		}
		
		// Define error handler that writes to stream
		error_handler := fn [error_response] (err IError, mut ctx StreamContext) {
			ctx.write_string(error_response) or {}
		}
		
		// Call stream with error handler
		_ := stream(mut writer, callback, error_handler)
		
		// Verify stream was closed after error handler
		if !writer.closed {
			println('  Iteration ${i}: Stream should be closed after error handler')
			return false
		}
		
		// Verify error response was written before close
		written := writer.get_written_string()
		if !written.contains(error_response) {
			println('  Iteration ${i}: Error response should be written before close')
			return false
		}
		
		// Verify final chunk marker is present
		if !written.ends_with('0\r\n\r\n') {
			println('  Iteration ${i}: Missing final chunk marker')
			return false
		}
	}
	
	return true
}

// Test 9f: Empty callback still closes stream
fn test_property_9f_empty_callback_closes() bool {
	for i in 0 .. test_iterations {
		// Create mock writer
		mut writer := MockStreamWriter.new()
		
		// Define empty callback
		callback := fn (mut ctx StreamContext) ! {
			// Do nothing
		}
		
		// Call stream
		_ := stream(mut writer, callback)
		
		// Verify stream was closed
		if !writer.closed {
			println('  Iteration ${i}: Stream should be closed even with empty callback')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 开始错误处理属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// Run Property 8 tests
	// Feature: sse-streaming-helper, Property 8: 错误处理器调用
	// Validates: Requirements 4.1
	println('--- Property 8: 错误处理器调用 ---')
	stats.run_property_test('Property 8a: Error handler called on error', test_property_8a_error_handler_called)
	stats.run_property_test('Property 8b: Error handler receives context', test_property_8b_error_handler_receives_context)
	stats.run_property_test('Property 8c: Error handler can write', test_property_8c_error_handler_can_write)
	stats.run_property_test('Property 8d: Default error handling', test_property_8d_default_error_handling)
	stats.run_property_test('Property 8e: Error type preserved', test_property_8e_error_type_preserved)

	println('')

	// Run Property 9 tests
	// Feature: sse-streaming-helper, Property 9: 流自动关闭
	// Validates: Requirements 1.5, 5.2
	println('--- Property 9: 流自动关闭 ---')
	stats.run_property_test('Property 9a: Stream closed after success', test_property_9a_stream_closed_after_success)
	stats.run_property_test('Property 9b: Stream closed after error', test_property_9b_stream_closed_after_error)
	stats.run_property_test('Property 9c: Final chunk written', test_property_9c_final_chunk_written)
	stats.run_property_test('Property 9d: Idempotent close', test_property_9d_idempotent_close)
	stats.run_property_test('Property 9e: Closed after error handler writes', test_property_9e_closed_after_error_handler_writes)
	stats.run_property_test('Property 9f: Empty callback closes stream', test_property_9f_empty_callback_closes)

	// Print summary
	stats.print_summary()
}
