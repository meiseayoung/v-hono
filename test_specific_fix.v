module main

import hono
import os

fn main() {
	println('Testing specific file fix...')
	
	// Create upload manager
	mut upload_manager := hono.new_chunk_upload_manager(hono.ChunkUploadConfig{})
	
	// Use the exact same parameters from the failing case
	file_hash := 'a45abf58302850765be03cf78bcf5129'
	filename := 'test.zip' // This should give us .zip extension
	total_chunks := 1
	chunk_size := 2097152
	file_size := 93569
	
	// Create test chunk directory and file
	chunk_dir := os.join_path(os.join_path('./uploads/chunks', file_hash), chunk_size.str())
	os.mkdir_all(chunk_dir) or { panic('Failed to create chunk directory') }
	
	// Create a test chunk file
	chunk_path := os.join_path(chunk_dir, 'chunk_0.part')
	test_data := 'This is test chunk data for testing the merge functionality.'
	os.write_file(chunk_path, test_data) or { panic('Failed to create test chunk') }
	
	println('Created test chunk at: $chunk_path')
	
	// Test the file extension function
	file_ext := get_file_extension(filename)
	println('File extension: "$file_ext"')
	
	// Test the merge functionality with the exact same path construction
	final_filename := '${file_hash.trim_space()}${file_ext}'
	final_path := os.join_path('./uploads/files', final_filename)
	println('Attempting to merge to: $final_path')
	
	upload_manager.handle_chunk_merge_internal(file_hash, filename, total_chunks, final_path, chunk_size, file_size, file_ext) or {
		println('Merge failed: $err')
		return
	}
	
	println('Merge successful!')
	println('Final file exists: ${os.exists(final_path)}')
	
	// Clean up
	os.rmdir_all(chunk_dir) or { println('Failed to clean up chunk directory') }
	os.rm(final_path) or { println('Failed to clean up final file') }
	
	println('Test completed successfully!')
}

// 获取文件扩展名
fn get_file_extension(filename string) string {
	println('[DEBUG] Getting extension for filename: "$filename"')
	parts := filename.split('.')
	println('[DEBUG] Split parts: $parts')
	if parts.len > 1 {
		ext := '.${parts.last()}'
		println('[DEBUG] Extracted extension: "$ext"')
		return ext
	}
	println('[DEBUG] No extension found, returning empty string')
	return ''
} 