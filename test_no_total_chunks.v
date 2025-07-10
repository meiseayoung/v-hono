module main

import hono
import os

fn main() {
	println('Testing upload without total_chunks parameter...')
	
	// Create upload manager
	mut upload_manager := hono.new_chunk_upload_manager(hono.ChunkUploadConfig{})
	
	// Test file info
	file_hash := 'test123456789'
	filename := 'test_file.zip'
	chunk_index := 0
	chunk_size := 2097152
	file_size := 93569
	
	// Create test chunk directory and file
	chunk_dir := os.join_path(os.join_path('./uploads/chunks', file_hash), chunk_size.str())
	os.mkdir_all(chunk_dir) or { panic('Failed to create chunk directory') }
	
	// Create a test chunk file
	chunk_path := os.join_path(chunk_dir, 'chunk_${chunk_index}.part')
	test_data := 'This is test chunk data for testing the merge functionality.'
	os.write_file(chunk_path, test_data) or { panic('Failed to create test chunk') }
	
	println('Created test chunk at: $chunk_path')
	
	// Test the update_upload_status function
	upload_manager.update_upload_status(file_hash, filename, chunk_index, file_size, chunk_size)
	println('Updated upload status')
	
	// Check if the upload status was created correctly
	if file_hash in upload_manager.uploads {
		status := upload_manager.uploads[file_hash]
		println('Upload status:')
		println('  File hash: ${status.file_hash}')
		println('  Filename: ${status.filename}')
		println('  Total chunks: ${status.total_chunks}')
		println('  Uploaded chunks: ${status.uploaded_chunks}')
		println('  File size: ${status.file_size}')
		println('  Chunk size: ${status.chunk_size}')
		println('  Status: ${status.status}')
	} else {
		println('Upload status not found!')
		return
	}
	
	// Test the merge logic
	file_ext := get_file_extension(filename)
	final_filename := '${file_hash.trim_space()}${file_ext}'
	final_path := os.join_path('./uploads/files', final_filename)
	
	println('Testing merge logic...')
	println('Final path: $final_path')
	
	// Calculate actual total chunks
	mut actual_total_chunks := 0
	for i := 0; ; i++ {
		check_chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')
		if !os.exists(check_chunk_path) {
			break
		}
		actual_total_chunks++
	}
	
	println('Actual total chunks: $actual_total_chunks')
	
	// Test merge
	upload_manager.handle_chunk_merge_internal(file_hash, filename, actual_total_chunks, final_path, chunk_size, file_size, file_ext) or {
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
	parts := filename.split('.')
	if parts.len > 1 {
		return '.${parts.last()}'
	}
	return ''
} 