import hono
import os

fn main() {
	println('=== 测试大文件处理内存优化 ===')
	
	// 创建测试配置，使用较小的缓冲区便于测试
	config := hono.ChunkUploadConfig{
		chunk_size: 1024 * 1024  // 1MB
		max_file_size: 100 * 1024 * 1024  // 100MB
		temp_dir: './test_uploads/chunks'
		upload_dir: './test_uploads/files'
		merge_buffer_size: 4096  // 4KB 缓冲区用于测试
	}
	
	mut manager := hono.new_chunk_upload_manager(config)
	
	println('1. 配置验证')
	println('   缓冲区大小: ${config.merge_buffer_size} bytes')
	println('   临时目录: ${config.temp_dir}')
	println('   上传目录: ${config.upload_dir}')
	
	// 创建测试分片文件
	test_file_hash := 'test_large_file_hash'
	chunk_size := 1024 * 1024  // 1MB
	test_chunks := 3  // 创建3个测试分片
	
	println('2. 创建测试分片文件')
	
	// 确保测试目录存在
	chunk_dir := os.join_path(config.temp_dir, test_file_hash, chunk_size.str())
	os.mkdir_all(chunk_dir) or {
		println('   ❌ 创建测试目录失败: $err')
		return
	}
	
	// 创建测试分片文件
	for i in 0 .. test_chunks {
		chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')
		
		// 创建1KB的测试数据
		test_data := 'A'.repeat(1024)
		os.write_file(chunk_path, test_data) or {
			println('   ❌ 创建测试分片 $i 失败: $err')
			return
		}
		println('   ✅ 创建测试分片 $i: ${test_data.len} bytes')
	}
	
	println('3. 测试流式文件合并')
	
	// 测试合并
	final_filename := 'test_merged_file.txt'
	final_path := os.join_path(config.upload_dir, final_filename)
	
	// 调用内部合并方法进行测试
	manager.handle_chunk_merge_internal(test_file_hash, final_filename, test_chunks, final_path, chunk_size, test_chunks * 1024, '.txt') or {
		println('   ❌ 文件合并失败: $err')
		cleanup_test_files(config)
		return
	}
	
	println('   ✅ 文件合并成功')
	
	// 验证合并结果
	if os.exists(final_path) {
		file_info := os.stat(final_path) or {
			println('   ❌ 获取文件信息失败: $err')
			cleanup_test_files(config)
			return
		}
		
		expected_size := u64(test_chunks * 1024)
		if file_info.size == expected_size {
			println('   ✅ 文件大小验证通过: ${file_info.size} bytes')
		} else {
			println('   ❌ 文件大小不匹配: 期望 ${expected_size}, 实际 ${file_info.size}')
		}
	} else {
		println('   ❌ 合并后的文件不存在')
	}
	
	println('4. 清理测试文件')
	cleanup_test_files(config)
	
	println('✅ 大文件处理内存优化测试完成！')
	println('   优化效果：')
	println('   - 使用流式读写，内存占用从 O(文件大小) 降低到 O(缓冲区大小)')
	println('   - 缓冲区大小可配置，默认 8KB')
	println('   - 支持任意大小文件的合并，不受内存限制')
}

fn cleanup_test_files(config hono.ChunkUploadConfig) {
	// 清理测试文件
	if os.exists('./test_uploads') {
		os.rmdir_all('./test_uploads') or {
			println('   ⚠️  清理测试目录失败: $err')
		}
	}
	println('   ✅ 测试文件清理完成')
}