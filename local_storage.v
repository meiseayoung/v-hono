module hono

import os
import io
import time
import rand
import crypto.md5

// LocalStorage 本地存储提供者
pub struct LocalStorage {
	config LocalStorageConfig
mut:
	// 用于跟踪分片上传的内存存储
	multipart_uploads map[string]MultipartUploadState
}

// 分片上传状态
struct MultipartUploadState {
mut:
	bucket       string
	key          string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

// 创建本地存储提供者
pub fn new_local_storage(config LocalStorageConfig) !LocalStorage {
	// 确保基础目录存在
	if config.create_dirs {
		os.mkdir_all(config.base_path) or {
			return error('Failed to create base directory: ${err}')
		}
	}
	return LocalStorage{
		config: config
		multipart_uploads: map[string]MultipartUploadState{}
	}
}

// 获取文件的完整路径
fn (s LocalStorage) get_full_path(bucket string, key string) string {
	return os.join_path(s.config.base_path, bucket, key)
}

// 获取 bucket 目录路径
fn (s LocalStorage) get_bucket_path(bucket string) string {
	return os.join_path(s.config.base_path, bucket)
}

// 计算数据的 ETag (MD5)
fn calculate_etag(data []u8) string {
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return '"${result}"'
}


// ============================================================================
// StorageProvider 接口实现 - 基本操作
// ============================================================================

// 上传文件
pub fn (mut s LocalStorage) upload(bucket string, key string, data []u8, content_type string) !StorageResult {
	// 确保 bucket 目录存在
	bucket_path := s.get_bucket_path(bucket)
	if s.config.create_dirs {
		os.mkdir_all(bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create bucket directory: ${err}',
				'local', 'upload').msg())
		}
	}

	// 获取完整文件路径
	full_path := s.get_full_path(bucket, key)

	// 确保父目录存在
	parent_dir := os.dir(full_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create parent directory: ${err}',
				'local', 'upload').msg())
		}
	}

	// 写入文件
	os.write_file_array(full_path, data) or {
		return error(new_storage_error(.unknown, 'Failed to write file: ${err}', 'local',
			'upload').msg())
	}

	// 计算 ETag
	etag := calculate_etag(data)

	return new_storage_result(key, etag, i64(data.len))
}

// 流式上传文件
pub fn (mut s LocalStorage) upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult {
	// 确保 bucket 目录存在
	bucket_path := s.get_bucket_path(bucket)
	if s.config.create_dirs {
		os.mkdir_all(bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create bucket directory: ${err}',
				'local', 'upload_stream').msg())
		}
	}

	// 获取完整文件路径
	full_path := s.get_full_path(bucket, key)

	// 确保父目录存在
	parent_dir := os.dir(full_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create parent directory: ${err}',
				'local', 'upload_stream').msg())
		}
	}

	// 读取所有数据
	mut data := []u8{}
	mut buf := []u8{len: 8192}
	for {
		n := reader.read(mut buf) or { break }
		if n == 0 {
			break
		}
		data << buf[..n]
	}

	// 写入文件
	os.write_file_array(full_path, data) or {
		return error(new_storage_error(.unknown, 'Failed to write file: ${err}', 'local',
			'upload_stream').msg())
	}

	// 计算 ETag
	etag := calculate_etag(data)

	return new_storage_result(key, etag, i64(data.len))
}

// 下载文件
pub fn (s LocalStorage) download(bucket string, key string) ![]u8 {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	data := os.read_bytes(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to read file: ${err}', 'local',
			'download').msg())
	}

	return data
}

// 流式下载文件
pub fn (s LocalStorage) download_stream(bucket string, key string, mut writer io.Writer) !i64 {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	data := os.read_bytes(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to read file: ${err}', 'local',
			'download_stream').msg())
	}

	written := writer.write(data) or {
		return error(new_storage_error(.unknown, 'Failed to write to stream: ${err}', 'local',
			'download_stream').msg())
	}

	return i64(written)
}

// 删除文件
pub fn (s LocalStorage) delete(bucket string, key string) ! {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	os.rm(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to delete file: ${err}', 'local',
			'delete').msg())
	}
}

// 检查文件是否存在
pub fn (s LocalStorage) exists(bucket string, key string) !bool {
	full_path := s.get_full_path(bucket, key)
	return os.exists(full_path) && os.is_file(full_path)
}


// ============================================================================
// StorageProvider 接口实现 - 元数据操作
// ============================================================================

// 获取文件元数据
pub fn (s LocalStorage) head(bucket string, key string) !ObjectInfo {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	// 获取文件信息
	file_size := os.file_size(full_path)
	mtime := os.file_last_mod_unix(full_path)

	// 读取文件计算 ETag
	data := os.read_bytes(full_path) or {
		return error(new_storage_error(.unknown, 'Failed to read file for metadata: ${err}',
			'local', 'head').msg())
	}
	etag := calculate_etag(data)

	// 推断 content_type
	content_type := infer_content_type(key)

	return new_object_info(key, i64(file_size), etag, content_type, mtime)
}

// 复制文件
pub fn (mut s LocalStorage) copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult {
	src_path := s.get_full_path(src_bucket, src_key)

	if !os.exists(src_path) {
		return error(new_not_found_error('local', src_bucket, src_key).msg())
	}

	// 确保目标 bucket 目录存在
	dst_bucket_path := s.get_bucket_path(dst_bucket)
	if s.config.create_dirs {
		os.mkdir_all(dst_bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create destination bucket directory: ${err}',
				'local', 'copy').msg())
		}
	}

	dst_path := s.get_full_path(dst_bucket, dst_key)

	// 确保目标父目录存在
	parent_dir := os.dir(dst_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create destination parent directory: ${err}',
				'local', 'copy').msg())
		}
	}

	// 复制文件
	os.cp(src_path, dst_path) or {
		return error(new_storage_error(.unknown, 'Failed to copy file: ${err}', 'local',
			'copy').msg())
	}

	// 读取文件计算 ETag 和大小
	data := os.read_bytes(dst_path) or {
		return error(new_storage_error(.unknown, 'Failed to read copied file: ${err}', 'local',
			'copy').msg())
	}
	etag := calculate_etag(data)

	return new_storage_result(dst_key, etag, i64(data.len))
}

// ============================================================================
// StorageProvider 接口实现 - 列表操作
// ============================================================================

// 列出文件
pub fn (s LocalStorage) list(bucket string, options ListOptions) !ListResult {
	bucket_path := s.get_bucket_path(bucket)

	if !os.exists(bucket_path) {
		return error(new_bucket_not_found_error('local', bucket).msg())
	}

	mut objects := []ObjectInfo{}
	mut common_prefixes := []string{}

	// 递归遍历目录
	s.list_directory_recursive(bucket_path, bucket_path, options.prefix, options.delimiter,
		options.start_after, options.max_keys, mut objects, mut common_prefixes)

	// 检查是否有更多结果
	is_truncated := objects.len >= options.max_keys
	next_marker := if is_truncated && objects.len > 0 { objects.last().key } else { '' }

	return new_list_result(objects, common_prefixes, is_truncated, next_marker)
}

// 递归列出目录内容
fn (s LocalStorage) list_directory_recursive(base_path string, current_path string, prefix string, delimiter string, start_after string, max_keys int, mut objects []ObjectInfo, mut common_prefixes []string) {
	if objects.len >= max_keys {
		return
	}

	entries := os.ls(current_path) or { return }

	for entry in entries {
		if objects.len >= max_keys {
			return
		}

		entry_path := os.join_path(current_path, entry)
		// 计算相对于 bucket 的 key
		relative_key := entry_path.replace(base_path + os.path_separator, '').replace(os.path_separator,
			'/')

		// 检查前缀匹配
		if prefix != '' && !relative_key.starts_with(prefix) {
			continue
		}

		// 检查 start_after
		if start_after != '' && relative_key <= start_after {
			continue
		}

		if os.is_dir(entry_path) {
			// 如果有分隔符，添加到 common_prefixes
			if delimiter != '' {
				prefix_key := relative_key + '/'
				if prefix_key !in common_prefixes {
					common_prefixes << prefix_key
				}
			} else {
				// 递归遍历子目录
				s.list_directory_recursive(base_path, entry_path, prefix, delimiter,
					start_after, max_keys, mut objects, mut common_prefixes)
			}
		} else {
			// 文件
			file_size := os.file_size(entry_path)
			mtime := os.file_last_mod_unix(entry_path)

			// 读取文件计算 ETag
			data := os.read_bytes(entry_path) or { continue }
			etag := calculate_etag(data)
			content_type := infer_content_type(relative_key)

			objects << new_object_info(relative_key, i64(file_size), etag, content_type,
				mtime)
		}
	}
}


// ============================================================================
// StorageProvider 接口实现 - 预签名 URL
// ============================================================================

// 生成预签名 URL
pub fn (s LocalStorage) presign_url(bucket string, key string, options PresignOptions) !string {
	full_path := s.get_full_path(bucket, key)

	// 对于 GET 请求，检查文件是否存在
	if options.method == 'GET' && !os.exists(full_path) {
		return error(new_not_found_error('local', bucket, key).msg())
	}

	// 本地存储返回 HTTP URL 或文件路径
	if s.config.url_prefix != '' {
		// 返回 HTTP URL
		return '${s.config.url_prefix}/${bucket}/${key}'
	} else {
		// 返回本地文件路径
		return full_path
	}
}

// ============================================================================
// StorageProvider 接口实现 - 分片上传
// ============================================================================

// 初始化分片上传
pub fn (mut s LocalStorage) init_multipart(bucket string, key string, content_type string) !string {
	// 确保 bucket 目录存在
	bucket_path := s.get_bucket_path(bucket)
	if s.config.create_dirs {
		os.mkdir_all(bucket_path) or {
			return error(new_storage_error(.invalid_config, 'Failed to create bucket directory: ${err}',
				'local', 'init_multipart').msg())
		}
	}

	// 生成 upload_id
	upload_id := generate_upload_id()

	// 创建临时目录存储分片
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	os.mkdir_all(temp_dir) or {
		return error(new_storage_error(.unknown, 'Failed to create temp directory: ${err}',
			'local', 'init_multipart').msg())
	}

	// 记录上传状态
	s.multipart_uploads[upload_id] = MultipartUploadState{
		bucket: bucket
		key: key
		content_type: content_type
		parts: map[int]PartInfo{}
		created_at: time.now().unix()
	}

	return upload_id
}

// 上传分片
pub fn (mut s LocalStorage) upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string {
	// 检查上传是否存在
	if upload_id !in s.multipart_uploads {
		return error(new_storage_error(.object_not_found, 'Multipart upload not found: ${upload_id}',
			'local', 'upload_part').msg())
	}

	// 写入分片文件
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	part_path := os.join_path(temp_dir, '${part_number}')

	os.write_file_array(part_path, data) or {
		return error(new_storage_error(.unknown, 'Failed to write part: ${err}', 'local',
			'upload_part').msg())
	}

	// 计算 ETag
	etag := calculate_etag(data)

	// 更新上传状态
	mut upload_state := s.multipart_uploads[upload_id]
	upload_state.parts[part_number] = new_part_info(part_number, etag, i64(data.len))
	s.multipart_uploads[upload_id] = upload_state

	return etag
}

// 完成分片上传
pub fn (mut s LocalStorage) complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult {
	// 检查上传是否存在
	if upload_id !in s.multipart_uploads {
		return error(new_storage_error(.object_not_found, 'Multipart upload not found: ${upload_id}',
			'local', 'complete_multipart').msg())
	}

	_ := s.multipart_uploads[upload_id] // 验证上传存在
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)

	// 合并所有分片
	mut final_data := []u8{}
	for part in parts {
		part_path := os.join_path(temp_dir, '${part.part_number}')
		part_data := os.read_bytes(part_path) or {
			return error(new_storage_error(.object_not_found, 'Part not found: ${part.part_number}',
				'local', 'complete_multipart').msg())
		}
		final_data << part_data
	}

	// 写入最终文件
	full_path := s.get_full_path(bucket, key)

	// 确保父目录存在
	parent_dir := os.dir(full_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error(new_storage_error(.invalid_config, 'Failed to create parent directory: ${err}',
				'local', 'complete_multipart').msg())
		}
	}

	os.write_file_array(full_path, final_data) or {
		return error(new_storage_error(.unknown, 'Failed to write final file: ${err}',
			'local', 'complete_multipart').msg())
	}

	// 清理临时文件
	os.rmdir_all(temp_dir) or {}

	// 删除上传状态
	s.multipart_uploads.delete(upload_id)

	// 计算 ETag
	etag := calculate_etag(final_data)

	return new_storage_result(key, etag, i64(final_data.len))
}

// 取消分片上传
pub fn (mut s LocalStorage) abort_multipart(bucket string, key string, upload_id string) ! {
	// 检查上传是否存在
	if upload_id !in s.multipart_uploads {
		return error(new_storage_error(.object_not_found, 'Multipart upload not found: ${upload_id}',
			'local', 'abort_multipart').msg())
	}

	// 清理临时文件
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	os.rmdir_all(temp_dir) or {}

	// 删除上传状态
	s.multipart_uploads.delete(upload_id)
}


// ============================================================================
// StorageProvider 接口实现 - Bucket 操作
// ============================================================================

// 创建 bucket
pub fn (s LocalStorage) create_bucket(bucket string) ! {
	bucket_path := s.get_bucket_path(bucket)

	if os.exists(bucket_path) {
		return // Bucket 已存在，不报错
	}

	os.mkdir_all(bucket_path) or {
		return error(new_storage_error(.unknown, 'Failed to create bucket: ${err}', 'local',
			'create_bucket').msg())
	}
}

// 删除 bucket
pub fn (s LocalStorage) delete_bucket(bucket string) ! {
	bucket_path := s.get_bucket_path(bucket)

	if !os.exists(bucket_path) {
		return error(new_bucket_not_found_error('local', bucket).msg())
	}

	// 检查 bucket 是否为空
	entries := os.ls(bucket_path) or { []string{} }
	if entries.len > 0 {
		return error(new_storage_error(.access_denied, 'Bucket is not empty', 'local',
			'delete_bucket').msg())
	}

	os.rmdir(bucket_path) or {
		return error(new_storage_error(.unknown, 'Failed to delete bucket: ${err}', 'local',
			'delete_bucket').msg())
	}
}

// 检查 bucket 是否存在
pub fn (s LocalStorage) bucket_exists(bucket string) !bool {
	bucket_path := s.get_bucket_path(bucket)
	return os.exists(bucket_path) && os.is_dir(bucket_path)
}

// 获取提供者名称
pub fn (s LocalStorage) provider_name() string {
	return 'local'
}

// ============================================================================
// 辅助函数
// ============================================================================

// 生成上传 ID
fn generate_upload_id() string {
	now := time.now().unix_nano()
	random_bytes := rand.bytes(8) or { []u8{len: 8} }
	mut random_hex := ''
	for b in random_bytes {
		random_hex += '${b:02x}'
	}
	return '${now}-${random_hex}'
}

// 根据文件扩展名推断 content_type
fn infer_content_type(key string) string {
	ext := os.file_ext(key).to_lower()
	match ext {
		'.html', '.htm' { return 'text/html' }
		'.css' { return 'text/css' }
		'.js' { return 'application/javascript' }
		'.json' { return 'application/json' }
		'.xml' { return 'application/xml' }
		'.txt' { return 'text/plain' }
		'.png' { return 'image/png' }
		'.jpg', '.jpeg' { return 'image/jpeg' }
		'.gif' { return 'image/gif' }
		'.svg' { return 'image/svg+xml' }
		'.webp' { return 'image/webp' }
		'.ico' { return 'image/x-icon' }
		'.pdf' { return 'application/pdf' }
		'.zip' { return 'application/zip' }
		'.gz', '.gzip' { return 'application/gzip' }
		'.tar' { return 'application/x-tar' }
		'.mp3' { return 'audio/mpeg' }
		'.mp4' { return 'video/mp4' }
		'.webm' { return 'video/webm' }
		'.woff' { return 'font/woff' }
		'.woff2' { return 'font/woff2' }
		'.ttf' { return 'font/ttf' }
		'.otf' { return 'font/otf' }
		else { return 'application/octet-stream' }
	}
}
