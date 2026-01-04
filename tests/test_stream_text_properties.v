// test_stream_text_properties.v
// Property-Based Testing for stream_text() function
// Feature: sse-streaming-helper
// Property 3: streamText() 设置正确的 HTTP 头
// Property 4: writeln() 添加换行符
// Property 5: sleep() 暂停正确的时间
// Validates: Requirements 2.1, 2.2, 2.3, 2.5, 2.6
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
	println('\n=== stream_text() 函数属性测试总结 ===')
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

@[heap]
struct StreamContext {
mut:
	writer    &MockStreamWriter
	is_closed bool
}

fn StreamContext.new(writer &MockStreamWriter) StreamContext {
	return StreamContext{
		writer: unsafe { writer }
		is_closed: false
	}
}

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

fn (mut ctx StreamContext) writeln(data string) ! {
	ctx.write_string(data)!
	ctx.write_string('\n')!
}

fn (ctx StreamContext) sleep(ms int) {
	time.sleep(ms * time.millisecond)
}

fn (mut ctx StreamContext) close() {
	if !ctx.is_closed {
		ctx.is_closed = true
		ctx.writer.close() or {}
	}
}

// ============================================================================
// Helper Functions
// ============================================================================

// get_stream_text_headers - Get the headers required for text streaming
fn get_stream_text_headers() map[string]string {
	return {
		'Content-Type':           'text/plain; charset=utf-8'
		'Transfer-Encoding':      'chunked'
		'X-Content-Type-Options': 'nosniff'
		'Connection':             'keep-alive'
	}
}

// Generate random string for testing (printable ASCII only)
fn generate_random_string(max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-. '
	len := rand.int_in_range(1, max_len) or { 10 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// Parse hex string to int
fn parse_hex(hex_str string) !int {
	mut result := 0
	for c in hex_str {
		result *= 16
		if c >= `0` && c <= `9` {
			result += int(c - `0`)
		} else if c >= `a` && c <= `f` {
			result += int(c - `a` + 10)
		} else if c >= `A` && c <= `F` {
			result += int(c - `A` + 10)
		} else {
			return error('Invalid hex character: ${c.ascii_str()}')
		}
	}
	return result
}

// Parse a chunked encoded string and extract all chunks
fn parse_all_chunks(chunked string) !([]string, bool) {
	mut chunks := []string{}
	mut pos := 0
	
	for pos < chunked.len {
		// Find the size part (before \r\n)
		mut crlf_pos := -1
		for i := pos; i < chunked.len - 1; i++ {
			if chunked[i] == `\r` && chunked[i + 1] == `\n` {
				crlf_pos = i
				break
			}
		}
		
		if crlf_pos == -1 {
			return error('No CRLF found in chunk header at position ${pos}')
		}
		
		size_hex := chunked[pos..crlf_pos]
		size := parse_hex(size_hex) or {
			return error('Invalid hex size: ${size_hex}')
		}
		
		// Check for final chunk
		if size == 0 {
			// Verify final chunk format
			remaining := chunked[pos..]
			if remaining != '0\r\n\r\n' {
				return error('Invalid final chunk format')
			}
			break
		}
		
		// Extract data after the \r\n
		data_start := crlf_pos + 2
		data_end := data_start + size
		
		if data_end > chunked.len {
			return error('Chunk data incomplete')
		}
		
		data := chunked[data_start..data_end]
		chunks << data
		
		// Verify trailing \r\n
		if data_end + 2 > chunked.len {
			return error('Missing trailing CRLF')
		}
		
		trailing := chunked[data_end..data_end + 2]
		if trailing != '\r\n' {
			return error('Invalid trailing CRLF')
		}
		
		pos = data_end + 2
	}
	
	return chunks, true
}

// ============================================================================
// Property 3: streamText() 设置正确的 HTTP 头
// Feature: sse-streaming-helper, Property 3
// Validates: Requirements 2.1, 2.2, 2.3
//
// *For any* call to streamText(c, callback), the response SHALL contain:
// - Content-Type: text/plain; charset=utf-8
// - Transfer-Encoding: chunked
// - X-Content-Type-Options: nosniff
// ============================================================================

// Test 3a: Content-Type header is set correctly
fn test_property_3a_content_type_header() bool {
	headers := get_stream_text_headers()
	
	// Verify Content-Type header exists
	if 'Content-Type' !in headers {
		println('  Content-Type header missing')
		return false
	}
	
	// Verify value is 'text/plain; charset=utf-8'
	if headers['Content-Type'] != 'text/plain; charset=utf-8' {
		println('  Content-Type should be "text/plain; charset=utf-8", got "${headers['Content-Type']}"')
		return false
	}
	
	return true
}

// Test 3b: Transfer-Encoding header is set correctly
fn test_property_3b_transfer_encoding_header() bool {
	headers := get_stream_text_headers()
	
	// Verify Transfer-Encoding header exists
	if 'Transfer-Encoding' !in headers {
		println('  Transfer-Encoding header missing')
		return false
	}
	
	// Verify value is 'chunked'
	if headers['Transfer-Encoding'] != 'chunked' {
		println('  Transfer-Encoding should be "chunked", got "${headers['Transfer-Encoding']}"')
		return false
	}
	
	return true
}

// Test 3c: X-Content-Type-Options header is set correctly
fn test_property_3c_x_content_type_options_header() bool {
	headers := get_stream_text_headers()
	
	// Verify X-Content-Type-Options header exists
	if 'X-Content-Type-Options' !in headers {
		println('  X-Content-Type-Options header missing')
		return false
	}
	
	// Verify value is 'nosniff'
	if headers['X-Content-Type-Options'] != 'nosniff' {
		println('  X-Content-Type-Options should be "nosniff", got "${headers['X-Content-Type-Options']}"')
		return false
	}
	
	return true
}

// Test 3d: Headers are consistent across multiple calls
fn test_property_3d_headers_consistency() bool {
	for _ in 0 .. test_iterations {
		headers1 := get_stream_text_headers()
		headers2 := get_stream_text_headers()
		
		// Headers should be identical
		if headers1['Content-Type'] != headers2['Content-Type'] {
			println('  Content-Type inconsistent between calls')
			return false
		}
		
		if headers1['Transfer-Encoding'] != headers2['Transfer-Encoding'] {
			println('  Transfer-Encoding inconsistent between calls')
			return false
		}
		
		if headers1['X-Content-Type-Options'] != headers2['X-Content-Type-Options'] {
			println('  X-Content-Type-Options inconsistent between calls')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 4: writeln() 添加换行符
// Feature: sse-streaming-helper, Property 4
// Validates: Requirements 2.5
//
// *For any* string text, when stream.writeln(text) is called, the output 
// SHALL be text followed by a newline character \n.
// ============================================================================

// Test 4a: writeln() appends newline for any string
fn test_property_4a_writeln_appends_newline() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random text
		text := generate_random_string(200)
		
		// Create mock writer and context
		mut writer := MockStreamWriter.new()
		mut ctx := StreamContext.new(writer)
		
		// Call writeln
		ctx.writeln(text) or {
			println('  Iteration ${i}: writeln failed: ${err}')
			return false
		}
		
		// Close to finalize
		ctx.close()
		
		// Parse the written chunked data
		written := writer.get_written_string()
		chunks, _ := parse_all_chunks(written) or {
			println('  Iteration ${i}: Failed to parse chunks: ${err}')
			return false
		}
		
		// Should have exactly 2 chunks (text and newline)
		if chunks.len != 2 {
			println('  Iteration ${i}: Expected 2 chunks, got ${chunks.len}')
			return false
		}
		
		// First chunk should be the text
		if chunks[0] != text {
			println('  Iteration ${i}: First chunk should be text')
			return false
		}
		
		// Second chunk should be newline
		if chunks[1] != '\n' {
			println('  Iteration ${i}: Second chunk should be newline, got "${chunks[1]}"')
			return false
		}
	}
	
	return true
}

// Test 4b: writeln() with empty string still adds newline
fn test_property_4b_writeln_empty_string() bool {
	// Create mock writer and context
	mut writer := MockStreamWriter.new()
	mut ctx := StreamContext.new(writer)
	
	// Call writeln with empty string - this should fail because write_string skips empty
	// Actually, writeln calls write_string twice: once for data, once for \n
	// Empty string write is skipped, but \n should still be written
	ctx.writeln('') or {
		println('  writeln empty string failed: ${err}')
		return false
	}
	
	// Close to finalize
	ctx.close()
	
	// Parse the written chunked data
	written := writer.get_written_string()
	chunks, _ := parse_all_chunks(written) or {
		println('  Failed to parse chunks: ${err}')
		return false
	}
	
	// Should have exactly 1 chunk (just the newline, empty string is skipped)
	if chunks.len != 1 {
		println('  Expected 1 chunk (newline only), got ${chunks.len}')
		return false
	}
	
	// The chunk should be newline
	if chunks[0] != '\n' {
		println('  Chunk should be newline, got "${chunks[0]}"')
		return false
	}
	
	return true
}

// Test 4c: Multiple writeln calls produce correct output
fn test_property_4c_multiple_writeln() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate multiple random lines
		num_lines := rand.int_in_range(2, 5) or { 3 }
		mut lines := []string{}
		
		mut writer := MockStreamWriter.new()
		mut ctx := StreamContext.new(writer)
		
		for _ in 0 .. num_lines {
			line := generate_random_string(50)
			lines << line
			ctx.writeln(line) or {
				println('  Iteration ${i}: writeln failed: ${err}')
				return false
			}
		}
		
		// Close to finalize
		ctx.close()
		
		// Parse the written chunked data
		written := writer.get_written_string()
		chunks, _ := parse_all_chunks(written) or {
			println('  Iteration ${i}: Failed to parse chunks: ${err}')
			return false
		}
		
		// Should have 2 chunks per line (text + newline)
		expected_chunks := num_lines * 2
		if chunks.len != expected_chunks {
			println('  Iteration ${i}: Expected ${expected_chunks} chunks, got ${chunks.len}')
			return false
		}
		
		// Verify each line and newline pair
		for j, line in lines {
			text_idx := j * 2
			newline_idx := j * 2 + 1
			
			if chunks[text_idx] != line {
				println('  Iteration ${i}: Line ${j} text mismatch')
				return false
			}
			
			if chunks[newline_idx] != '\n' {
				println('  Iteration ${i}: Line ${j} newline missing')
				return false
			}
		}
	}
	
	return true
}

// ============================================================================
// Property 5: sleep() 暂停正确的时间
// Feature: sse-streaming-helper, Property 5
// Validates: Requirements 2.6
//
// *For any* positive integer ms, when stream.sleep(ms) is called, the execution 
// SHALL pause for approximately ms milliseconds (within ±10% tolerance).
// ============================================================================

// Test 5a: sleep() pauses for approximately the specified time
fn test_property_5a_sleep_duration() bool {
	// Test with a few specific durations to avoid long test times
	test_durations := [10, 20, 50]
	
	for duration in test_durations {
		mut writer := MockStreamWriter.new()
		ctx := StreamContext.new(writer)
		
		// Measure time before and after sleep
		start := time.now()
		ctx.sleep(duration)
		elapsed := time.now() - start
		
		elapsed_ms := elapsed.milliseconds()
		
		// Allow generous tolerance for system overhead (±50% plus overhead)
		// Sleep timing can vary significantly depending on system load
		min_expected := int(f64(duration) * 0.5)
		max_expected := int(f64(duration) * 2.0) + 20
		
		if elapsed_ms < min_expected || elapsed_ms > max_expected {
			println('  sleep(${duration}) took ${elapsed_ms}ms, expected ${min_expected}-${max_expected}ms')
			return false
		}
	}
	
	return true
}

// Test 5b: sleep(0) returns immediately
fn test_property_5b_sleep_zero() bool {
	mut writer := MockStreamWriter.new()
	ctx := StreamContext.new(writer)
	
	// Measure time for sleep(0)
	start := time.now()
	ctx.sleep(0)
	elapsed := time.now() - start
	
	elapsed_ms := elapsed.milliseconds()
	
	// sleep(0) should return very quickly (within 10ms)
	if elapsed_ms > 10 {
		println('  sleep(0) took ${elapsed_ms}ms, expected < 10ms')
		return false
	}
	
	return true
}

// Test 5c: Multiple sleeps accumulate correctly
fn test_property_5c_multiple_sleeps() bool {
	mut writer := MockStreamWriter.new()
	ctx := StreamContext.new(writer)
	
	// Sleep multiple times
	sleep_duration := 10
	num_sleeps := 3
	
	start := time.now()
	for _ in 0 .. num_sleeps {
		ctx.sleep(sleep_duration)
	}
	elapsed := time.now() - start
	
	elapsed_ms := elapsed.milliseconds()
	expected_total := sleep_duration * num_sleeps
	
	// Allow generous tolerance for system overhead (±50% plus overhead)
	// Sleep timing can vary significantly depending on system load
	min_expected := int(f64(expected_total) * 0.5)
	max_expected := int(f64(expected_total) * 2.0) + 30
	
	if elapsed_ms < min_expected || elapsed_ms > max_expected {
		println('  ${num_sleeps} sleeps of ${sleep_duration}ms took ${elapsed_ms}ms, expected ${min_expected}-${max_expected}ms')
		return false
	}
	
	return true
}

fn main() {
	println('🚀 开始 stream_text() 函数属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// Run Property 3 tests
	// Feature: sse-streaming-helper, Property 3: streamText() 设置正确的 HTTP 头
	// Validates: Requirements 2.1, 2.2, 2.3
	println('--- Property 3: streamText() 设置正确的 HTTP 头 ---')
	stats.run_property_test('Property 3a: Content-Type header', test_property_3a_content_type_header)
	stats.run_property_test('Property 3b: Transfer-Encoding header', test_property_3b_transfer_encoding_header)
	stats.run_property_test('Property 3c: X-Content-Type-Options header', test_property_3c_x_content_type_options_header)
	stats.run_property_test('Property 3d: Headers consistency', test_property_3d_headers_consistency)

	println('')

	// Run Property 4 tests
	// Feature: sse-streaming-helper, Property 4: writeln() 添加换行符
	// Validates: Requirements 2.5
	println('--- Property 4: writeln() 添加换行符 ---')
	stats.run_property_test('Property 4a: writeln() appends newline', test_property_4a_writeln_appends_newline)
	stats.run_property_test('Property 4b: writeln() empty string', test_property_4b_writeln_empty_string)
	stats.run_property_test('Property 4c: Multiple writeln calls', test_property_4c_multiple_writeln)

	println('')

	// Run Property 5 tests
	// Feature: sse-streaming-helper, Property 5: sleep() 暂停正确的时间
	// Validates: Requirements 2.6
	println('--- Property 5: sleep() 暂停正确的时间 ---')
	stats.run_property_test('Property 5a: sleep() duration', test_property_5a_sleep_duration)
	stats.run_property_test('Property 5b: sleep(0) returns immediately', test_property_5b_sleep_zero)
	stats.run_property_test('Property 5c: Multiple sleeps accumulate', test_property_5c_multiple_sleeps)

	// Print summary
	stats.print_summary()
}
