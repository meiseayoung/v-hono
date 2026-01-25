module hono

import io

// 存储操作结果
pub struct StorageResult {
pub:
	success    bool
	object_key string
	etag       string
	size       i64
	error_msg  string
}

// 文件对象信息
pub struct ObjectInfo {
pub:
	key           string
	size          i64
	etag          string
	content_type  string
	last_modified i64
	metadata      map[string]string
}

// 列表选项
pub struct ListOptions {
pub:
	prefix      string
	delimiter   string
	max_keys    int = 1000
	start_after string
}

// 列表结果
pub struct ListResult {
pub:
	objects         []ObjectInfo
	common_prefixes []string
	is_truncated    bool
	next_marker     string
}

// 预签名URL选项
pub struct PresignOptions {
pub:
	expires_in   int    = 3600 // 秒
	method       string = 'GET'
	content_type string
}

// 分片信息
pub struct PartInfo {
pub:
	part_number int
	etag        string
	size        i64
}


// 统一存储接口
pub interface StorageProvider {
mut:
	// 基本操作
	upload(bucket string, key string, data []u8, content_type string) !StorageResult
	upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult
	download(bucket string, key string) ![]u8
	download_stream(bucket string, key string, mut writer io.Writer) !i64
	delete(bucket string, key string) !
	exists(bucket string, key string) !bool
	// 元数据操作
	head(bucket string, key string) !ObjectInfo
	copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult
	// 列表操作
	list(bucket string, options ListOptions) !ListResult
	// 预签名URL
	presign_url(bucket string, key string, options PresignOptions) !string
	// 分片上传
	init_multipart(bucket string, key string, content_type string) !string // 返回 upload_id
	upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string // 返回 etag
	complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult
	abort_multipart(bucket string, key string, upload_id string) !
	// Bucket 操作
	create_bucket(bucket string) !
	delete_bucket(bucket string) !
	bucket_exists(bucket string) !bool
	// 获取提供者名称
	provider_name() string
}

// 创建成功的存储结果
pub fn new_storage_result(object_key string, etag string, size i64) StorageResult {
	return StorageResult{
		success: true
		object_key: object_key
		etag: etag
		size: size
		error_msg: ''
	}
}

// 创建失败的存储结果
pub fn new_storage_error_result(error_msg string) StorageResult {
	return StorageResult{
		success: false
		object_key: ''
		etag: ''
		size: 0
		error_msg: error_msg
	}
}

// 创建对象信息
pub fn new_object_info(key string, size i64, etag string, content_type string, last_modified i64) ObjectInfo {
	return ObjectInfo{
		key: key
		size: size
		etag: etag
		content_type: content_type
		last_modified: last_modified
		metadata: map[string]string{}
	}
}

// 创建带元数据的对象信息
pub fn new_object_info_with_metadata(key string, size i64, etag string, content_type string, last_modified i64, metadata map[string]string) ObjectInfo {
	return ObjectInfo{
		key: key
		size: size
		etag: etag
		content_type: content_type
		last_modified: last_modified
		metadata: metadata
	}
}

// 创建空的列表结果
pub fn new_empty_list_result() ListResult {
	return ListResult{
		objects: []ObjectInfo{}
		common_prefixes: []string{}
		is_truncated: false
		next_marker: ''
	}
}

// 创建列表结果
pub fn new_list_result(objects []ObjectInfo, common_prefixes []string, is_truncated bool, next_marker string) ListResult {
	return ListResult{
		objects: objects
		common_prefixes: common_prefixes
		is_truncated: is_truncated
		next_marker: next_marker
	}
}

// 创建分片信息
pub fn new_part_info(part_number int, etag string, size i64) PartInfo {
	return PartInfo{
		part_number: part_number
		etag: etag
		size: size
	}
}
