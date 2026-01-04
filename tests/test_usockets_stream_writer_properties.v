// test_usockets_stream_writer_properties.v
// Property-Based Testing for UsocketsStreamWriter chunked encoding
// Feature: sse-streaming-helper, Property 10: Chunked 编码格式正确性
// Validates: Requirements 7.2
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
	println('\n=== UsocketsStreamWriter 属性测试总结 ===')
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
// Chunked Encoding Functions (copied from streaming.v for testing)
// ============================================================================

// format_chunk_size - Format the chunk size as hex followed by CRLF
@[inline]
fn format_chunk_size(size int) string {
	return '${size:x}\r\n'
}

// format_chunk - Format a complete chunk with size, data, and trailing CRLF
fn format_chunk(data []u8) string {
	if data.len == 0 {
		return ''
	}
	return '${data.len:x}\r\n${data.bytestr()}\r\n'
}

// format_chunk_string - Format a string as a complete chunk
fn format_chunk_string(data string) string {
	if data.len == 0 {
		return ''
	}
	return '${data.len:x}\r\n${data}\r\n'
}

// format_final_chunk - Return the final chunk marker for chunked encoding
fn format_final_chunk() string {
	return '0\r\n\r\n'
}

// ============================================================================
// Random Data Generators
// ============================================================================

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

// ============================================================================
// Chunk Parsing Helper
// ============================================================================

// Parse a chunked encoded string and extract the data
fn parse_chunked_data(chunked string) !([]u8, bool) {
	mut crlf_pos := -1
	for i := 0; i < chunked.len - 1; i++ {
		if chunked[i] == `\r` && chunked[i + 1] == `\n` {
			crlf_pos = i
			break
		}
	}
	
	if crlf_pos == -1 {
		return error('No CRLF found in chunk header')
	}
	
	size_hex := chunked[..crlf_pos]
	size := parse_hex(size_hex) or {
		return error('Invalid hex size: ${size_hex}')
	}
	
	data_start := crlf_pos + 2
	data_end := data_start + size
	
	if data_end > chunked.len {
		return error('Chunk data incomplete')
	}
	
	data := chunked[data_start..data_end].bytes()
	
	if data_end + 2 > chunked.len {
		return error('Missing trailing CRLF')
	}
	
	trailing := chunked[data_end..data_end + 2]
	if trailing != '\r\n' {
		return error('Invalid trailing CRLF: got "${trailing}"')
	}
	
	return data, true
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


// ============================================================================
// Mock Socket for Testing UsocketsStreamWriter
// ============================================================================

// MockSocket - A mock socket that captures written data for testing
struct MockSocket {
mut:
	buffer    string
	is_closed bool
}

fn MockSocket.new() MockSocket {
	return MockSocket{
		buffer: ''
		is_closed: false
	}
}

fn (mut s MockSocket) write_bytes(data string) int {
	if s.is_closed {
		return 0
	}
	s.buffer += data
	return data.len
}

fn (s MockSocket) get_buffer() string {
	return s.buffer
}

fn (mut s MockSocket) clear() {
	s.buffer = ''
}

// ============================================================================
// UsocketsStreamWriter Simulation for Testing
// Uses the same chunked encoding logic as the real implementation
// ============================================================================

struct TestUsocketsStreamWriter {
mut:
	socket    &MockSocket
	connected bool
}

fn TestUsocketsStreamWriter.new(socket &MockSocket) TestUsocketsStreamWriter {
	return TestUsocketsStreamWriter{
		socket: unsafe { socket }
		connected: true
	}
}

fn (mut w TestUsocketsStreamWriter) write(data []u8) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	chunk_header := format_chunk_size(data.len)
	w.socket.write_bytes(chunk_header)
	w.socket.write_bytes(data.bytestr())
	w.socket.write_bytes('\r\n')
}

fn (mut w TestUsocketsStreamWriter) write_string(data string) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	chunk_header := format_chunk_size(data.len)
	w.socket.write_bytes(chunk_header)
	w.socket.write_bytes(data)
	w.socket.write_bytes('\r\n')
}

fn (mut w TestUsocketsStreamWriter) close() ! {
	if w.connected {
		w.socket.write_bytes('0\r\n\r\n')
		w.connected = false
	}
}

fn (w TestUsocketsStreamWriter) is_connected() bool {
	return w.connected
}


// ============================================================================
// Property 10: Chunked 编码格式正确性
// Feature: sse-streaming-helper, Property 10: Chunked 编码格式正确性
// Validates: Requirements 7.2
//
// *For any* data written to the stream, the output SHALL follow HTTP chunked 
// transfer encoding format:
// - Each chunk starts with the hex size followed by \r\n
// - Chunk data followed by \r\n
// - Final chunk is 0\r\n\r\n
// ============================================================================

// Test 10a: UsocketsStreamWriter.write produces valid chunked encoding for bytes
fn test_property_10a_usockets_write_bytes() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		mut mock_socket := MockSocket.new()
		mut writer := TestUsocketsStreamWriter.new(&mock_socket)
		
		// Generate random data
		data := generate_random_bytes(1000)
		
		// Write using the writer
		writer.write(data) or {
			println('  Iteration ${i}: Write failed: ${err}')
			return false
		}
		
		// Get the output
		output := mock_socket.get_buffer()
		
		// Verify chunk format
		mut crlf_pos := -1
		for j := 0; j < output.len - 1; j++ {
			if output[j] == `\r` && output[j + 1] == `\n` {
				crlf_pos = j
				break
			}
		}
		
		if crlf_pos == -1 {
			println('  Iteration ${i}: No CRLF found in chunk header')
			return false
		}
		
		size_hex := output[..crlf_pos]
		parsed_size := parse_hex(size_hex) or {
			println('  Iteration ${i}: Invalid hex size: ${size_hex}')
			return false
		}
		
		if parsed_size != data.len {
			println('  Iteration ${i}: Size mismatch - expected ${data.len}, got ${parsed_size}')
			return false
		}
		
		// Extract and verify data
		extracted_data, _ := parse_chunked_data(output) or {
			println('  Iteration ${i}: Failed to parse chunk: ${err}')
			return false
		}
		
		if extracted_data != data {
			println('  Iteration ${i}: Data mismatch after extraction')
			return false
		}
	}
	
	return true
}

// Test 10b: UsocketsStreamWriter.write_string produces valid chunked encoding
fn test_property_10b_usockets_write_string() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		mut mock_socket := MockSocket.new()
		mut writer := TestUsocketsStreamWriter.new(&mock_socket)
		
		// Generate random string
		data := generate_random_string(500)
		
		// Write using the writer
		writer.write_string(data) or {
			println('  Iteration ${i}: Write failed: ${err}')
			return false
		}
		
		// Get the output
		output := mock_socket.get_buffer()
		
		// Verify chunk format
		mut crlf_pos := -1
		for j := 0; j < output.len - 1; j++ {
			if output[j] == `\r` && output[j + 1] == `\n` {
				crlf_pos = j
				break
			}
		}
		
		if crlf_pos == -1 {
			println('  Iteration ${i}: No CRLF found in chunk header')
			return false
		}
		
		size_hex := output[..crlf_pos]
		parsed_size := parse_hex(size_hex) or {
			println('  Iteration ${i}: Invalid hex size: ${size_hex}')
			return false
		}
		
		if parsed_size != data.len {
			println('  Iteration ${i}: Size mismatch - expected ${data.len}, got ${parsed_size}')
			return false
		}
		
		// Extract and verify data
		extracted_data, _ := parse_chunked_data(output) or {
			println('  Iteration ${i}: Failed to parse chunk: ${err}')
			return false
		}
		
		if extracted_data.bytestr() != data {
			println('  Iteration ${i}: String mismatch after extraction')
			return false
		}
	}
	
	return true
}


// Test 10c: UsocketsStreamWriter.close produces correct final chunk
fn test_property_10c_usockets_close_final_chunk() bool {
	mut mock_socket := MockSocket.new()
	mut writer := TestUsocketsStreamWriter.new(&mock_socket)
	
	// Close the writer
	writer.close() or {
		println('  Close failed: ${err}')
		return false
	}
	
	// Get the output
	output := mock_socket.get_buffer()
	
	// Final chunk must be exactly "0\r\n\r\n"
	expected := '0\r\n\r\n'
	
	if output != expected {
		println('  Final chunk mismatch - expected "${expected}", got "${output}"')
		return false
	}
	
	// Verify writer is now disconnected
	if writer.is_connected() {
		println('  Writer should be disconnected after close')
		return false
	}
	
	return true
}

// Test 10d: UsocketsStreamWriter handles empty data correctly
fn test_property_10d_usockets_empty_data() bool {
	mut mock_socket := MockSocket.new()
	mut writer := TestUsocketsStreamWriter.new(&mock_socket)
	
	// Write empty byte array
	writer.write([]u8{}) or {
		println('  Empty write failed: ${err}')
		return false
	}
	
	// Buffer should be empty (no chunk for empty data)
	if mock_socket.get_buffer() != '' {
		println('  Empty bytes should produce no output, got "${mock_socket.get_buffer()}"')
		return false
	}
	
	// Write empty string
	writer.write_string('') or {
		println('  Empty string write failed: ${err}')
		return false
	}
	
	// Buffer should still be empty
	if mock_socket.get_buffer() != '' {
		println('  Empty string should produce no output, got "${mock_socket.get_buffer()}"')
		return false
	}
	
	return true
}

// Test 10e: UsocketsStreamWriter rejects writes after close
fn test_property_10e_usockets_write_after_close() bool {
	mut mock_socket := MockSocket.new()
	mut writer := TestUsocketsStreamWriter.new(&mock_socket)
	
	// Close the writer
	writer.close() or {
		println('  Close failed: ${err}')
		return false
	}
	
	mock_socket.clear()
	
	// Try to write after close - should fail
	writer.write([u8(1), 2, 3]) or {
		// Expected error
		return true
	}
	
	println('  Write after close should have failed')
	return false
}

// Test 10f: UsocketsStreamWriter multiple writes produce valid chunks
fn test_property_10f_usockets_multiple_writes() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		mut mock_socket := MockSocket.new()
		mut writer := TestUsocketsStreamWriter.new(&mock_socket)
		
		// Generate multiple random data chunks
		num_chunks := rand.int_in_range(2, 10) or { 3 }
		mut all_data := [][]u8{}
		
		for _ in 0 .. num_chunks {
			data := generate_random_bytes(100)
			all_data << data
			writer.write(data) or {
				println('  Iteration ${i}: Write failed: ${err}')
				return false
			}
		}
		
		// Close to add final chunk
		writer.close() or {
			println('  Iteration ${i}: Close failed: ${err}')
			return false
		}
		
		// Parse all chunks from output
		output := mock_socket.get_buffer()
		mut pos := 0
		mut chunk_idx := 0
		
		for pos < output.len && chunk_idx < all_data.len {
			// Find CRLF for size
			mut crlf_pos := -1
			for j := pos; j < output.len - 1; j++ {
				if output[j] == `\r` && output[j + 1] == `\n` {
					crlf_pos = j
					break
				}
			}
			
			if crlf_pos == -1 {
				println('  Iteration ${i}: No CRLF found at chunk ${chunk_idx}')
				return false
			}
			
			size_hex := output[pos..crlf_pos]
			size := parse_hex(size_hex) or {
				println('  Iteration ${i}: Invalid hex at chunk ${chunk_idx}')
				return false
			}
			
			// Check for final chunk
			if size == 0 {
				break
			}
			
			// Verify size matches expected
			if size != all_data[chunk_idx].len {
				println('  Iteration ${i}: Size mismatch at chunk ${chunk_idx}')
				return false
			}
			
			// Extract data
			data_start := crlf_pos + 2
			data_end := data_start + size
			extracted := output[data_start..data_end].bytes()
			
			if extracted != all_data[chunk_idx] {
				println('  Iteration ${i}: Data mismatch at chunk ${chunk_idx}')
				return false
			}
			
			// Move to next chunk (skip trailing CRLF)
			pos = data_end + 2
			chunk_idx++
		}
		
		// Verify all chunks were found
		if chunk_idx != all_data.len {
			println('  Iteration ${i}: Expected ${all_data.len} chunks, found ${chunk_idx}')
			return false
		}
		
		// Verify final chunk exists
		if !output.ends_with('0\r\n\r\n') {
			println('  Iteration ${i}: Missing final chunk')
			return false
		}
	}
	
	return true
}


// Test 10g: Round-trip property for UsocketsStreamWriter
fn test_property_10g_usockets_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(77777)])
	
	for i in 0 .. test_iterations {
		mut mock_socket := MockSocket.new()
		mut writer := TestUsocketsStreamWriter.new(&mock_socket)
		
		// Generate random data
		original := generate_random_bytes(500)
		
		// Write using the writer
		writer.write(original) or {
			println('  Iteration ${i}: Write failed: ${err}')
			return false
		}
		
		// Parse back
		output := mock_socket.get_buffer()
		recovered, _ := parse_chunked_data(output) or {
			println('  Iteration ${i}: Failed to parse: ${err}')
			return false
		}
		
		// Verify round-trip
		if recovered != original {
			println('  Iteration ${i}: Round-trip failed - data mismatch')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 开始 UsocketsStreamWriter 属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// Run Property 10 tests for UsocketsStreamWriter
	// Feature: sse-streaming-helper, Property 10: Chunked 编码格式正确性
	// Validates: Requirements 7.2
	stats.run_property_test('Property 10a: UsocketsStreamWriter.write bytes encoding', test_property_10a_usockets_write_bytes)
	stats.run_property_test('Property 10b: UsocketsStreamWriter.write_string encoding', test_property_10b_usockets_write_string)
	stats.run_property_test('Property 10c: UsocketsStreamWriter.close final chunk', test_property_10c_usockets_close_final_chunk)
	stats.run_property_test('Property 10d: UsocketsStreamWriter empty data handling', test_property_10d_usockets_empty_data)
	stats.run_property_test('Property 10e: UsocketsStreamWriter write after close', test_property_10e_usockets_write_after_close)
	stats.run_property_test('Property 10f: UsocketsStreamWriter multiple writes', test_property_10f_usockets_multiple_writes)
	stats.run_property_test('Property 10g: UsocketsStreamWriter round-trip', test_property_10g_usockets_roundtrip)

	// Print summary
	stats.print_summary()
}
