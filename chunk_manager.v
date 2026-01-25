module hono

import time
import crypto.md5

// 分片上传管理器
// 负责管理分片上传的生命周期，包括初始化、上传分片、完成和取消上传
@[heap]
pub struct ChunkManager {
mut:
	db       DatabaseManager
	provider &StorageProvider = unsafe { nil }
	config   ChunkManagerConfig
}

// 分片管理器配置
pub struct ChunkManagerConfig {
pub:
	default_chunk_size int = 5 * 1024 * 1024 // 5MB 默认分片大小
	max_chunk_size     int = 100 * 1024 * 1024 // 100MB 最大分片大小
	min_chunk_size     int = 1024 * 1024 // 1MB 最小分片大小
	max_parts          int = 10000 // 最大分片数量
	retry_count        int = 3 // 重试次数
	retry_delay_ms     int = 1000 // 重试延迟（毫秒）
}

// 上传进度信息
pub struct UploadProgress {
pub:
	upload_id       string
	file_uuid       string
	file_name       string
	file_size       i64
	chunk_size      int
	total_chunks    int
	uploaded_chunks int
	uploaded_bytes  i64
	progress_pct    f64
	status          string
	pending_parts   []int
	created_at      i64
	updated_at      i64
}

// 分片上传初始化参数
pub struct InitMultipartParams {
pub:
	bucket       string
	object_key   string
	file_name    string
	file_size    i64
	content_type string
	chunk_size   int // 可选，为0时使用默认值
}

// 分片上传结果
pub struct ChunkUploadResult {
pub:
	upload_id   string
	part_number int
	etag        string
	size        i64
	success     bool
	error_msg   string
}


// 创建分片管理器
pub fn new_chunk_manager(mut db DatabaseManager, provider &StorageProvider, config ChunkManagerConfig) ChunkManager {
	return ChunkManager{
		db: db
		provider: unsafe { provider }
		config: config
	}
}

// 创建使用默认配置的分片管理器
pub fn new_chunk_manager_default(mut db DatabaseManager, provider &StorageProvider) ChunkManager {
	return ChunkManager{
		db: db
		provider: unsafe { provider }
		config: ChunkManagerConfig{}
	}
}

// ============================================================================
// 核心分片上传操作
// ============================================================================

// 初始化分片上传
// 创建一个新的分片上传会话，返回 upload_id
pub fn (mut cm ChunkManager) init_multipart(params InitMultipartParams) !MultipartUpload {
	// 验证参数
	if params.bucket == '' {
		return error('Bucket name is required')
	}
	if params.object_key == '' {
		return error('Object key is required')
	}
	if params.file_size <= 0 {
		return error('File size must be positive')
	}

	// 确定分片大小
	chunk_size := if params.chunk_size > 0 {
		cm.validate_chunk_size(params.chunk_size)
	} else {
		cm.config.default_chunk_size
	}

	// 计算总分片数
	total_chunks := cm.calculate_total_chunks(params.file_size, chunk_size)
	if total_chunks > cm.config.max_parts {
		return error('File too large: would require ${total_chunks} parts, max is ${cm.config.max_parts}')
	}

	// 调用存储提供者初始化分片上传
	provider_upload_id := cm.provider.init_multipart(params.bucket, params.object_key,
		params.content_type)!

	// 在数据库中创建上传记录
	upload := cm.db.create_multipart_upload(MultipartUpload{
		upload_id: provider_upload_id
		file_name: params.file_name
		file_size: params.file_size
		chunk_size: chunk_size
		total_chunks: total_chunks
		bucket: params.bucket
		object_key: params.object_key
		content_type: params.content_type
	})!

	return upload
}

// 上传单个分片
pub fn (mut cm ChunkManager) upload_part(upload_id string, part_number int, data []u8) !ChunkUploadResult {
	// 获取上传状态
	upload := cm.db.get_multipart_upload(upload_id) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Upload not found: ${upload_id}'
		}
	}

	// 验证上传状态
	if upload.status != 'uploading' {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Upload is not in uploading state: ${upload.status}'
		}
	}

	// 验证分片号
	if part_number < 1 || part_number > upload.total_chunks {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Invalid part number: ${part_number}, expected 1-${upload.total_chunks}'
		}
	}

	// 调用存储提供者上传分片
	etag := cm.provider.upload_part(upload.bucket, upload.object_key, upload_id, part_number,
		data) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Failed to upload part: ${err}'
		}
	}

	// 记录已上传的分片
	cm.db.record_uploaded_part(upload_id, part_number, etag, i64(data.len)) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Failed to record uploaded part: ${err}'
		}
	}

	return ChunkUploadResult{
		upload_id: upload_id
		part_number: part_number
		etag: etag
		size: i64(data.len)
		success: true
		error_msg: ''
	}
}


// 完成分片上传
// 合并所有分片并创建最终文件
pub fn (mut cm ChunkManager) complete_multipart(upload_id string) !StorageResult {
	// 获取上传状态
	upload := cm.db.get_multipart_upload(upload_id)!

	// 验证上传状态
	if upload.status != 'uploading' {
		return error('Upload is not in uploading state: ${upload.status}')
	}

	// 获取所有已上传的分片
	uploaded_parts := cm.db.get_uploaded_parts(upload_id)!

	// 验证所有分片都已上传
	if uploaded_parts.len != upload.total_chunks {
		return error('Not all parts uploaded: ${uploaded_parts.len}/${upload.total_chunks}')
	}

	// 构建分片信息列表
	mut parts := []PartInfo{}
	for part in uploaded_parts {
		parts << new_part_info(part.part_number, part.etag, part.size)
	}

	// 按分片号排序
	parts.sort(a.part_number < b.part_number)

	// 调用存储提供者完成上传
	result := cm.provider.complete_multipart(upload.bucket, upload.object_key, upload_id,
		parts)!

	// 更新数据库状态
	cm.db.update_multipart_status(upload_id, 'completed')!

	// 在文件信息表中创建记录
	file_hash := calculate_chunk_file_hash(upload_id, upload.file_size)
	cm.db.insert_file(FileInfo{
		file_uuid: upload.file_uuid
		file_hash: file_hash
		file_name: upload.file_name
		file_size: upload.file_size
		file_type: upload.content_type
		storage_type: cm.provider.provider_name()
		bucket: upload.bucket
		object_key: upload.object_key
		metadata: ''
	}) or {
		// 文件已存在，忽略错误
	}

	return result
}

// 取消分片上传
// 清理所有已上传的分片和临时数据
pub fn (mut cm ChunkManager) abort_multipart(upload_id string) ! {
	// 获取上传状态
	upload := cm.db.get_multipart_upload(upload_id) or {
		return error('Upload not found: ${upload_id}')
	}

	// 调用存储提供者取消上传
	cm.provider.abort_multipart(upload.bucket, upload.object_key, upload_id) or {
		// 忽略存储提供者的错误，继续清理数据库
	}

	// 更新数据库状态
	cm.db.update_multipart_status(upload_id, 'aborted')!

	// 删除上传记录和分片记录
	cm.db.delete_multipart_upload(upload_id)!
}

// ============================================================================
// 上传进度和状态查询
// ============================================================================

// 获取上传进度
pub fn (cm ChunkManager) get_upload_progress(upload_id string) !UploadProgress {
	// 获取上传状态
	upload := cm.db.get_multipart_upload(upload_id)!

	// 获取已上传的分片
	uploaded_parts := cm.db.get_uploaded_parts(upload_id)!

	// 计算已上传字节数
	mut uploaded_bytes := i64(0)
	mut uploaded_part_numbers := map[int]bool{}
	for part in uploaded_parts {
		uploaded_bytes += part.size
		uploaded_part_numbers[part.part_number] = true
	}

	// 计算待上传的分片
	mut pending_parts := []int{}
	for i in 1 .. upload.total_chunks + 1 {
		if i !in uploaded_part_numbers {
			pending_parts << i
		}
	}

	// 计算进度百分比
	progress_pct := if upload.total_chunks > 0 {
		f64(uploaded_parts.len) / f64(upload.total_chunks) * 100.0
	} else {
		0.0
	}

	return UploadProgress{
		upload_id: upload_id
		file_uuid: upload.file_uuid
		file_name: upload.file_name
		file_size: upload.file_size
		chunk_size: upload.chunk_size
		total_chunks: upload.total_chunks
		uploaded_chunks: uploaded_parts.len
		uploaded_bytes: uploaded_bytes
		progress_pct: progress_pct
		status: upload.status
		pending_parts: pending_parts
		created_at: upload.created_at
		updated_at: upload.updated_at
	}
}

// 检查分片是否已上传
pub fn (cm ChunkManager) is_part_uploaded(upload_id string, part_number int) bool {
	return cm.db.is_part_uploaded(upload_id, part_number)
}

// 获取已上传的分片列表
pub fn (cm ChunkManager) get_uploaded_parts(upload_id string) ![]UploadedPart {
	return cm.db.get_uploaded_parts(upload_id)
}

// 列出所有进行中的上传
pub fn (cm ChunkManager) list_pending_uploads() ![]MultipartUpload {
	return cm.db.list_pending_multipart_uploads()
}


// ============================================================================
// 分片重试和恢复
// ============================================================================

// 重试上传单个分片
// 带有指数退避重试逻辑
pub fn (mut cm ChunkManager) retry_upload_part(upload_id string, part_number int, data []u8) !ChunkUploadResult {
	mut last_error := ''
	mut delay := cm.config.retry_delay_ms

	for attempt in 0 .. cm.config.retry_count + 1 {
		result := cm.upload_part(upload_id, part_number, data)!

		if result.success {
			return result
		}

		last_error = result.error_msg

		// 检查是否是可重试的错误
		if !cm.is_retryable_error(result.error_msg) {
			return result
		}

		// 如果不是最后一次尝试，等待后重试
		if attempt < cm.config.retry_count {
			time.sleep(delay * time.millisecond)
			delay = delay * 2 // 指数退避
			if delay > 30000 {
				delay = 30000 // 最大延迟 30 秒
			}
		}
	}

	return ChunkUploadResult{
		upload_id: upload_id
		part_number: part_number
		success: false
		error_msg: 'All retry attempts failed: ${last_error}'
	}
}

// 恢复上传（断点续传）
// 返回需要上传的分片列表
pub fn (cm ChunkManager) get_pending_parts(upload_id string) ![]int {
	progress := cm.get_upload_progress(upload_id)!
	return progress.pending_parts
}

// 批量上传待处理的分片
// data_provider 是一个函数，根据分片号返回分片数据
pub fn (mut cm ChunkManager) upload_pending_parts(upload_id string, data_provider fn (int) ![]u8) ![]ChunkUploadResult {
	pending_parts := cm.get_pending_parts(upload_id)!

	mut results := []ChunkUploadResult{}
	for part_number in pending_parts {
		data := data_provider(part_number) or {
			results << ChunkUploadResult{
				upload_id: upload_id
				part_number: part_number
				success: false
				error_msg: 'Failed to get data for part ${part_number}: ${err}'
			}
			continue
		}

		result := cm.retry_upload_part(upload_id, part_number, data) or {
			results << ChunkUploadResult{
				upload_id: upload_id
				part_number: part_number
				success: false
				error_msg: 'Failed to upload part ${part_number}: ${err}'
			}
			continue
		}

		results << result
	}

	return results
}

// ============================================================================
// 辅助方法
// ============================================================================

// 验证分片大小
fn (cm ChunkManager) validate_chunk_size(size int) int {
	if size < cm.config.min_chunk_size {
		return cm.config.min_chunk_size
	}
	if size > cm.config.max_chunk_size {
		return cm.config.max_chunk_size
	}
	return size
}

// 计算总分片数
fn (cm ChunkManager) calculate_total_chunks(file_size i64, chunk_size int) int {
	chunks := file_size / i64(chunk_size)
	if file_size % i64(chunk_size) > 0 {
		return int(chunks) + 1
	}
	return int(chunks)
}

// 判断错误是否可重试
fn (cm ChunkManager) is_retryable_error(error_msg string) bool {
	retryable_keywords := ['timeout', 'connection', 'network', 'unavailable', 'rate limit',
		'temporary']
	lower_msg := error_msg.to_lower()
	for keyword in retryable_keywords {
		if lower_msg.contains(keyword) {
			return true
		}
	}
	return false
}

// 计算文件哈希（用于文件记录）
fn calculate_chunk_file_hash(upload_id string, file_size i64) string {
	// 使用 upload_id 和 file_size 生成一个简单的哈希
	// 实际应用中应该使用文件内容的 MD5/SHA256
	data := '${upload_id}-${file_size}'.bytes()
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return result
}

// 获取分片的数据范围
pub fn (cm ChunkManager) get_part_range(upload_id string, part_number int) !(i64, i64) {
	upload := cm.db.get_multipart_upload(upload_id)!

	if part_number < 1 || part_number > upload.total_chunks {
		return error('Invalid part number: ${part_number}')
	}

	start := i64(part_number - 1) * i64(upload.chunk_size)
	mut end := start + i64(upload.chunk_size) - 1

	// 最后一个分片可能小于 chunk_size
	if end >= upload.file_size {
		end = upload.file_size - 1
	}

	return start, end
}

// 获取分片的预期大小
pub fn (cm ChunkManager) get_expected_part_size(upload_id string, part_number int) !i64 {
	start, end := cm.get_part_range(upload_id, part_number)!
	return end - start + 1
}


// ============================================================================
// 断点续传支持
// ============================================================================

// 恢复上传会话信息
// 用于客户端重新连接后恢复上传状态
pub struct ResumeInfo {
pub:
	upload_id       string
	file_uuid       string
	file_name       string
	file_size       i64
	chunk_size      int
	total_chunks    int
	uploaded_chunks int
	pending_parts   []int
	can_resume      bool
	error_msg       string
}

// 获取恢复上传所需的信息
pub fn (cm ChunkManager) get_resume_info(upload_id string) ResumeInfo {
	upload := cm.db.get_multipart_upload(upload_id) or {
		return ResumeInfo{
			upload_id: upload_id
			can_resume: false
			error_msg: 'Upload not found: ${upload_id}'
		}
	}

	// 只有 uploading 状态的上传可以恢复
	if upload.status != 'uploading' {
		return ResumeInfo{
			upload_id: upload_id
			file_uuid: upload.file_uuid
			file_name: upload.file_name
			file_size: upload.file_size
			chunk_size: upload.chunk_size
			total_chunks: upload.total_chunks
			can_resume: false
			error_msg: 'Upload is in ${upload.status} state, cannot resume'
		}
	}

	// 获取进度信息
	progress := cm.get_upload_progress(upload_id) or {
		return ResumeInfo{
			upload_id: upload_id
			file_uuid: upload.file_uuid
			file_name: upload.file_name
			file_size: upload.file_size
			chunk_size: upload.chunk_size
			total_chunks: upload.total_chunks
			can_resume: false
			error_msg: 'Failed to get upload progress: ${err}'
		}
	}

	return ResumeInfo{
		upload_id: upload_id
		file_uuid: upload.file_uuid
		file_name: upload.file_name
		file_size: upload.file_size
		chunk_size: upload.chunk_size
		total_chunks: upload.total_chunks
		uploaded_chunks: progress.uploaded_chunks
		pending_parts: progress.pending_parts
		can_resume: true
		error_msg: ''
	}
}

// 根据文件名查找可恢复的上传
pub fn (cm ChunkManager) find_resumable_upload(file_name string, file_size i64) ?MultipartUpload {
	pending_uploads := cm.db.list_pending_multipart_uploads() or { return none }

	for upload in pending_uploads {
		if upload.file_name == file_name && upload.file_size == file_size {
			return upload
		}
	}

	return none
}

// 检查上传是否可以完成（所有分片都已上传）
pub fn (cm ChunkManager) can_complete(upload_id string) bool {
	progress := cm.get_upload_progress(upload_id) or { return false }
	return progress.pending_parts.len == 0 && progress.status == 'uploading'
}

// 获取上传的详细状态报告
pub struct UploadStatusReport {
pub:
	upload_id         string
	status            string
	file_name         string
	file_size         i64
	total_chunks      int
	uploaded_chunks   int
	pending_chunks    int
	uploaded_bytes    i64
	remaining_bytes   i64
	progress_pct      f64
	estimated_time_ms i64 // 基于平均上传速度估算的剩余时间
	can_complete      bool
	can_resume        bool
}

// 获取详细的上传状态报告
pub fn (cm ChunkManager) get_status_report(upload_id string) !UploadStatusReport {
	progress := cm.get_upload_progress(upload_id)!

	remaining_bytes := progress.file_size - progress.uploaded_bytes
	can_complete := progress.pending_parts.len == 0 && progress.status == 'uploading'
	can_resume := progress.status == 'uploading' && progress.pending_parts.len > 0

	return UploadStatusReport{
		upload_id: upload_id
		status: progress.status
		file_name: progress.file_name
		file_size: progress.file_size
		total_chunks: progress.total_chunks
		uploaded_chunks: progress.uploaded_chunks
		pending_chunks: progress.pending_parts.len
		uploaded_bytes: progress.uploaded_bytes
		remaining_bytes: remaining_bytes
		progress_pct: progress.progress_pct
		estimated_time_ms: 0 // 需要历史数据来估算
		can_complete: can_complete
		can_resume: can_resume
	}
}

// 清理过期的上传（超过指定时间未更新的上传）
pub fn (mut cm ChunkManager) cleanup_stale_uploads(max_age_seconds i64) !int {
	pending_uploads := cm.db.list_pending_multipart_uploads()!
	now := time.now().unix()
	mut cleaned := 0

	for upload in pending_uploads {
		if now - upload.updated_at > max_age_seconds {
			cm.abort_multipart(upload.upload_id) or { continue }
			cleaned++
		}
	}

	return cleaned
}
