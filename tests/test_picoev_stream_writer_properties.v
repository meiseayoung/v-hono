// test_picoev_stream_writer_properties.v
// Property-Based Testing for PicoevStreamWriter chunked encoding
// Feature: sse-streaming-helper, Property 10: Chunked 编码格式正确性
// Validates: Requirements 6.2
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
	println('\n=== PicoevStreamWriter 属性测试总结 ===')
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

// Generate random string for testing (printable ASCII only to avoid encoding issues)
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
// Returns the extracted data and whether parsing was successful
fn parse_chunked_data(chunked string) !([]u8, bool) {
	// Find the size part (before first \r\n)
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
	
	// Extract data after the first \r\n
	data_start := crlf_pos + 2
	data_end := data_start + size
	
	if data_end > chunked.len {
		return error('Chunk data incomplete')
	}
	
	data := chunked[data_start..data_end].bytes()
	
	// Verify trailing \r\n
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
// Property 10: Chunked 编码格式正确性
// Feature: sse-streaming-helper, Property 10: Chunked 编码格式正确性
// Validates: Requirements 6.2
//
// *For any* data written to the stream, the output SHALL follow HTTP chunked 
// transfer encoding format:
// - Each chunk starts with the hex size followed by \r\n
// - Chunk data followed by \r\n
// - Final chunk is 0\r\n\r\n
// ============================================================================

// Test 10a: format_chunk produces valid chunked encoding for any byte array
fn test_property_10a_format_chunk_bytes() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random data
		data := generate_random_bytes(1000)
		
		// Format as chunk
		chunk := format_chunk(data)
		
		// Verify chunk format
		// 1. Should start with hex size
		mut crlf_pos := -1
		for j := 0; j < chunk.len - 1; j++ {
			if chunk[j] == `\r` && chunk[j + 1] == `\n` {
				crlf_pos = j
				break
			}
		}
		
		if crlf_pos == -1 {
			println('  Iteration ${i}: No CRLF found in chunk header')
			return false
		}
		
		size_hex := chunk[..crlf_pos]
		parsed_size := parse_hex(size_hex) or {
			println('  Iteration ${i}: Invalid hex size: ${size_hex}')
			return false
		}
		
		// 2. Size should match data length
		if parsed_size != data.len {
			println('  Iteration ${i}: Size mismatch - expected ${data.len}, got ${parsed_size}')
			return false
		}
		
		// 3. Data should be extractable and match original
		extracted_data, _ := parse_chunked_data(chunk) or {
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

// Test 10b: format_chunk_string produces valid chunked encoding for any string
fn test_property_10b_format_chunk_string() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate random string
		data := generate_random_string(500)
		
		// Format as chunk
		chunk := format_chunk_string(data)
		
		// Verify chunk format
		mut crlf_pos := -1
		for j := 0; j < chunk.len - 1; j++ {
			if chunk[j] == `\r` && chunk[j + 1] == `\n` {
				crlf_pos = j
				break
			}
		}
		
		if crlf_pos == -1 {
			println('  Iteration ${i}: No CRLF found in chunk header')
			return false
		}
		
		size_hex := chunk[..crlf_pos]
		parsed_size := parse_hex(size_hex) or {
			println('  Iteration ${i}: Invalid hex size: ${size_hex}')
			return false
		}
		
		// Size should match string byte length
		if parsed_size != data.len {
			println('  Iteration ${i}: Size mismatch - expected ${data.len}, got ${parsed_size}')
			return false
		}
		
		// Extract and verify data
		extracted_data, _ := parse_chunked_data(chunk) or {
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

// Test 10c: format_final_chunk produces correct terminator
fn test_property_10c_final_chunk_format() bool {
	final_chunk := format_final_chunk()
	
	// Final chunk must be exactly "0\r\n\r\n"
	expected := '0\r\n\r\n'
	
	if final_chunk != expected {
		println('  Final chunk mismatch - expected "${expected}", got "${final_chunk}"')
		return false
	}
	
	// Verify it starts with zero size
	if !final_chunk.starts_with('0\r\n') {
		println('  Final chunk should start with "0\\r\\n"')
		return false
	}
	
	// Verify it ends with empty line (double CRLF after size)
	if !final_chunk.ends_with('\r\n\r\n') {
		println('  Final chunk should end with "\\r\\n\\r\\n"')
		return false
	}
	
	return true
}

// Test 10d: Empty data produces empty string (no chunk)
fn test_property_10d_empty_data_handling() bool {
	// Empty byte array
	empty_bytes := []u8{}
	chunk_bytes := format_chunk(empty_bytes)
	if chunk_bytes != '' {
		println('  Empty bytes should produce empty string, got "${chunk_bytes}"')
		return false
	}
	
	// Empty string
	chunk_string := format_chunk_string('')
	if chunk_string != '' {
		println('  Empty string should produce empty string, got "${chunk_string}"')
		return false
	}
	
	return true
}

// Test 10e: Chunk size is correctly formatted as lowercase hex
fn test_property_10e_hex_format() bool {
	rand.seed([u32(time.now().unix()), u32(98765)])
	
	// Test various sizes including edge cases
	test_sizes := [1, 15, 16, 255, 256, 4095, 4096, 65535]
	
	for size in test_sizes {
		// Create data of specific size
		mut data := []u8{len: size}
		for i in 0 .. size {
			data[i] = u8(i % 256)
		}
		
		chunk := format_chunk(data)
		
		// Extract hex size
		mut crlf_pos := -1
		for j := 0; j < chunk.len - 1; j++ {
			if chunk[j] == `\r` && chunk[j + 1] == `\n` {
				crlf_pos = j
				break
			}
		}
		
		if crlf_pos == -1 {
			println('  Size ${size}: No CRLF found')
			return false
		}
		
		size_hex := chunk[..crlf_pos]
		
		// Verify it's valid lowercase hex
		for c in size_hex {
			is_digit := c >= `0` && c <= `9`
			is_lower_hex := c >= `a` && c <= `f`
			if !is_digit && !is_lower_hex {
				println('  Size ${size}: Invalid hex character "${c.ascii_str()}" in "${size_hex}"')
				return false
			}
		}
		
		// Verify parsed value matches
		parsed := parse_hex(size_hex) or {
			println('  Size ${size}: Failed to parse hex "${size_hex}"')
			return false
		}
		
		if parsed != size {
			println('  Size ${size}: Hex "${size_hex}" parsed as ${parsed}')
			return false
		}
	}
	
	return true
}

// Test 10f: Round-trip property - chunk then parse returns original data
fn test_property_10f_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])
	
	for i in 0 .. test_iterations {
		// Generate random data
		original := generate_random_bytes(500)
		
		// Format as chunk
		chunk := format_chunk(original)
		
		// Parse back
		recovered, _ := parse_chunked_data(chunk) or {
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
	println('🚀 开始 PicoevStreamWriter 属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// Run Property 10 tests
	// Feature: sse-streaming-helper, Property 10: Chunked 编码格式正确性
	// Validates: Requirements 6.2
	stats.run_property_test('Property 10a: format_chunk bytes encoding', test_property_10a_format_chunk_bytes)
	stats.run_property_test('Property 10b: format_chunk_string encoding', test_property_10b_format_chunk_string)
	stats.run_property_test('Property 10c: Final chunk format', test_property_10c_final_chunk_format)
	stats.run_property_test('Property 10d: Empty data handling', test_property_10d_empty_data_handling)
	stats.run_property_test('Property 10e: Hex format correctness', test_property_10e_hex_format)
	stats.run_property_test('Property 10f: Round-trip property', test_property_10f_roundtrip)

	// Print summary
	stats.print_summary()
}
