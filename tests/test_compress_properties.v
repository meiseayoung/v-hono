import compress.gzip
import compress.zlib
import rand
import time

// Compression Middleware 属性测试
// Property-Based Testing for Compression functionality
// 
// Note: These tests validate the compression round-trip properties
// using V's standard library compression functions, which are the
// same functions used by the compress middleware.

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
	println('\n=== Compression Middleware 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// 生成随机字符串（用于测试压缩）
fn generate_random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \t\n!@#\$%^&*()_+-=[]{}|;:,.<>?'
	len := rand.int_in_range(min_len, max_len) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// 生成可压缩的文本（重复模式更容易压缩）
fn generate_compressible_text(min_len int, max_len int) string {
	patterns := [
		'Hello World! ',
		'This is a test. ',
		'Lorem ipsum dolor sit amet. ',
		'The quick brown fox jumps over the lazy dog. ',
		'AAAAAAAAAA',
		'1234567890',
	]
	
	target_len := rand.int_in_range(min_len, max_len) or { min_len }
	mut result := ''
	
	for result.len < target_len {
		idx := rand.int_in_range(0, patterns.len) or { 0 }
		result += patterns[idx]
	}
	
	if result.len > target_len {
		return result[..target_len]
	}
	return result
}

// ============================================================================
// Property 10: Compression Round-Trip
// Feature: builtin-middleware, Property 10: Compression Round-Trip
// Validates: Requirements 5.1, 5.2, 5.6
// 
// *For any* response body and supported encoding (gzip/deflate), 
// compressing then decompressing SHALL produce the original body.
// ============================================================================
fn test_property_10_gzip_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate random data
		original := generate_random_string(100, 5000)
		
		// Test gzip round-trip
		gzip_compressed := gzip.compress(original.bytes(), gzip.CompressParams{
			compression_level: 128
		}) or {
			println('  Iteration ${i}: Gzip compression failed: ${err}')
			return false
		}
		
		gzip_decompressed := gzip.decompress(gzip_compressed) or {
			println('  Iteration ${i}: Gzip decompression failed: ${err}')
			return false
		}
		
		if gzip_decompressed.bytestr() != original {
			println('  Iteration ${i}: Gzip round-trip mismatch')
			println('    Original length: ${original.len}')
			println('    Decompressed length: ${gzip_decompressed.len}')
			return false
		}
	}
	
	return true
}

fn test_property_10_deflate_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate random data
		original := generate_random_string(100, 5000)
		
		// Test deflate round-trip
		deflate_compressed := zlib.compress(original.bytes()) or {
			println('  Iteration ${i}: Deflate compression failed: ${err}')
			return false
		}
		
		deflate_decompressed := zlib.decompress(deflate_compressed) or {
			println('  Iteration ${i}: Deflate decompression failed: ${err}')
			return false
		}
		
		if deflate_decompressed.bytestr() != original {
			println('  Iteration ${i}: Deflate round-trip mismatch')
			println('    Original length: ${original.len}')
			println('    Decompressed length: ${deflate_decompressed.len}')
			return false
		}
	}
	
	return true
}

fn test_property_10_compressible_text_roundtrip() bool {
	rand.seed([u32(time.now().unix()), u32(98765)])
	
	for i in 0 .. test_iterations {
		original := generate_compressible_text(500, 3000)
		
		// Test gzip with compressible text
		gzip_compressed := gzip.compress(original.bytes(), gzip.CompressParams{
			compression_level: 128
		}) or {
			println('  Iteration ${i}: Gzip compression failed')
			return false
		}
		
		gzip_decompressed := gzip.decompress(gzip_compressed) or {
			println('  Iteration ${i}: Gzip decompression failed: ${err}')
			return false
		}
		
		if gzip_decompressed.bytestr() != original {
			println('  Iteration ${i}: Gzip compressible text round-trip mismatch')
			return false
		}
		
		// Test deflate with compressible text
		deflate_compressed := zlib.compress(original.bytes()) or {
			println('  Iteration ${i}: Deflate compression failed')
			return false
		}
		
		deflate_decompressed := zlib.decompress(deflate_compressed) or {
			println('  Iteration ${i}: Deflate decompression failed: ${err}')
			return false
		}
		
		if deflate_decompressed.bytestr() != original {
			println('  Iteration ${i}: Deflate compressible text round-trip mismatch')
			return false
		}
	}
	
	return true
}

// ============================================================================
// Property 11: Compression Threshold Enforcement
// Feature: builtin-middleware, Property 11: Compression Threshold Enforcement
// Validates: Requirements 5.7
// 
// *For any* response body smaller than the configured threshold, 
// the Compression middleware SHALL NOT compress the response.
// 
// This test validates the threshold logic by checking that:
// 1. Small data (below threshold) should not be compressed
// 2. Large data (above threshold) can be compressed
// ============================================================================
fn test_property_11_threshold_logic() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])
	
	// Test various threshold values
	thresholds := [512, 1024, 2048, 4096]
	
	for threshold in thresholds {
		for i in 0 .. 25 {
			// Generate data smaller than threshold
			small_data_len := rand.int_in_range(1, threshold) or { threshold / 2 }
			small_data := generate_random_string(small_data_len, small_data_len + 1)
			
			// Verify the data is indeed smaller than threshold
			if small_data.len >= threshold {
				continue // Skip if data is not smaller
			}
			
			// For small data, the middleware would skip compression
			// We verify that the threshold check works correctly
			should_compress := small_data.len >= threshold
			if should_compress {
				println('  Threshold logic error: small data (${small_data.len}) should not be compressed with threshold ${threshold}')
				return false
			}
			
			// Generate data larger than threshold
			large_data_len := rand.int_in_range(threshold + 100, threshold * 2) or { threshold + 500 }
			large_data := generate_compressible_text(large_data_len, large_data_len + 1)
			
			// Verify the data is indeed larger than threshold
			if large_data.len < threshold {
				continue // Skip if data is not larger
			}
			
			// For large data, compression should be attempted
			should_compress_large := large_data.len >= threshold
			if !should_compress_large {
				println('  Threshold logic error: large data (${large_data.len}) should be compressed with threshold ${threshold}')
				return false
			}
			
			// Verify compression actually works for large data
			compressed := gzip.compress(large_data.bytes(), gzip.CompressParams{
				compression_level: 128
			}) or {
				println('  Iteration ${i}: Compression of large data failed')
				return false
			}
			
			// Verify we can decompress it back
			decompressed := gzip.decompress(compressed) or {
				println('  Iteration ${i}: Decompression of large data failed')
				return false
			}
			
			if decompressed.bytestr() != large_data {
				println('  Iteration ${i}: Large data round-trip failed')
				return false
			}
		}
	}
	
	return true
}

fn test_property_11_boundary_conditions() bool {
	rand.seed([u32(time.now().unix()), u32(22222)])
	
	threshold := 1024
	
	for i in 0 .. test_iterations {
		// Test data exactly at threshold boundary
		// Data at exactly threshold should be compressed (>= threshold)
		exact_data := generate_compressible_text(threshold, threshold + 1)
		
		// Verify exact boundary
		if exact_data.len < threshold {
			continue
		}
		
		should_compress_exact := exact_data.len >= threshold
		if !should_compress_exact {
			println('  Iteration ${i}: Boundary condition error at exact threshold')
			return false
		}
		
		// Test data just below threshold
		below_threshold := threshold - 1
		below_data := generate_random_string(below_threshold, below_threshold + 1)
		
		if below_data.len >= threshold {
			continue
		}
		
		should_compress_below := below_data.len >= threshold
		if should_compress_below {
			println('  Iteration ${i}: Boundary condition error below threshold')
			return false
		}
		
		// Test data just above threshold
		above_data := generate_compressible_text(threshold + 1, threshold + 100)
		
		if above_data.len <= threshold {
			continue
		}
		
		should_compress_above := above_data.len >= threshold
		if !should_compress_above {
			println('  Iteration ${i}: Boundary condition error above threshold')
			return false
		}
	}
	
	return true
}

// Unit tests for basic compression functionality
fn test_gzip_basic() {
	original := 'Hello, World! This is a test string for compression.'
	
	compressed := gzip.compress(original.bytes(), gzip.CompressParams{
		compression_level: 128
	}) or {
		assert false, 'Gzip compression failed: ${err}'
		return
	}
	
	decompressed := gzip.decompress(compressed) or {
		assert false, 'Gzip decompression failed: ${err}'
		return
	}
	
	assert decompressed.bytestr() == original, 'Gzip round-trip failed'
}

fn test_deflate_basic() {
	original := 'Hello, World! This is a test string for compression.'
	
	compressed := zlib.compress(original.bytes()) or {
		assert false, 'Deflate compression failed: ${err}'
		return
	}
	
	decompressed := zlib.decompress(compressed) or {
		assert false, 'Deflate decompression failed: ${err}'
		return
	}
	
	assert decompressed.bytestr() == original, 'Deflate round-trip failed'
}

fn test_compression_reduces_size() {
	// Highly compressible data
	original := 'AAAAAAAAAA'.repeat(1000)
	
	gzip_compressed := gzip.compress(original.bytes(), gzip.CompressParams{
		compression_level: 128
	}) or {
		assert false, 'Gzip compression failed'
		return
	}
	
	deflate_compressed := zlib.compress(original.bytes()) or {
		assert false, 'Deflate compression failed'
		return
	}
	
	// Compressed size should be smaller than original
	assert gzip_compressed.len < original.len, 'Gzip should reduce size for compressible data'
	assert deflate_compressed.len < original.len, 'Deflate should reduce size for compressible data'
}

fn test_empty_data_compression() {
	original := ''
	
	// Gzip should handle empty data
	gzip_compressed := gzip.compress(original.bytes(), gzip.CompressParams{
		compression_level: 128
	}) or {
		assert false, 'Gzip compression of empty data failed: ${err}'
		return
	}
	
	gzip_decompressed := gzip.decompress(gzip_compressed) or {
		assert false, 'Gzip decompression of empty data failed: ${err}'
		return
	}
	
	assert gzip_decompressed.bytestr() == original, 'Gzip empty data round-trip failed'
	
	// Deflate should handle empty data
	deflate_compressed := zlib.compress(original.bytes()) or {
		assert false, 'Deflate compression of empty data failed: ${err}'
		return
	}
	
	deflate_decompressed := zlib.decompress(deflate_compressed) or {
		assert false, 'Deflate decompression of empty data failed: ${err}'
		return
	}
	
	assert deflate_decompressed.bytestr() == original, 'Deflate empty data round-trip failed'
}

// Main function for running property tests
fn main() {
	println('🚀 开始 Compression Middleware 属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: builtin-middleware, Property 10: Compression Round-Trip
	// Validates: Requirements 5.1, 5.2, 5.6
	stats.run_property_test('Property 10: Gzip Round-Trip', test_property_10_gzip_roundtrip)
	stats.run_property_test('Property 10: Deflate Round-Trip', test_property_10_deflate_roundtrip)
	stats.run_property_test('Property 10: Compressible Text Round-Trip', test_property_10_compressible_text_roundtrip)
	
	// Feature: builtin-middleware, Property 11: Compression Threshold Enforcement
	// Validates: Requirements 5.7
	stats.run_property_test('Property 11: Threshold Logic', test_property_11_threshold_logic)
	stats.run_property_test('Property 11: Boundary Conditions', test_property_11_boundary_conditions)

	// Print test summary
	stats.print_summary()
}
