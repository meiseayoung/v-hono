// test_stream_function_properties.v
// Property-Based Testing for stream() function
// Feature: sse-streaming-helper
// Property 1: stream() 设置正确的 Transfer-Encoding 头
// Property 2: write() 正确输出数据
// Validates: Requirements 1.1, 1.2
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
	println('\n=== stream() 函数属性测试总结 ===')
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
// Helper Functions
// ============================================================================

// get_stream_headers - Get the headers required for basic streaming
fn get_stream_headers() map[string]string {
	return {
		'Transfer-Encoding': 'chunked'
		'Connection':        'keep-alive'
	}
}

// Generate random bytes for testing
fn generate_random_bytes(max_len int) []u8 {
	len := rand.int_in_range(1, max_len) or { 10 }
	mut data := []u8{len: len}
	for i in 0 .. len {
		data[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	return data
}

// Generate random string for testing (printable ASCII only)
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
fn parse_all_chunks(chunked string) !([][]u8, bool) {
	mut chunks := [][]u8{}
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
		
		data := chunked[data_start..data_end].bytes()
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
// Property 1: stream() 设置正确的 Transfer-Encoding 头
// Feature: sse-streaming-helper, Property 1
// Validates: Requirements 1.1
//
// *For any* call to stream(c, callback), the response SHALL contain 
// Transfer-Encoding: chunked header.
// ============================================================================

// Test 1a: get_stream_headers returns Transfer-Encoding: chunked
fn test_property_1a_transfer_encoding_header() bool {
	headers := get_stream_headers()
	
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

// Test 1b: get_stream_headers returns Connection: keep-alive
fn test_property_1b_connection_header() bool {
	headers := get_stream_headers()
	
	// Verify Connection header exists
	if 'Connection' !in headers {
		println('  Connection header missing')
		return false
	}
	
	// Verify value is 'keep-alive'
	if headers['Connection'] != 'keep-alive' {
		println('  Connection should be "keep-alive", got "${headers['Connection']}"')
		return false
	}
	
	return true
}

// Test 1c: Headers are consistent across multiple calls
fn test_property_1c_headers_consistency() bool {
	for _ in 0 .. test_iterations {
		headers1 := get_stream_headers()
		headers2 := get_stream_headers()
		
		// Headers should be identical
		if headers1['Transfer-Encoding'] != headers2['Transfer-Encoding'] {
			println('  Transfer-Encoding inconsistent between calls')
			return false
		}
		
		if headers1['Connection'] != headers2['Connection'] {
			println('  Connection inconsistent between calls')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 2: write() 正确输出数据
// Feature: sse-streaming-helper, Property 2
// Validates: Requirements 1.2
//
// *For any* byte array data, when stream.write(data) is called, the output 
// stream SHALL contain the exact bytes from data in chunked transfer encoding format.
// ============================================================================

// Test 2a: write() outputs data in chunked format for any byte array
fn test_property_2a_write_bytes_chunked() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random data
		data := generate_random_bytes(500)
		
		// Create mock writer and write data
		mut writer := MockStreamWriter.new()
		writer.write(data) or {
			println('  Iteration ${i}: write failed: ${err}')
			return false
		}
		
		// Parse the written chunked data
		written := writer.get_written_string()
		chunks, _ := parse_all_chunks(written + '0\r\n\r\n') or {
			println('  Iteration ${i}: Failed to parse chunks: ${err}')
			return false
		}
		
		// Should have exactly one chunk
		if chunks.len != 1 {
			println('  Iteration ${i}: Expected 1 chunk, got ${chunks.len}')
			return false
		}
		
		// Chunk data should match original
		if chunks[0] != data {
			println('  Iteration ${i}: Data mismatch')
			return false
		}
	}
	
	return true
}

// Test 2b: write_string() outputs data in chunked format for any string
fn test_property_2b_write_string_chunked() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate random string
		data := generate_random_string(500)
		
		// Create mock writer and write data
		mut writer := MockStreamWriter.new()
		writer.write_string(data) or {
			println('  Iteration ${i}: write_string failed: ${err}')
			return false
		}
		
		// Parse the written chunked data
		written := writer.get_written_string()
		chunks, _ := parse_all_chunks(written + '0\r\n\r\n') or {
			println('  Iteration ${i}: Failed to parse chunks: ${err}')
			return false
		}
		
		// Should have exactly one chunk
		if chunks.len != 1 {
			println('  Iteration ${i}: Expected 1 chunk, got ${chunks.len}')
			return false
		}
		
		// Chunk data should match original string
		if chunks[0].bytestr() != data {
			println('  Iteration ${i}: String mismatch')
			return false
		}
	}
	
	return true
}

// Test 2c: Multiple writes produce multiple chunks
fn test_property_2c_multiple_writes() bool {
	rand.seed([u32(time.now().unix()), u32(98765)])
	
	for i in 0 .. test_iterations {
		// Generate multiple random data pieces
		num_writes := rand.int_in_range(2, 10) or { 3 }
		mut original_data := [][]u8{}
		
		mut writer := MockStreamWriter.new()
		
		for _ in 0 .. num_writes {
			data := generate_random_bytes(100)
			original_data << data
			writer.write(data) or {
				println('  Iteration ${i}: write failed: ${err}')
				return false
			}
		}
		
		// Parse the written chunked data
		written := writer.get_written_string()
		chunks, _ := parse_all_chunks(written + '0\r\n\r\n') or {
			println('  Iteration ${i}: Failed to parse chunks: ${err}')
			return false
		}
		
		// Should have same number of chunks as writes
		if chunks.len != num_writes {
			println('  Iteration ${i}: Expected ${num_writes} chunks, got ${chunks.len}')
			return false
		}
		
		// Each chunk should match original data
		for j, chunk in chunks {
			if chunk != original_data[j] {
				println('  Iteration ${i}: Chunk ${j} data mismatch')
				return false
			}
		}
	}
	
	return true
}

// Test 2d: close() writes final chunk marker
fn test_property_2d_close_final_chunk() bool {
	for _ in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		
		// Write some data
		data := generate_random_bytes(50)
		writer.write(data) or {
			println('  write failed')
			return false
		}
		
		// Close the writer
		writer.close() or {
			println('  close failed')
			return false
		}
		
		// Verify final chunk marker is present
		written := writer.get_written_string()
		if !written.ends_with('0\r\n\r\n') {
			println('  Missing final chunk marker')
			return false
		}
		
		// Verify writer is marked as closed
		if writer.connected {
			println('  Writer should be disconnected after close')
			return false
		}
		
		if !writer.closed {
			println('  Writer should be marked as closed')
			return false
		}
	}
	
	return true
}

// Test 2e: Empty data is handled correctly (no chunk written)
fn test_property_2e_empty_data() bool {
	mut writer := MockStreamWriter.new()
	
	// Write empty byte array
	writer.write([]u8{}) or {
		println('  write empty bytes failed')
		return false
	}
	
	// Write empty string
	writer.write_string('') or {
		println('  write empty string failed')
		return false
	}
	
	// No data should be written for empty inputs
	if writer.written_data.len != 0 {
		println('  Empty data should not produce output, got ${writer.written_data.len} bytes')
		return false
	}
	
	return true
}

// Test 2f: Round-trip property - write then parse returns original data
fn test_property_2f_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])
	
	for i in 0 .. test_iterations {
		// Generate random data
		original := generate_random_bytes(500)
		
		// Write to mock writer
		mut writer := MockStreamWriter.new()
		writer.write(original) or {
			println('  Iteration ${i}: write failed')
			return false
		}
		writer.close() or {
			println('  Iteration ${i}: close failed')
			return false
		}
		
		// Parse back
		written := writer.get_written_string()
		chunks, _ := parse_all_chunks(written) or {
			println('  Iteration ${i}: Failed to parse: ${err}')
			return false
		}
		
		// Verify round-trip
		if chunks.len != 1 {
			println('  Iteration ${i}: Expected 1 chunk, got ${chunks.len}')
			return false
		}
		
		if chunks[0] != original {
			println('  Iteration ${i}: Round-trip failed - data mismatch')
			return false
		}
	}
	
	return true
}

// Test 2g: Writing to closed connection returns error
fn test_property_2g_write_after_close() bool {
	mut writer := MockStreamWriter.new()
	
	// Close the writer
	writer.close() or {
		println('  close failed')
		return false
	}
	
	// Try to write - should fail
	writer.write('test'.bytes()) or {
		// Expected error
		return true
	}
	
	println('  Writing to closed connection should fail')
	return false
}

fn main() {
	println('🚀 开始 stream() 函数属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// Run Property 1 tests
	// Feature: sse-streaming-helper, Property 1: stream() 设置正确的 Transfer-Encoding 头
	// Validates: Requirements 1.1
	println('--- Property 1: stream() 设置正确的 Transfer-Encoding 头 ---')
	stats.run_property_test('Property 1a: Transfer-Encoding header', test_property_1a_transfer_encoding_header)
	stats.run_property_test('Property 1b: Connection header', test_property_1b_connection_header)
	stats.run_property_test('Property 1c: Headers consistency', test_property_1c_headers_consistency)

	println('')

	// Run Property 2 tests
	// Feature: sse-streaming-helper, Property 2: write() 正确输出数据
	// Validates: Requirements 1.2
	println('--- Property 2: write() 正确输出数据 ---')
	stats.run_property_test('Property 2a: write() bytes chunked format', test_property_2a_write_bytes_chunked)
	stats.run_property_test('Property 2b: write_string() chunked format', test_property_2b_write_string_chunked)
	stats.run_property_test('Property 2c: Multiple writes produce chunks', test_property_2c_multiple_writes)
	stats.run_property_test('Property 2d: close() writes final chunk', test_property_2d_close_final_chunk)
	stats.run_property_test('Property 2e: Empty data handling', test_property_2e_empty_data)
	stats.run_property_test('Property 2f: Round-trip property', test_property_2f_roundtrip)
	stats.run_property_test('Property 2g: Write after close fails', test_property_2g_write_after_close)

	// Print summary
	stats.print_summary()
}
