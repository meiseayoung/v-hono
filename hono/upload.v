module hono

import net.http
import os
import crypto.md5
import json
import time

// 分片上传配置
pub struct ChunkUploadConfig {
pub:
	chunk_size     int = 1024 * 1024  // 1MB 默认分片大小
	max_file_size  int = 1024 * 1024 * 1024  // 1GB 最大文件大小
	temp_dir       string = './uploads/chunks'  // 临时分片目录（分片保存在 temp_dir/filehash/chunksize/ 下）
	upload_dir     string = './uploads/files'  // 最终文件目录
	cleanup_delay  int = 3600  // 1小时后清理临时文件
	clear_chunks_on_complete bool // 上传完成后是否清空分片，默认不清空
	db_path        string = './uploads/files.db'  // 数据库文件路径
}

// 分片信息
pub struct ChunkInfo {
pub:
	file_hash    string
	chunk_index  int
	total_chunks int
	filename     string
	file_size    int
	chunk_size   int
	upload_time  int
}

// 文件上传状态
pub struct FileUploadStatus {
pub:
	file_hash    string
	filename     string
	total_chunks int
	file_size    int
	chunk_size   int
	created_at   int
pub mut:
	uploaded_chunks []int
	status       string
	updated_at   int
}

// 分片上传管理器
pub struct ChunkUploadManager {
pub mut:
	config ChunkUploadConfig
	uploads map[string]FileUploadStatus
	db      DatabaseManager
}

// 创建分片上传管理器
pub fn new_chunk_upload_manager(config ChunkUploadConfig) ChunkUploadManager {
	// 确保目录存在
	os.mkdir_all(config.temp_dir) or { panic('Failed to create temp directory') }
	os.mkdir_all(config.upload_dir) or { panic('Failed to create upload directory') }
	
	// 创建数据库管理器
	db := new_database_manager(config.db_path) or { panic('Failed to create database manager: $err') }
	
	return ChunkUploadManager{
		config: config
		uploads: map[string]FileUploadStatus{}
		db: db
	}
}

// 处理分片上传
pub fn (mut manager ChunkUploadManager) handle_chunk_upload(mut ctx Context) http.Response {
	// 解析 multipart 表单数据
	form_data := hono.parse_multipart_form(ctx.req) or {
		ctx.status(400)
		return ctx.json('{"error": "Invalid form data", "message": "$err"}')
	}
	
	// 获取必要参数
	file_hash := form_data.get('file_hash') or {
		ctx.status(400)
		return ctx.json('{"error": "Missing file_hash"}')
	}
	
	chunk_index_str := form_data.get('chunk_index') or {
		ctx.status(400)
		return ctx.json('{"error": "Missing chunk_index"}')
	}
	
	filename := form_data.get('filename') or {
		ctx.status(400)
		return ctx.json('{"error": "Missing filename"}')
	}
	
	file_size_str := form_data.get('file_size') or {
		ctx.status(400)
		return ctx.json('{"error": "Missing file_size"}')
	}
	
	// 解析数值
	chunk_index := chunk_index_str.int()
	file_size := file_size_str.int()
	
	// 验证文件大小
	if file_size > manager.config.max_file_size {
		ctx.status(413)
		return ctx.json('{"error": "File too large", "max_size": "${manager.config.max_file_size}"}')
	}
	
	// 获取前端传递的分片大小参数
	chunk_size_str := form_data.get('chunk_size') or {
		ctx.status(400)
		return ctx.json('{"error": "Missing chunk_size"}')
	}
	chunk_size := chunk_size_str.int()
	
	// 验证分片大小（允许更大的分片大小，但不超过10MB）
	max_allowed_chunk_size := 10 * 1024 * 1024 // 10MB
	if chunk_size > max_allowed_chunk_size {
		ctx.status(413)
		return ctx.json('{"error": "Chunk size too large", "max_chunk_size": "$max_allowed_chunk_size"}')
	}
	
	// 获取文件数据
	file_data := form_data.get_file('chunk') or {
		ctx.status(400)
		return ctx.json('{"error": "Missing chunk file"}')
	}
	
	// 创建按文件hash和分片大小分组的目录
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	os.mkdir_all(chunk_dir) or {
		ctx.status(500)
		return ctx.json('{"error": "Failed to create chunk directory"}')
	}
	
	// 保存分片文件到hash/chunksize子目录
	chunk_path := os.join_path(chunk_dir, 'chunk_${chunk_index}.part')
	println('[DEBUG] Saving chunk to: $chunk_path')
	println('[DEBUG] Chunk dir exists: ${os.exists(chunk_dir)}')
	println('[DEBUG] Chunk data size: ${file_data.len} bytes')
	
	os.write_file(chunk_path, file_data) or {
		println('[DEBUG] Failed to save chunk: $err')
		ctx.status(500)
		return ctx.json('{"error": "Failed to save chunk"}')
	}
	
	// 更新上传状态
	manager.update_upload_status(file_hash, filename, chunk_index, file_size, chunk_size)
	
	println('[DEBUG] Updated upload status for file: $file_hash, chunk: $chunk_index')
	
	// 判断是否所有分片都已上传，自动合并
	// 基于分片大小总和来判断是否合并
	mut all_chunk_uploaded := false
	merge_chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	
	if os.exists(merge_chunk_dir) {
		mut total_chunk_size := u64(0)
		mut chunk_count := 0
		mut max_chunk_index := -1
		
		// 遍历所有分片文件，计算总大小和找到最大分片索引
		for i := 0; ; i++ {
			merge_chunk_path := os.join_path(merge_chunk_dir, 'chunk_${i}.part')
			if !os.exists(merge_chunk_path) {
				break
			}
			chunk_info := os.stat(merge_chunk_path) or { continue }
			total_chunk_size += chunk_info.size
			chunk_count++
			max_chunk_index = i
		}
		
		println('[DEBUG] [MergeCheck] total_chunk_size=$total_chunk_size, file_size=$file_size, chunk_count=$chunk_count, max_chunk_index=$max_chunk_index')
		
		// 如果分片文件大小总和 >= file_size，认为可以合并
		if total_chunk_size >= u64(file_size) {
			all_chunk_uploaded = true
			println('[DEBUG] All chunks uploaded based on size comparison')
		}
	}
	
	println('[DEBUG] All chunks uploaded: $all_chunk_uploaded')
	
	if all_chunk_uploaded {
		// 重新计算分片数量用于合并
		mut actual_total_chunks := 0
		for i := 0; ; i++ {
			check_chunk_path := os.join_path(merge_chunk_dir, 'chunk_${i}.part')
			if !os.exists(check_chunk_path) {
				break
			}
			actual_total_chunks++
		}
		
		// 获取文件扩展名
		file_ext := get_file_extension(filename)
		final_filename := '${file_hash.trim_space()}${file_ext}'
		final_path := os.join_path(manager.config.upload_dir, final_filename)
		
		// 检查最终文件是否已经存在，避免重复合并
		if os.exists(final_path) {
			println('[DEBUG] Final file already exists: $final_path, skipping merge')
		} else {
			println('[DEBUG] Merging chunks to: $final_path')
			println('[DEBUG] Upload dir exists: ${os.exists(manager.config.upload_dir)}')
			println('[DEBUG] Actual total chunks: $actual_total_chunks')
			
			manager.merge_chunks(file_hash, actual_total_chunks, final_path, chunk_size) or {
				println('[DEBUG] Merge failed: $err')
				ctx.status(500)
				return ctx.json('{"error": "Failed to merge chunks", "message": "$err"}')
			}
		}
		
		// 在数据库中记录文件信息
		file_info := manager.db.insert_or_update_file(file_hash, filename, file_size, file_ext) or {
			println('[DEBUG] Failed to save file info to database: $err')
			// 即使数据库保存失败，也不影响文件合并
			FileInfo{}
		}
		
		manager.uploads[file_hash].status = 'completed'
		manager.uploads[file_hash].updated_at = int(time.now().unix())
		
		if manager.config.clear_chunks_on_complete {
			manager.cleanup_chunks(file_hash, chunk_size)
		}
		
		clean_file_path := final_path.replace('\n', '').replace('\r', '').replace('\\', '\\\\').trim_space()
		return ctx.json('{"success": true, "all_chunk_uploaded": true, "file_path": "$clean_file_path", "file_uuid": "${file_info.file_uuid}", "message": "File merged successfully"}')
	}
	// 未全部上传，正常返回
	return ctx.json('{"success": true, "chunk_index": $chunk_index, "all_chunk_uploaded": false, "message": "Chunk uploaded successfully"}')
}

// 处理分片合并
pub fn (mut manager ChunkUploadManager) handle_chunk_merge(mut ctx Context) http.Response {
	// 解析请求体
	merge_request := hono.parse_merge_request(ctx.body) or {
		ctx.status(400)
		return ctx.json('{"error": "Invalid request body", "message": "$err"}')
	}
	
	file_hash := merge_request.file_hash
	filename := merge_request.filename
	total_chunks := merge_request.total_chunks
	
	// 检查上传状态
	upload_status := manager.uploads[file_hash] or {
		ctx.status(404)
		return ctx.json('{"error": "Upload not found"}')
	}
	
	// 验证所有分片是否上传完成
	if upload_status.uploaded_chunks.len != total_chunks {
		ctx.status(400)
		return ctx.json('{"error": "Not all chunks uploaded", "uploaded": ${upload_status.uploaded_chunks.len}, "total": $total_chunks}')
	}
	
	// 合并文件
	file_ext := get_file_extension(filename)
	final_filename := '${file_hash.trim_space()}${file_ext}'
	final_path := os.join_path(manager.config.upload_dir, final_filename)
	
	// 从上传状态中获取分片大小
	chunk_size := upload_status.chunk_size
	manager.merge_chunks(file_hash, total_chunks, final_path, chunk_size) or {
		ctx.status(500)
		return ctx.json('{"error": "Failed to merge chunks", "message": "$err"}')
	}
	
	// 在数据库中记录文件信息
	file_info := manager.db.insert_or_update_file(file_hash, filename, upload_status.file_size, file_ext) or {
		println('[DEBUG] Failed to save file info to database: $err')
		// 即使数据库保存失败，也不影响文件合并
		FileInfo{}
	}
	
	// 更新状态为完成
	manager.uploads[file_hash].status = 'completed'
	manager.uploads[file_hash].updated_at = int(time.now().unix())
	
	// 清理临时分片
	manager.cleanup_chunks(file_hash, chunk_size)
	
	// 返回成功响应
	clean_file_path2 := final_path.replace('\n', '').replace('\r', '').replace('\\', '\\\\').trim_space()
	return ctx.json('{"success": true, "file_path": "$clean_file_path2", "file_uuid": "${file_info.file_uuid}", "message": "File merged successfully"}')
}

// 获取上传状态
pub fn (manager ChunkUploadManager) get_upload_status(mut ctx Context) http.Response {
	file_hash := ctx.query['file_hash'] or {
		ctx.status(400)
		return ctx.json('{"error": "Missing file_hash parameter"}')
	}
	
	upload_status := manager.uploads[file_hash] or {
		ctx.status(404)
		return ctx.json('{"error": "Upload not found"}')
	}
	
	return ctx.json(json.encode(upload_status))
}

// 更新上传状态
pub fn (mut manager ChunkUploadManager) update_upload_status(file_hash string, filename string, chunk_index int, file_size int, chunk_size int) {
	now := int(time.now().unix())
	
	if file_hash !in manager.uploads {
		manager.uploads[file_hash] = FileUploadStatus{
			file_hash: file_hash
			filename: filename
			total_chunks: 0 // 不再使用固定的total_chunks，改为动态计算
			uploaded_chunks: []
			file_size: file_size
			chunk_size: chunk_size
			status: 'uploading'
			created_at: now
			updated_at: now
		}
	}
	
	// 添加已上传的分片索引
	if chunk_index !in manager.uploads[file_hash].uploaded_chunks {
		manager.uploads[file_hash].uploaded_chunks << chunk_index
	}
	
	manager.uploads[file_hash].updated_at = now
}

// 合并分片
fn (mut manager ChunkUploadManager) merge_chunks(file_hash string, total_chunks int, final_path string, chunk_size int) ! {
	println('[DEBUG] Merge chunks called with:')
	println('[DEBUG]   file_hash: $file_hash')
	println('[DEBUG]   total_chunks: $total_chunks')
	println('[DEBUG]   final_path: $final_path')
	println('[DEBUG]   chunk_size: $chunk_size')
	println('[DEBUG]   upload_dir: ${manager.config.upload_dir}')
	
	// 确保上传目录存在
	os.mkdir_all(manager.config.upload_dir) or {
		return error('Failed to create upload directory: $err')
	}
	
	// 检查目录权限
	if !os.is_writable(manager.config.upload_dir) {
		return error('Upload directory is not writable: ${manager.config.upload_dir}')
	}
	
	println('[DEBUG] Creating final file: $final_path')
	println('[DEBUG] Final path length: ${final_path.len}')
	println('[DEBUG] Final path bytes: ${final_path.bytes()}')
	println('[DEBUG] Final path exists: ${os.exists(final_path)}')
	println('[DEBUG] Final path is file: ${os.is_file(final_path)}')
	println('[DEBUG] Final path is dir: ${os.is_dir(final_path)}')
	
	// 如果文件已存在，直接返回成功
	if os.exists(final_path) {
		println('[DEBUG] Final file already exists, skipping creation')
		return
	}
	
	// Try to create the file with explicit path cleaning
	clean_path := final_path.trim_space()
	println('[DEBUG] Clean path: "$clean_path"')
	println('[DEBUG] Clean path length: ${clean_path.len}')
	
	// Try to get absolute path
	abs_path := os.abs_path(clean_path)
	println('[DEBUG] Absolute path: "$abs_path"')
	
	mut final_file := os.create(abs_path) or {
		println('[DEBUG] File creation failed with error: $err')
		return error('Failed to create final file: $err')
	}
	defer { final_file.close() }
	
	for i in 0 .. total_chunks {
		chunk_path := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str(), 'chunk_${i}.part')
		println('[DEBUG] Reading chunk: $chunk_path')
		
		if !os.exists(chunk_path) {
			return error('Chunk file not found: $chunk_path')
		}
		
		chunk_data := os.read_file(chunk_path) or {
			return error('Failed to read chunk $i: $err')
		}
		
		final_file.write(chunk_data.bytes()) or {
			return error('Failed to write chunk $i: $err')
		}
		
		println('[DEBUG] Chunk $i merged successfully, size: ${chunk_data.len} bytes')
	}
	
	println('[DEBUG] All chunks merged successfully to: $final_path')
}

// 清理临时分片
fn (mut manager ChunkUploadManager) cleanup_chunks(file_hash string, chunk_size int) {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	if os.exists(chunk_dir) {
		// 删除整个分片目录
		os.rmdir_all(chunk_dir) or { 
			println('[DEBUG] Failed to remove chunk directory: $err')
		}
	}
}

// 公共清理方法
pub fn (mut manager ChunkUploadManager) cleanup_chunks_public(file_hash string, chunk_size int) {
	manager.cleanup_chunks(file_hash, chunk_size)
}

// 内部合并处理方法
pub fn (mut manager ChunkUploadManager) handle_chunk_merge_internal(file_hash string, filename string, total_chunks int, final_path string, chunk_size int, file_size int, file_ext string) ! {
	// 执行合并
	manager.merge_chunks(file_hash, total_chunks, final_path, chunk_size) or {
		return error('Failed to merge chunks: $err')
	}
	
	// 在数据库中记录文件信息
	manager.db.insert_or_update_file(file_hash, filename, file_size, file_ext) or {
		println('[DEBUG] Failed to save file info to database: $err')
		// 即使数据库保存失败，也不影响文件合并
	}
}

// 生成文件哈希
pub fn generate_file_hash(data string) string {
	return md5.sum(data.bytes()).hex()
}

// 验证文件完整性
pub fn verify_file_integrity(file_path string, expected_hash string) bool {
	file_data := os.read_file(file_path) or { return false }
	actual_hash := generate_file_hash(file_data)
	return actual_hash == expected_hash
}

// 获取文件扩展名
fn get_file_extension(filename string) string {
	parts := filename.split('.')
	if parts.len > 1 {
		return '.${parts.last()}'
	}
	return ''
}

// 清理文件上传状态（当文件被删除时调用）
pub fn (mut manager ChunkUploadManager) cleanup_upload_status(file_hash string) {
	if file_hash in manager.uploads {
		manager.uploads.delete(file_hash)
	}
}

// 检查并清理无效的上传状态
pub fn (mut manager ChunkUploadManager) cleanup_invalid_status() {
	mut to_delete := []string{}
	
	for file_hash, upload_status in manager.uploads {
		// 检查最终文件是否存在
		final_path := os.join_path(manager.config.upload_dir, upload_status.filename.trim_space())
		if !os.exists(final_path) {
			// 如果最终文件不存在，检查分片文件是否都存在
			mut all_chunks_exist := true
			chunk_size := upload_status.chunk_size
			chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
			
			// 动态检查分片文件
			for i := 0; ; i++ {
				chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')
				if !os.exists(chunk_path) {
					break
				}
				// 如果找到至少一个分片，说明上传正在进行中
				all_chunks_exist = false
				break
			}
			
			// 如果没有找到任何分片文件，清理状态
			if all_chunks_exist {
				to_delete << file_hash
			}
		}
	}
	
	// 删除无效状态
	for file_hash in to_delete {
		manager.uploads.delete(file_hash)
	}
} 