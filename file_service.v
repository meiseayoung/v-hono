module hono

import os
import time
import crypto.md5

// FileService 统一文件服务层
// 提供高级文件操作 API，管理存储提供者和元数据
@[heap]
pub struct FileService {
mut:
	provider      &StorageProvider = unsafe { nil }
	db            DatabaseManager
	config        FileServiceConfig
	chunk_manager ChunkManager
	// 用于热加载的配置
	current_config StorageConfig
}

// FileService 配置
pub struct FileServiceConfig {
pub:
	storage        StorageConfig
	db_path        string = './storage/files.db'
	default_bucket string = 'default'
	chunk_size     int    = 5 * 1024 * 1024 // 5MB
	max_file_size  i64    = 5 * 1024 * 1024 * 1024 // 5GB
}

// 文件上传参数
pub struct UploadParams {
pub:
	bucket       string
	filename     string
	content_type string
	metadata     string // JSON 格式的额外元数据
}

// 文件上传结果
pub struct UploadResult {
pub:
	file_uuid    string
	file_hash    string
	file_name    string
	file_size    i64
	file_type    string
	storage_type string
	bucket       string
	object_key   string
	etag         string
	created_at   i64
}

// 预签名 URL 结果
pub struct PresignResult {
pub:
	url        string
	expires_at i64
	method     string
}

// ============================================================================
// 存储提供者工厂方法
// ============================================================================

// 根据配置创建存储提供者
pub fn create_storage_provider(config StorageConfig) !&StorageProvider {
	match config.storage_type {
		.local {
			mut provider := new_local_storage(config.local)!
			return &provider
		}
		.s3 {
			mut provider := new_s3_storage(config.s3)!
			return &provider
		}
		.aliyun_oss {
			mut provider := new_aliyun_oss(config.aliyun_oss)!
			return &provider
		}
		.tencent_cos {
			mut provider := new_tencent_cos(config.tencent_cos)!
			return &provider
		}
	}
}

// 根据存储类型字符串创建存储提供者
pub fn create_storage_provider_by_type(storage_type string, config StorageConfig) !&StorageProvider {
	match storage_type.to_lower() {
		'local' {
			mut provider := new_local_storage(config.local)!
			return &provider
		}
		's3' {
			mut provider := new_s3_storage(config.s3)!
			return &provider
		}
		'aliyun_oss', 'oss' {
			mut provider := new_aliyun_oss(config.aliyun_oss)!
			return &provider
		}
		'tencent_cos', 'cos' {
			mut provider := new_tencent_cos(config.tencent_cos)!
			return &provider
		}
		else {
			return error('Unknown storage type: ${storage_type}')
		}
	}
}

// ============================================================================
// FileService 创建和初始化
// ============================================================================

// 创建 FileService
pub fn new_file_service(config FileServiceConfig) !FileService {
	// 验证存储配置
	validation := validate_storage_config(config.storage)
	if !validation.valid {
		return error(validation.error_message)
	}

	// 确保数据库目录存在
	db_dir := os.dir(config.db_path)
	if db_dir != '' && db_dir != '.' {
		os.mkdir_all(db_dir) or {
			return error('Failed to create database directory: ${err}')
		}
	}

	// 创建数据库管理器
	mut db := new_database_manager(config.db_path)!

	// 创建存储提供者
	provider := create_storage_provider(config.storage)!

	// 创建分片管理器
	chunk_manager := new_chunk_manager_default(mut db, provider)

	return FileService{
		provider: provider
		db: db
		config: config
		chunk_manager: chunk_manager
		current_config: config.storage
	}
}

// 使用默认配置创建本地存储的 FileService
pub fn new_local_file_service(base_path string, db_path string) !FileService {
	config := FileServiceConfig{
		storage: new_local_storage_config(base_path)
		db_path: db_path
		default_bucket: 'default'
	}
	return new_file_service(config)
}

// 从 JSON 配置文件创建 FileService
pub fn new_file_service_from_config_file(config_path string, db_path string) !FileService {
	storage_config := load_storage_config_from_file(config_path)!
	config := FileServiceConfig{
		storage: storage_config
		db_path: db_path
		default_bucket: get_default_bucket(storage_config)
	}
	return new_file_service(config)
}

// 从环境变量创建 FileService
pub fn new_file_service_from_env(db_path string) !FileService {
	storage_config := load_storage_config_from_env()!
	config := FileServiceConfig{
		storage: storage_config
		db_path: db_path
		default_bucket: get_default_bucket(storage_config)
	}
	return new_file_service(config)
}

// 获取默认 bucket
fn get_default_bucket(config StorageConfig) string {
	match config.storage_type {
		.local { return 'default' }
		.s3 { return config.s3.default_bucket }
		.aliyun_oss { return config.aliyun_oss.default_bucket }
		.tencent_cos { return config.tencent_cos.default_bucket }
	}
}


// ============================================================================
// 高级文件操作 API
// ============================================================================

// 上传文件
pub fn (mut fs FileService) upload_file(params UploadParams, data []u8) !UploadResult {
	bucket := if params.bucket != '' { params.bucket } else { fs.config.default_bucket }
	
	// 检查文件大小
	if i64(data.len) > fs.config.max_file_size {
		return error('File size exceeds maximum allowed size: ${data.len} > ${fs.config.max_file_size}')
	}

	// 计算文件哈希
	file_hash := calculate_md5_hash(data)

	// 生成对象键
	object_key := generate_object_key(params.filename, file_hash)

	// 确定 content_type
	content_type := if params.content_type != '' {
		params.content_type
	} else {
		infer_content_type(params.filename)
	}

	// 上传到存储提供者
	result := fs.provider.upload(bucket, object_key, data, content_type)!

	// 保存文件元数据到数据库
	file_info := fs.db.insert_file(FileInfo{
		file_hash: file_hash
		file_name: params.filename
		file_size: i64(data.len)
		file_type: content_type
		storage_type: fs.provider.provider_name()
		bucket: bucket
		object_key: object_key
		metadata: params.metadata
	})!

	return UploadResult{
		file_uuid: file_info.file_uuid
		file_hash: file_hash
		file_name: params.filename
		file_size: i64(data.len)
		file_type: content_type
		storage_type: fs.provider.provider_name()
		bucket: bucket
		object_key: object_key
		etag: result.etag
		created_at: file_info.created_at
	}
}

// 下载文件（通过 UUID）
pub fn (mut fs FileService) download_file(file_uuid string) ![]u8 {
	// 获取文件元数据
	file_info := fs.db.get_file_by_uuid(file_uuid)!

	// 从存储提供者下载
	return fs.provider.download(file_info.bucket, file_info.object_key)
}

// 下载文件（通过 bucket 和 key）
pub fn (mut fs FileService) download_file_by_key(bucket string, object_key string) ![]u8 {
	return fs.provider.download(bucket, object_key)
}

// 删除文件（通过 UUID）
pub fn (mut fs FileService) delete_file(file_uuid string) ! {
	// 获取文件元数据
	file_info := fs.db.get_file_by_uuid(file_uuid)!

	// 从存储提供者删除
	fs.provider.delete(file_info.bucket, file_info.object_key)!

	// 从数据库删除元数据
	fs.db.delete_file(file_uuid)!
}

// 获取文件信息（通过 UUID）
pub fn (fs FileService) get_file_info(file_uuid string) !FileInfo {
	return fs.db.get_file_by_uuid(file_uuid)
}

// 获取文件信息（通过哈希）
pub fn (fs FileService) get_file_by_hash(file_hash string) !FileInfo {
	return fs.db.get_file_by_hash(file_hash)
}

// 检查文件是否存在（通过 UUID）
pub fn (fs FileService) file_exists(file_uuid string) bool {
	return fs.db.file_exists(file_uuid)
}

// 检查文件是否存在（通过 bucket 和 key）
pub fn (mut fs FileService) file_exists_by_key(bucket string, object_key string) !bool {
	return fs.provider.exists(bucket, object_key)
}

// 获取预签名 URL
pub fn (mut fs FileService) get_presigned_url(file_uuid string, expires_in int) !PresignResult {
	// 获取文件元数据
	file_info := fs.db.get_file_by_uuid(file_uuid)!

	// 生成预签名 URL
	url := fs.provider.presign_url(file_info.bucket, file_info.object_key, PresignOptions{
		expires_in: expires_in
		method: 'GET'
	})!

	return PresignResult{
		url: url
		expires_at: time.now().unix() + i64(expires_in)
		method: 'GET'
	}
}

// 获取预签名上传 URL
pub fn (mut fs FileService) get_presigned_upload_url(bucket string, object_key string, expires_in int, content_type string) !PresignResult {
	url := fs.provider.presign_url(bucket, object_key, PresignOptions{
		expires_in: expires_in
		method: 'PUT'
		content_type: content_type
	})!

	return PresignResult{
		url: url
		expires_at: time.now().unix() + i64(expires_in)
		method: 'PUT'
	}
}

// 列出文件
pub fn (fs FileService) list_files(options FileListOptions) !FileListResult {
	return fs.db.list_files(options)
}

// 更新文件元数据
pub fn (mut fs FileService) update_file_metadata(file_uuid string, file_name string, file_type string, metadata string) !FileInfo {
	return fs.db.update_file(file_uuid, file_name, file_type, metadata)
}

// 复制文件
pub fn (mut fs FileService) copy_file(file_uuid string, dst_bucket string, dst_key string) !UploadResult {
	// 获取源文件信息
	src_info := fs.db.get_file_by_uuid(file_uuid)!

	// 复制文件
	result := fs.provider.copy(src_info.bucket, src_info.object_key, dst_bucket, dst_key)!

	// 保存新文件元数据
	new_info := fs.db.insert_file(FileInfo{
		file_hash: src_info.file_hash
		file_name: src_info.file_name
		file_size: src_info.file_size
		file_type: src_info.file_type
		storage_type: fs.provider.provider_name()
		bucket: dst_bucket
		object_key: dst_key
		metadata: src_info.metadata
	})!

	return UploadResult{
		file_uuid: new_info.file_uuid
		file_hash: src_info.file_hash
		file_name: src_info.file_name
		file_size: src_info.file_size
		file_type: src_info.file_type
		storage_type: fs.provider.provider_name()
		bucket: dst_bucket
		object_key: dst_key
		etag: result.etag
		created_at: new_info.created_at
	}
}


// ============================================================================
// 分片上传操作
// ============================================================================

// 初始化分片上传
pub fn (mut fs FileService) init_multipart_upload(params InitMultipartParams) !MultipartUpload {
	mut p := params
	if p.bucket == '' {
		p = InitMultipartParams{
			...params
			bucket: fs.config.default_bucket
		}
	}
	if p.chunk_size == 0 {
		p = InitMultipartParams{
			...p
			chunk_size: fs.config.chunk_size
		}
	}
	return fs.chunk_manager.init_multipart(p)
}

// 上传分片
pub fn (mut fs FileService) upload_part(upload_id string, part_number int, data []u8) !ChunkUploadResult {
	return fs.chunk_manager.upload_part(upload_id, part_number, data)
}

// 完成分片上传
pub fn (mut fs FileService) complete_multipart_upload(upload_id string) !StorageResult {
	return fs.chunk_manager.complete_multipart(upload_id)
}

// 取消分片上传
pub fn (mut fs FileService) abort_multipart_upload(upload_id string) ! {
	return fs.chunk_manager.abort_multipart(upload_id)
}

// 获取上传进度
pub fn (fs FileService) get_upload_progress(upload_id string) !UploadProgress {
	return fs.chunk_manager.get_upload_progress(upload_id)
}

// 获取待上传的分片列表
pub fn (fs FileService) get_pending_parts(upload_id string) ![]int {
	return fs.chunk_manager.get_pending_parts(upload_id)
}

// ============================================================================
// 提供者切换
// ============================================================================

// 切换存储提供者
pub fn (mut fs FileService) switch_provider(config StorageConfig) ! {
	// 验证新配置
	validation := validate_storage_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	// 创建新的存储提供者
	new_provider := create_storage_provider(config)!

	// 更新提供者
	fs.provider = new_provider
	fs.current_config = config

	// 更新分片管理器的提供者
	fs.chunk_manager = new_chunk_manager_default(mut fs.db, new_provider)
}

// 切换到本地存储
pub fn (mut fs FileService) switch_to_local(base_path string) ! {
	config := new_local_storage_config(base_path)
	fs.switch_provider(config)!
}

// 切换到 S3 存储
pub fn (mut fs FileService) switch_to_s3(endpoint string, access_key string, secret_key string, bucket string) ! {
	config := new_s3_storage_config(endpoint, access_key, secret_key, bucket)
	fs.switch_provider(config)!
}

// 切换到 MinIO 存储
pub fn (mut fs FileService) switch_to_minio(endpoint string, access_key string, secret_key string, bucket string) ! {
	config := new_minio_storage_config(endpoint, access_key, secret_key, bucket)
	fs.switch_provider(config)!
}

// 切换到阿里云 OSS
pub fn (mut fs FileService) switch_to_aliyun_oss(endpoint string, access_key_id string, access_key_secret string, bucket string) ! {
	config := new_aliyun_oss_storage_config(endpoint, access_key_id, access_key_secret, bucket)
	fs.switch_provider(config)!
}

// 切换到腾讯云 COS
pub fn (mut fs FileService) switch_to_tencent_cos(secret_id string, secret_key string, region string, bucket string) ! {
	config := new_tencent_cos_storage_config(secret_id, secret_key, region, bucket)
	fs.switch_provider(config)!
}

// 从配置文件热加载配置
pub fn (mut fs FileService) reload_config_from_file(config_path string) ! {
	config := load_storage_config_from_file(config_path)!
	fs.switch_provider(config)!
}

// 从环境变量热加载配置
pub fn (mut fs FileService) reload_config_from_env() ! {
	config := load_storage_config_from_env()!
	fs.switch_provider(config)!
}


// ============================================================================
// 状态和信息查询
// ============================================================================

// 获取当前存储提供者名称
pub fn (mut fs FileService) get_current_provider_name() string {
	return fs.provider.provider_name()
}

// 获取当前存储类型
pub fn (fs FileService) get_current_storage_type() StorageType {
	return fs.current_config.storage_type
}

// 获取当前配置
pub fn (fs FileService) get_current_config() StorageConfig {
	return fs.current_config
}

// 获取默认 bucket
pub fn (fs FileService) get_default_bucket() string {
	return fs.config.default_bucket
}

// 获取分片大小
pub fn (fs FileService) get_chunk_size() int {
	return fs.config.chunk_size
}

// 获取最大文件大小
pub fn (fs FileService) get_max_file_size() i64 {
	return fs.config.max_file_size
}

// 检查 bucket 是否存在
pub fn (mut fs FileService) bucket_exists(bucket string) !bool {
	return fs.provider.bucket_exists(bucket)
}

// 创建 bucket
pub fn (mut fs FileService) create_bucket(bucket string) ! {
	return fs.provider.create_bucket(bucket)
}

// 删除 bucket
pub fn (mut fs FileService) delete_bucket(bucket string) ! {
	return fs.provider.delete_bucket(bucket)
}

// 关闭 FileService
pub fn (mut fs FileService) close() {
	fs.db.close()
}

// ============================================================================
// 辅助函数
// ============================================================================

// 计算 MD5 哈希
fn calculate_md5_hash(data []u8) string {
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return result
}

// 生成对象键
fn generate_object_key(filename string, file_hash string) string {
	// 使用日期和哈希前缀组织文件
	now := time.now()
	date_prefix := now.custom_format('YYYY/MM/DD')
	hash_prefix := file_hash[..8]
	
	// 获取文件扩展名
	ext := os.file_ext(filename)
	
	return '${date_prefix}/${hash_prefix}/${file_hash}${ext}'
}
