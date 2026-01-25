module hono

import net.http
import os
import crypto.md5
import x.json2
import time

// 分片上传配置
pub struct ChunkUploadConfig {
pub:
	chunk_size     int = 1024 * 1024  // 1MB 默认分片大小
	max_file_size  int = 1024 * 1024 * 1024  // 1GB 最大文件大小
	max_chunk_size int = 10 * 1024 * 1024  // 10MB 最大分片大小
	temp_dir       string = './uploads/chunks'  // 临时分片目录（分片保存在 temp_dir/filehash/chunksize/ 下）
	upload_dir     string = './uploads/files'  // 最终文件目录
	cleanup_delay  int = 3600  // 1小时后清理临时文件
	clear_chunks_on_complete bool // 上传完成后是否清空分片，默认不清空
	db_path        string = './uploads/files.db'  // 数据库文件路径
	merge_buffer_size int = 8192  // 文件合并时的缓冲区大小（8KB）
	// 新增：存储配置（可选，用于集成 FileService）
	use_file_service bool // 是否使用 FileService 进行存储
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
	config       ChunkUploadConfig
	uploads      map[string]FileUploadStatus
	db           DatabaseManager
	file_service &FileService = unsafe { nil } // 可选的 FileService，用于云存储集成
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
		file_service: unsafe { nil }
	}
}

// 创建分片上传管理器（使用现有的 FileService）
// 当提供 FileService 时，合并后的文件将通过 FileService 存储到配置的存储后端
pub fn new_chunk_upload_manager_with_storage(config ChunkUploadConfig, mut file_service FileService) ChunkUploadManager {
	// 确保临时目录存在
	os.mkdir_all(config.temp_dir) or { panic('Failed to create temp directory') }
	
	// 如果不使用 FileService，也需要创建上传目录
	if !config.use_file_service {
		os.mkdir_all(config.upload_dir) or { panic('Failed to create upload directory') }
	}
	
	// 创建数据库管理器
	db := new_database_manager(config.db_path) or { panic('Failed to create database manager: $err') }
	
	return ChunkUploadManager{
		config: config
		uploads: map[string]FileUploadStatus{}
		db: db
		file_service: file_service
	}
}

// 创建分片上传管理器（自动创建本地 FileService）
pub fn new_chunk_upload_manager_with_local_storage(config ChunkUploadConfig, storage_path string, db_path string) !ChunkUploadManager {
	// 确保临时目录存在
	os.mkdir_all(config.temp_dir) or {
		return error('Failed to create temp directory: ${err}')
	}
	
	// 创建本地 FileService
	mut file_service := new_local_file_service(storage_path, db_path)!
	
	// 创建数据库管理器
	db := new_database_manager(config.db_path) or {
		return error('Failed to create database manager: ${err}')
	}
	
	return ChunkUploadManager{
		config: config
		uploads: map[string]FileUploadStatus{}
		db: db
		file_service: &file_service
	}
}

// 处理分片上传
pub fn (mut manager ChunkUploadManager) handle_chunk_upload(mut ctx Context) http.Response {
	// 解析 multipart 表单数据
	form_data := hono.parse_multipart_form(ctx.req) or {
		return ctx.bad_request('Invalid form data: ${err}')
	}
	
	// 获取并验证必要参数
	file_hash_raw := form_data.get('file_hash') or {
		return ctx.missing_parameter('file_hash')
	}
	
	// 验证文件哈希
	file_hash := validate_file_hash(file_hash_raw) or {
		return ctx.invalid_parameter('file_hash', err.msg())
	}
	
	chunk_index_str := form_data.get('chunk_index') or {
		return ctx.missing_parameter('chunk_index')
	}
	
	filename_raw := form_data.get('filename') or {
		return ctx.missing_parameter('filename')
	}
	
	// 验证文件名
	filename := validate_filename(filename_raw) or {
		return ctx.invalid_parameter('filename', err.msg())
	}
	
	file_size_str := form_data.get('file_size') or {
		return ctx.missing_parameter('file_size')
	}
	
	// 验证文件大小
	file_size := validate_file_size(file_size_str, manager.config.max_file_size) or {
		return ctx.invalid_parameter('file_size', err.msg())
	}
	
	// 获取前端传递的分片大小参数
	chunk_size_str := form_data.get('chunk_size') or {
		return ctx.missing_parameter('chunk_size')
	}
	
	// 验证分片大小
	chunk_size := validate_file_size(chunk_size_str, manager.config.max_chunk_size) or {
		return ctx.invalid_parameter('chunk_size', err.msg())
	}
	
	// 验证分片索引
	chunk_index := validate_chunk_index(chunk_index_str, 0) or { // 0 表示不限制最大值
		return ctx.invalid_parameter('chunk_index', err.msg())
	}
	
	// 获取文件数据
	file_data := form_data.get_file('chunk') or {
		return ctx.missing_parameter('chunk')
	}
	
	// 验证分片数据大小
	if file_data.len > chunk_size {
		return ctx.validation_error('Chunk data size exceeds declared chunk_size', {
			'actual_size': file_data.len.str()
			'declared_size': chunk_size.str()
		})
	}
	
	// 创建按文件hash和分片大小分组的目录
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash, chunk_size.str())
	os.mkdir_all(chunk_dir) or {
		return ctx.file_operation_error('create_directory', chunk_dir, err.msg())
	}
	
	// 保存分片文件到hash/chunksize子目录
	chunk_path := os.join_path(chunk_dir, 'chunk_${chunk_index}.part')
	println('[DEBUG] Saving chunk to: $chunk_path')
	println('[DEBUG] Chunk dir exists: ${os.exists(chunk_dir)}')
	println('[DEBUG] Chunk data size: ${file_data.len} bytes')
	
	os.write_file(chunk_path, file_data) or {
		println('[DEBUG] Failed to save chunk: $err')
		return ctx.file_operation_error('save_chunk', chunk_path, err.msg())
	}
	
	// 更新上传状态
	manager.update_upload_status(file_hash, filename, chunk_index, file_size, chunk_size)
	
	println('[DEBUG] Updated upload status for file: $file_hash, chunk: $chunk_index')
	
	// 判断是否所有分片都已上传，自动合并
	// 使用记录文件来避免遍历分片文件计算总大小
	mut all_chunk_uploaded := false
	merge_chunk_dir := os.join_path(manager.config.temp_dir, file_hash, chunk_size.str())
	
	if os.exists(merge_chunk_dir) {
		// 更新已上传分片的总大小记录
		manager.update_chunk_size_record(file_hash, chunk_size, file_data.len)
		
		// 读取已上传分片的总大小
		total_chunk_size := manager.get_chunk_size_record(file_hash, chunk_size)
		
		println('[DEBUG] [MergeCheck] total_chunk_size=$total_chunk_size, file_size=$file_size, chunk_index=$chunk_index')
		
		// 如果分片文件大小总和 >= file_size，认为可以合并
		if total_chunk_size >= u64(file_size) {
			all_chunk_uploaded = true
			println('[DEBUG] All chunks uploaded based on size comparison')
		}
	}
	
	println('[DEBUG] All chunks uploaded: $all_chunk_uploaded')
	
	if all_chunk_uploaded {
		// 使用内存中的上传状态来获取分片数量，避免遍历文件
		actual_total_chunks := manager.uploads[file_hash].uploaded_chunks.len
		
		// 获取文件扩展名
		file_ext := get_file_extension(filename)
		final_filename := '${file_hash}${file_ext}'
		
		// 检查是否使用 FileService 进行存储
		if manager.file_service != unsafe { nil } && manager.config.use_file_service {
			// 使用 FileService 存储
			result := manager.merge_and_store_to_file_service(file_hash, filename, file_size, chunk_size) or {
				println('[DEBUG] Merge and store to FileService failed: $err')
				return ctx.file_operation_error('merge_and_store', file_hash, err.msg())
			}
			
			manager.uploads[file_hash].status = 'completed'
			manager.uploads[file_hash].updated_at = int(time.now().unix())
			
			if manager.config.clear_chunks_on_complete {
				manager.cleanup_chunks(file_hash, chunk_size)
			}
			
			return ctx.json('{"success": true, "all_chunk_uploaded": true, "file_uuid": "${result.file_uuid}", "storage_type": "${result.storage_type}", "message": "File uploaded successfully"}')
		}
		
		// 使用本地文件系统存储（原有逻辑）
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
				return ctx.file_operation_error('merge_chunks', final_path, err.msg())
			}
		}
		
		// 在数据库中记录文件信息
		file_info := manager.db.insert_or_update_file_simple(file_hash, filename, i64(file_size), file_ext) or {
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

// 合并请求结构
pub struct MergeRequest {
pub:
	file_hash    string @[json: 'file_hash']
	filename     string
	total_chunks int    @[json: 'total_chunks']
}

// 处理分片合并
pub fn (mut manager ChunkUploadManager) handle_chunk_merge(mut ctx Context) http.Response {
	// 使用 x.json2 解析请求体
	merge_request := json2.decode[MergeRequest](ctx.body) or {
		return ctx.bad_request('Invalid request body: ${err}')
	}
	
	file_hash := merge_request.file_hash
	filename := merge_request.filename
	total_chunks := merge_request.total_chunks
	
	// 检查上传状态
	upload_status := manager.uploads[file_hash] or {
		return ctx.resource_not_found('upload', file_hash)
	}
	
	// 验证所有分片是否上传完成
	if upload_status.uploaded_chunks.len != total_chunks {
		return ctx.validation_error('Not all chunks uploaded', {
			'uploaded': upload_status.uploaded_chunks.len.str()
			'total': total_chunks.str()
		})
	}
	
	// 从上传状态中获取分片大小
	chunk_size := upload_status.chunk_size
	
	// 检查是否使用 FileService 进行存储
	if manager.file_service != unsafe { nil } && manager.config.use_file_service {
		// 使用 FileService 存储
		result := manager.merge_and_store_to_file_service(file_hash, filename, upload_status.file_size, chunk_size) or {
			return ctx.file_operation_error('merge_and_store', file_hash, err.msg())
		}
		
		// 更新状态为完成
		manager.uploads[file_hash].status = 'completed'
		manager.uploads[file_hash].updated_at = int(time.now().unix())
		
		// 清理临时分片
		manager.cleanup_chunks(file_hash, chunk_size)
		
		return ctx.json('{"success": true, "file_uuid": "${result.file_uuid}", "storage_type": "${result.storage_type}", "message": "File merged successfully"}')
	}
	
	// 使用本地文件系统存储（原有逻辑）
	file_ext := get_file_extension(filename)
	final_filename := '${file_hash.trim_space()}${file_ext}'
	final_path := os.join_path(manager.config.upload_dir, final_filename)
	
	manager.merge_chunks(file_hash, total_chunks, final_path, chunk_size) or {
		return ctx.file_operation_error('merge_chunks', final_path, err.msg())
	}
	
	// 在数据库中记录文件信息
	file_info := manager.db.insert_or_update_file_simple(file_hash, filename, i64(upload_status.file_size), file_ext) or {
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
		return ctx.missing_parameter('file_hash')
	}
	
	upload_status := manager.uploads[file_hash] or {
		return ctx.resource_not_found('upload', file_hash)
	}
	
	return ctx.json(json2.encode[FileUploadStatus](upload_status))
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

// 合并分片 - 流式版本，减少内存占用
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
	
	// 如果文件已存在，直接返回成功
	if os.exists(final_path) {
		println('[DEBUG] Final file already exists, skipping creation')
		return
	}
	
	// 清理路径并创建最终文件
	clean_path := final_path.trim_space()
	abs_path := os.abs_path(clean_path)
	println('[DEBUG] Absolute path: "$abs_path"')
	
	mut final_file := os.create(abs_path) or {
		println('[DEBUG] File creation failed with error: $err')
		return error('Failed to create final file: $err')
	}
	defer { final_file.close() }
	
	// 流式合并分片，使用可配置的缓冲区大小
	buffer_size := manager.config.merge_buffer_size
	mut buffer := []u8{len: buffer_size}
	
	for i in 0 .. total_chunks {
		chunk_path := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str(), 'chunk_${i}.part')
		println('[DEBUG] Processing chunk: $chunk_path')
		
		if !os.exists(chunk_path) {
			return error('Chunk file not found: $chunk_path')
		}
		
		// 流式读取和写入分片文件
		mut chunk_file := os.open(chunk_path) or {
			return error('Failed to open chunk $i: $err')
		}
		
		mut bytes_copied := 0
		for {
			bytes_read := chunk_file.read(mut buffer) or { break }
			if bytes_read == 0 { break }
			
			final_file.write(buffer[..bytes_read]) or {
				chunk_file.close()
				return error('Failed to write chunk $i data: $err')
			}
			
			bytes_copied += bytes_read
		}
		
		chunk_file.close()
		println('[DEBUG] Chunk $i merged successfully, size: ${bytes_copied} bytes')
	}
	
	println('[DEBUG] All chunks merged successfully to: $final_path')
}

// 合并分片并存储到 FileService
// 当配置了 FileService 时，将合并后的文件通过 FileService 存储到配置的存储后端
fn (mut manager ChunkUploadManager) merge_and_store_to_file_service(file_hash string, filename string, file_size int, chunk_size int) !UploadResult {
	upload_status := manager.uploads[file_hash] or {
		return error('Upload status not found')
	}
	
	total_chunks := upload_status.uploaded_chunks.len
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash, chunk_size.str())
	
	// 流式合并分片到内存
	mut final_data := []u8{}
	buffer_size := manager.config.merge_buffer_size
	mut buffer := []u8{len: buffer_size}
	
	for i in 0 .. total_chunks {
		chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')
		
		if !os.exists(chunk_path) {
			return error('Chunk file not found: ${chunk_path}')
		}
		
		mut chunk_file := os.open(chunk_path) or {
			return error('Failed to open chunk ${i}: ${err}')
		}
		
		for {
			bytes_read := chunk_file.read(mut buffer) or { break }
			if bytes_read == 0 { break }
			final_data << buffer[..bytes_read]
		}
		
		chunk_file.close()
	}
	
	// 获取 content_type
	content_type := infer_content_type(filename)
	
	// 使用 FileService 上传文件
	result := manager.file_service.upload_file(UploadParams{
		filename: filename
		content_type: content_type
		metadata: '{"original_hash": "${file_hash}", "chunk_count": ${total_chunks}}'
	}, final_data)!
	
	return result
}

// 清理临时分片
fn (mut manager ChunkUploadManager) cleanup_chunks(file_hash string, chunk_size int) {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	if os.exists(chunk_dir) {
		// 清理分片大小记录
		manager.cleanup_chunk_size_record(file_hash, chunk_size)
		
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
	manager.db.insert_or_update_file_simple(file_hash, filename, i64(file_size), file_ext) or {
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

// 更新分片大小记录
pub fn (mut manager ChunkUploadManager) update_chunk_size_record(file_hash string, chunk_size int, current_chunk_size int) {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	size_record_path := os.join_path(chunk_dir, 'total_size.record')
	
	// 确保目录存在
	os.mkdir_all(chunk_dir) or {
		println('[DEBUG] Failed to create chunk directory: $err')
		return
	}
	
	// 读取现有的总大小记录
	mut total_size := u64(0)
	if os.exists(size_record_path) {
		size_data := os.read_file(size_record_path) or { '0' }
		total_size = size_data.u64()
	}
	
	// 更新总大小
	total_size += u64(current_chunk_size)
	
	// 写入更新后的总大小
	os.write_file(size_record_path, total_size.str()) or {
		println('[DEBUG] Failed to write size record: $err')
	}
	
	println('[DEBUG] Updated size record: $total_size bytes')
}

// 获取分片大小记录
pub fn (manager ChunkUploadManager) get_chunk_size_record(file_hash string, chunk_size int) u64 {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	size_record_path := os.join_path(chunk_dir, 'total_size.record')
	
	if os.exists(size_record_path) {
		size_data := os.read_file(size_record_path) or { '0' }
		return size_data.u64()
	}
	
	return u64(0)
}

// 清理分片大小记录
pub fn (mut manager ChunkUploadManager) cleanup_chunk_size_record(file_hash string, chunk_size int) {
	chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
	size_record_path := os.join_path(chunk_dir, 'total_size.record')
	
	if os.exists(size_record_path) {
		os.rm(size_record_path) or {
			println('[DEBUG] Failed to remove size record: $err')
		}
	}
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

// 关闭管理器（释放资源）
pub fn (mut manager ChunkUploadManager) close() {
	// 关闭数据库连接
	manager.db.close()
	
	// 如果使用了 FileService，也关闭它
	if manager.file_service != unsafe { nil } {
		manager.file_service.close()
	}
}

// 检查是否使用 FileService
pub fn (manager ChunkUploadManager) uses_file_service() bool {
	return manager.file_service != unsafe { nil } && manager.config.use_file_service
}

// 获取 FileService（如果存在）
pub fn (manager ChunkUploadManager) get_file_service() ?&FileService {
	if manager.file_service != unsafe { nil } {
		return manager.file_service
	}
	return none
} 