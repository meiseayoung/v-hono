module hono

import db.sqlite
import time
import crypto.rand

// 文件信息结构（扩展版本，支持多存储提供者）
pub struct FileInfo {
pub:
	id           int
	file_uuid    string
	file_hash    string
	file_name    string
	file_size    i64
	file_type    string
	storage_type string // 存储类型 (local/s3/oss/cos)
	bucket       string // 存储桶名称
	object_key   string // 对象键（存储路径）
	created_at   i64
	updated_at   i64
	metadata     string // JSON 格式的额外元数据
}

// 分片上传状态
pub struct MultipartUpload {
pub:
	id           int
	upload_id    string
	file_uuid    string
	file_name    string
	file_size    i64
	chunk_size   int
	total_chunks int
	bucket       string
	object_key   string
	content_type string
	status       string // 'uploading', 'completed', 'aborted'
	created_at   i64
	updated_at   i64
}

// 已上传分片记录
pub struct UploadedPart {
pub:
	id          int
	upload_id   string
	part_number int
	etag        string
	size        i64
	uploaded_at i64
}

// 文件列表查询选项
pub struct FileListOptions {
pub:
	bucket       string
	prefix       string
	storage_type string
	limit        int = 100
	offset       int
	order_by     string = 'created_at'
	order_desc   bool   = true
}

// 文件列表查询结果
pub struct FileListResult {
pub:
	files       []FileInfo
	total_count int
	has_more    bool
}


// 数据库管理器
pub struct DatabaseManager {
mut:
	db sqlite.DB
}

// 创建数据库管理器
pub fn new_database_manager(db_path string) !DatabaseManager {
	mut db := sqlite.connect(db_path) or {
		return error('Failed to connect to database: ${err}')
	}

	// 创建文件信息表（扩展版本，支持多存储提供者）
	db.exec('CREATE TABLE IF NOT EXISTS file_info (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_uuid TEXT UNIQUE NOT NULL,
		file_hash TEXT NOT NULL,
		file_name TEXT NOT NULL,
		file_size INTEGER NOT NULL,
		file_type TEXT NOT NULL,
		storage_type TEXT NOT NULL DEFAULT "local",
		bucket TEXT NOT NULL DEFAULT "default",
		object_key TEXT NOT NULL,
		created_at INTEGER NOT NULL,
		updated_at INTEGER NOT NULL,
		metadata TEXT
	);') or { return error('Failed to create file_info table: ${err}') }

	// 创建索引
	db.exec('CREATE INDEX IF NOT EXISTS idx_file_hash ON file_info(file_hash);') or {
		return error('Failed to create idx_file_hash index: ${err}')
	}
	db.exec('CREATE INDEX IF NOT EXISTS idx_file_uuid ON file_info(file_uuid);') or {
		return error('Failed to create idx_file_uuid index: ${err}')
	}
	db.exec('CREATE INDEX IF NOT EXISTS idx_bucket_key ON file_info(bucket, object_key);') or {
		return error('Failed to create idx_bucket_key index: ${err}')
	}
	db.exec('CREATE INDEX IF NOT EXISTS idx_storage_type ON file_info(storage_type);') or {
		return error('Failed to create idx_storage_type index: ${err}')
	}

	// 创建分片上传状态表
	db.exec("CREATE TABLE IF NOT EXISTS multipart_uploads (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		upload_id TEXT UNIQUE NOT NULL,
		file_uuid TEXT NOT NULL,
		file_name TEXT NOT NULL,
		file_size INTEGER NOT NULL,
		chunk_size INTEGER NOT NULL,
		total_chunks INTEGER NOT NULL,
		bucket TEXT NOT NULL,
		object_key TEXT NOT NULL,
		content_type TEXT,
		status TEXT NOT NULL DEFAULT 'uploading',
		created_at INTEGER NOT NULL,
		updated_at INTEGER NOT NULL
	);") or { return error('Failed to create multipart_uploads table: ${err}') }

	// 创建已上传分片记录表
	db.exec('CREATE TABLE IF NOT EXISTS uploaded_parts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		upload_id TEXT NOT NULL,
		part_number INTEGER NOT NULL,
		etag TEXT NOT NULL,
		size INTEGER NOT NULL,
		uploaded_at INTEGER NOT NULL,
		UNIQUE(upload_id, part_number)
	);') or { return error('Failed to create uploaded_parts table: ${err}') }

	db.exec('CREATE INDEX IF NOT EXISTS idx_upload_id ON uploaded_parts(upload_id);') or {
		return error('Failed to create idx_upload_id index: ${err}')
	}

	return DatabaseManager{
		db: db
	}
}

// 生成文件UUID
pub fn generate_file_uuid() string {
	// 生成16字节的随机数据
	random_bytes := rand.bytes(16) or { return '' }

	// 转换为UUID格式 (8-4-4-4-12)
	mut uuid := ''
	for i, b in random_bytes {
		if i == 4 || i == 6 || i == 8 || i == 10 {
			uuid += '-'
		}
		uuid += '${b:02x}'
	}

	return uuid
}

// 生成上传ID (用于数据库记录)
pub fn generate_db_upload_id() string {
	random_bytes := rand.bytes(16) or { return '' }
	mut id := ''
	for b in random_bytes {
		id += '${b:02x}'
	}
	return id
}


// ============ 文件元数据 CRUD 操作 ============

// 插入文件信息
pub fn (mut dm DatabaseManager) insert_file(file FileInfo) !FileInfo {
	now := time.now().unix()
	file_uuid := if file.file_uuid != '' { file.file_uuid } else { generate_file_uuid() }

	dm.db.exec("INSERT INTO file_info (file_uuid, file_hash, file_name, file_size, file_type, storage_type, bucket, object_key, created_at, updated_at, metadata) VALUES ('${file_uuid}', '${file.file_hash}', '${escape_sql(file.file_name)}', ${file.file_size}, '${file.file_type}', '${file.storage_type}', '${file.bucket}', '${escape_sql(file.object_key)}', ${now}, ${now}, '${escape_sql(file.metadata)}')") or {
		return error('Failed to insert file info: ${err}')
	}

	return FileInfo{
		id: 0
		file_uuid: file_uuid
		file_hash: file.file_hash
		file_name: file.file_name
		file_size: file.file_size
		file_type: file.file_type
		storage_type: file.storage_type
		bucket: file.bucket
		object_key: file.object_key
		created_at: now
		updated_at: now
		metadata: file.metadata
	}
}

// 根据UUID获取文件信息
pub fn (dm DatabaseManager) get_file_by_uuid(file_uuid string) !FileInfo {
	rows := dm.db.exec("SELECT id, file_uuid, file_hash, file_name, file_size, file_type, storage_type, bucket, object_key, created_at, updated_at, metadata FROM file_info WHERE file_uuid = '${file_uuid}'") or {
		return error('Failed to query file info: ${err}')
	}

	if rows.len > 0 {
		row := rows[0]
		return FileInfo{
			id: row.vals[0].int()
			file_uuid: row.vals[1]
			file_hash: row.vals[2]
			file_name: row.vals[3]
			file_size: row.vals[4].i64()
			file_type: row.vals[5]
			storage_type: row.vals[6]
			bucket: row.vals[7]
			object_key: row.vals[8]
			created_at: row.vals[9].i64()
			updated_at: row.vals[10].i64()
			metadata: row.vals[11]
		}
	}

	return error('File not found')
}

// 根据hash获取文件信息
pub fn (dm DatabaseManager) get_file_by_hash(file_hash string) !FileInfo {
	rows := dm.db.exec("SELECT id, file_uuid, file_hash, file_name, file_size, file_type, storage_type, bucket, object_key, created_at, updated_at, metadata FROM file_info WHERE file_hash = '${file_hash}'") or {
		return error('Failed to query file info: ${err}')
	}

	if rows.len > 0 {
		row := rows[0]
		return FileInfo{
			id: row.vals[0].int()
			file_uuid: row.vals[1]
			file_hash: row.vals[2]
			file_name: row.vals[3]
			file_size: row.vals[4].i64()
			file_type: row.vals[5]
			storage_type: row.vals[6]
			bucket: row.vals[7]
			object_key: row.vals[8]
			created_at: row.vals[9].i64()
			updated_at: row.vals[10].i64()
			metadata: row.vals[11]
		}
	}

	return error('File not found')
}

// 根据hash获取所有匹配的文件
pub fn (dm DatabaseManager) get_files_by_hash(file_hash string) ![]FileInfo {
	rows := dm.db.exec("SELECT id, file_uuid, file_hash, file_name, file_size, file_type, storage_type, bucket, object_key, created_at, updated_at, metadata FROM file_info WHERE file_hash = '${file_hash}'") or {
		return error('Failed to query files: ${err}')
	}

	mut files := []FileInfo{}
	for row in rows {
		files << FileInfo{
			id: row.vals[0].int()
			file_uuid: row.vals[1]
			file_hash: row.vals[2]
			file_name: row.vals[3]
			file_size: row.vals[4].i64()
			file_type: row.vals[5]
			storage_type: row.vals[6]
			bucket: row.vals[7]
			object_key: row.vals[8]
			created_at: row.vals[9].i64()
			updated_at: row.vals[10].i64()
			metadata: row.vals[11]
		}
	}

	return files
}

// 更新文件信息
pub fn (mut dm DatabaseManager) update_file(file_uuid string, file_name string, file_type string, metadata string) !FileInfo {
	now := time.now().unix()

	dm.db.exec("UPDATE file_info SET file_name = '${escape_sql(file_name)}', file_type = '${file_type}', metadata = '${escape_sql(metadata)}', updated_at = ${now} WHERE file_uuid = '${file_uuid}'") or {
		return error('Failed to update file info: ${err}')
	}

	return dm.get_file_by_uuid(file_uuid)
}

// 删除文件信息
pub fn (mut dm DatabaseManager) delete_file(file_uuid string) ! {
	dm.db.exec("DELETE FROM file_info WHERE file_uuid = '${file_uuid}'") or {
		return error('Failed to delete file info: ${err}')
	}
}

// 检查文件是否存在
pub fn (dm DatabaseManager) file_exists(file_uuid string) bool {
	rows := dm.db.exec("SELECT 1 FROM file_info WHERE file_uuid = '${file_uuid}' LIMIT 1") or {
		return false
	}
	return rows.len > 0
}


// 分页列表查询
pub fn (dm DatabaseManager) list_files(options FileListOptions) !FileListResult {
	mut where_clauses := []string{}
	
	if options.bucket != '' {
		where_clauses << "bucket = '${options.bucket}'"
	}
	if options.prefix != '' {
		where_clauses << "object_key LIKE '${escape_sql(options.prefix)}%'"
	}
	if options.storage_type != '' {
		where_clauses << "storage_type = '${options.storage_type}'"
	}

	where_sql := if where_clauses.len > 0 { 'WHERE ' + where_clauses.join(' AND ') } else { '' }
	order_dir := if options.order_desc { 'DESC' } else { 'ASC' }
	order_sql := 'ORDER BY ${options.order_by} ${order_dir}'

	// 获取总数
	count_rows := dm.db.exec('SELECT COUNT(*) FROM file_info ${where_sql}') or {
		return error('Failed to count files: ${err}')
	}
	total_count := if count_rows.len > 0 { count_rows[0].vals[0].int() } else { 0 }

	// 获取分页数据
	limit := if options.limit > 0 { options.limit } else { 100 }
	rows := dm.db.exec('SELECT id, file_uuid, file_hash, file_name, file_size, file_type, storage_type, bucket, object_key, created_at, updated_at, metadata FROM file_info ${where_sql} ${order_sql} LIMIT ${limit} OFFSET ${options.offset}') or {
		return error('Failed to list files: ${err}')
	}

	mut files := []FileInfo{}
	for row in rows {
		files << FileInfo{
			id: row.vals[0].int()
			file_uuid: row.vals[1]
			file_hash: row.vals[2]
			file_name: row.vals[3]
			file_size: row.vals[4].i64()
			file_type: row.vals[5]
			storage_type: row.vals[6]
			bucket: row.vals[7]
			object_key: row.vals[8]
			created_at: row.vals[9].i64()
			updated_at: row.vals[10].i64()
			metadata: row.vals[11]
		}
	}

	return FileListResult{
		files: files
		total_count: total_count
		has_more: options.offset + files.len < total_count
	}
}

// 获取所有文件
pub fn (dm DatabaseManager) get_all_files() ![]FileInfo {
	result := dm.list_files(FileListOptions{ limit: 10000 })!
	return result.files
}

// ============ 分片上传状态管理 ============

// 创建分片上传记录
pub fn (mut dm DatabaseManager) create_multipart_upload(upload MultipartUpload) !MultipartUpload {
	now := time.now().unix()
	upload_id := if upload.upload_id != '' { upload.upload_id } else { generate_db_upload_id() }
	file_uuid := if upload.file_uuid != '' { upload.file_uuid } else { generate_file_uuid() }

	dm.db.exec("INSERT INTO multipart_uploads (upload_id, file_uuid, file_name, file_size, chunk_size, total_chunks, bucket, object_key, content_type, status, created_at, updated_at) VALUES ('${upload_id}', '${file_uuid}', '${escape_sql(upload.file_name)}', ${upload.file_size}, ${upload.chunk_size}, ${upload.total_chunks}, '${upload.bucket}', '${escape_sql(upload.object_key)}', '${upload.content_type}', 'uploading', ${now}, ${now})") or {
		return error('Failed to create multipart upload: ${err}')
	}

	return MultipartUpload{
		id: 0
		upload_id: upload_id
		file_uuid: file_uuid
		file_name: upload.file_name
		file_size: upload.file_size
		chunk_size: upload.chunk_size
		total_chunks: upload.total_chunks
		bucket: upload.bucket
		object_key: upload.object_key
		content_type: upload.content_type
		status: 'uploading'
		created_at: now
		updated_at: now
	}
}

// 获取分片上传状态
pub fn (dm DatabaseManager) get_multipart_upload(upload_id string) !MultipartUpload {
	rows := dm.db.exec("SELECT id, upload_id, file_uuid, file_name, file_size, chunk_size, total_chunks, bucket, object_key, content_type, status, created_at, updated_at FROM multipart_uploads WHERE upload_id = '${upload_id}'") or {
		return error('Failed to query multipart upload: ${err}')
	}

	if rows.len > 0 {
		row := rows[0]
		return MultipartUpload{
			id: row.vals[0].int()
			upload_id: row.vals[1]
			file_uuid: row.vals[2]
			file_name: row.vals[3]
			file_size: row.vals[4].i64()
			chunk_size: row.vals[5].int()
			total_chunks: row.vals[6].int()
			bucket: row.vals[7]
			object_key: row.vals[8]
			content_type: row.vals[9]
			status: row.vals[10]
			created_at: row.vals[11].i64()
			updated_at: row.vals[12].i64()
		}
	}

	return error('Multipart upload not found')
}

// 更新分片上传状态
pub fn (mut dm DatabaseManager) update_multipart_status(upload_id string, status string) ! {
	now := time.now().unix()
	dm.db.exec("UPDATE multipart_uploads SET status = '${status}', updated_at = ${now} WHERE upload_id = '${upload_id}'") or {
		return error('Failed to update multipart status: ${err}')
	}
}

// 删除分片上传记录
pub fn (mut dm DatabaseManager) delete_multipart_upload(upload_id string) ! {
	// 先删除分片记录
	dm.db.exec("DELETE FROM uploaded_parts WHERE upload_id = '${upload_id}'") or {
		return error('Failed to delete uploaded parts: ${err}')
	}
	// 再删除上传记录
	dm.db.exec("DELETE FROM multipart_uploads WHERE upload_id = '${upload_id}'") or {
		return error('Failed to delete multipart upload: ${err}')
	}
}

// 列出所有进行中的分片上传
pub fn (dm DatabaseManager) list_pending_multipart_uploads() ![]MultipartUpload {
	rows := dm.db.exec("SELECT id, upload_id, file_uuid, file_name, file_size, chunk_size, total_chunks, bucket, object_key, content_type, status, created_at, updated_at FROM multipart_uploads WHERE status = 'uploading' ORDER BY created_at DESC") or {
		return error('Failed to list pending uploads: ${err}')
	}

	mut uploads := []MultipartUpload{}
	for row in rows {
		uploads << MultipartUpload{
			id: row.vals[0].int()
			upload_id: row.vals[1]
			file_uuid: row.vals[2]
			file_name: row.vals[3]
			file_size: row.vals[4].i64()
			chunk_size: row.vals[5].int()
			total_chunks: row.vals[6].int()
			bucket: row.vals[7]
			object_key: row.vals[8]
			content_type: row.vals[9]
			status: row.vals[10]
			created_at: row.vals[11].i64()
			updated_at: row.vals[12].i64()
		}
	}

	return uploads
}


// ============ 分片记录管理 ============

// 记录已上传的分片
pub fn (mut dm DatabaseManager) record_uploaded_part(upload_id string, part_number int, etag string, size i64) !UploadedPart {
	now := time.now().unix()

	// 使用 INSERT OR REPLACE 来处理重复上传的分片
	dm.db.exec("INSERT OR REPLACE INTO uploaded_parts (upload_id, part_number, etag, size, uploaded_at) VALUES ('${upload_id}', ${part_number}, '${etag}', ${size}, ${now})") or {
		return error('Failed to record uploaded part: ${err}')
	}

	// 更新分片上传的更新时间
	dm.db.exec("UPDATE multipart_uploads SET updated_at = ${now} WHERE upload_id = '${upload_id}'") or {}

	return UploadedPart{
		id: 0
		upload_id: upload_id
		part_number: part_number
		etag: etag
		size: size
		uploaded_at: now
	}
}

// 获取已上传的分片列表
pub fn (dm DatabaseManager) get_uploaded_parts(upload_id string) ![]UploadedPart {
	rows := dm.db.exec("SELECT id, upload_id, part_number, etag, size, uploaded_at FROM uploaded_parts WHERE upload_id = '${upload_id}' ORDER BY part_number ASC") or {
		return error('Failed to get uploaded parts: ${err}')
	}

	mut parts := []UploadedPart{}
	for row in rows {
		parts << UploadedPart{
			id: row.vals[0].int()
			upload_id: row.vals[1]
			part_number: row.vals[2].int()
			etag: row.vals[3]
			size: row.vals[4].i64()
			uploaded_at: row.vals[5].i64()
		}
	}

	return parts
}

// 获取已上传分片数量
pub fn (dm DatabaseManager) get_uploaded_parts_count(upload_id string) int {
	rows := dm.db.exec("SELECT COUNT(*) FROM uploaded_parts WHERE upload_id = '${upload_id}'") or {
		return 0
	}
	if rows.len > 0 {
		return rows[0].vals[0].int()
	}
	return 0
}

// 检查分片是否已上传
pub fn (dm DatabaseManager) is_part_uploaded(upload_id string, part_number int) bool {
	rows := dm.db.exec("SELECT 1 FROM uploaded_parts WHERE upload_id = '${upload_id}' AND part_number = ${part_number} LIMIT 1") or {
		return false
	}
	return rows.len > 0
}

// 获取上传进度（已上传分片数 / 总分片数）
pub fn (dm DatabaseManager) get_upload_progress(upload_id string) !(int, int) {
	upload := dm.get_multipart_upload(upload_id)!
	uploaded_count := dm.get_uploaded_parts_count(upload_id)
	return uploaded_count, upload.total_chunks
}

// 删除分片记录
pub fn (mut dm DatabaseManager) delete_uploaded_part(upload_id string, part_number int) ! {
	dm.db.exec("DELETE FROM uploaded_parts WHERE upload_id = '${upload_id}' AND part_number = ${part_number}") or {
		return error('Failed to delete uploaded part: ${err}')
	}
}

// ============ 辅助函数 ============

// SQL 字符串转义
fn escape_sql(s string) string {
	return s.replace("'", "''")
}

// 关闭数据库连接
pub fn (mut dm DatabaseManager) close() {
	dm.db.close() or {}
}

// ============ 向后兼容的接口 ============

// 插入或更新文件（兼容旧接口，支持扩展参数）
pub fn (mut dm DatabaseManager) insert_or_update_file(file_hash string, file_name string, file_size i64, file_type string, storage_type string, bucket string, object_key string) !FileInfo {
	// 检查是否已存在相同的 file_hash 和 bucket/object_key
	existing := dm.get_file_by_hash(file_hash) or { FileInfo{} }

	if existing.file_uuid != '' && existing.bucket == bucket && existing.object_key == object_key {
		// 更新现有记录
		return dm.update_file(existing.file_uuid, file_name, file_type, existing.metadata)
	}

	// 创建新记录
	return dm.insert_file(FileInfo{
		file_hash: file_hash
		file_name: file_name
		file_size: file_size
		file_type: file_type
		storage_type: storage_type
		bucket: bucket
		object_key: object_key
		metadata: ''
	})
}

// 简化版插入或更新文件（完全向后兼容旧接口）
pub fn (mut dm DatabaseManager) insert_or_update_file_simple(file_hash string, file_name string, file_size i64, file_type string) !FileInfo {
	return dm.insert_or_update_file(file_hash, file_name, file_size, file_type, 'local', 'default', file_name)
}

// 根据 bucket 和 object_key 获取文件
pub fn (dm DatabaseManager) get_file_by_key(bucket string, object_key string) !FileInfo {
	rows := dm.db.exec("SELECT id, file_uuid, file_hash, file_name, file_size, file_type, storage_type, bucket, object_key, created_at, updated_at, metadata FROM file_info WHERE bucket = '${bucket}' AND object_key = '${escape_sql(object_key)}'") or {
		return error('Failed to query file info: ${err}')
	}

	if rows.len > 0 {
		row := rows[0]
		return FileInfo{
			id: row.vals[0].int()
			file_uuid: row.vals[1]
			file_hash: row.vals[2]
			file_name: row.vals[3]
			file_size: row.vals[4].i64()
			file_type: row.vals[5]
			storage_type: row.vals[6]
			bucket: row.vals[7]
			object_key: row.vals[8]
			created_at: row.vals[9].i64()
			updated_at: row.vals[10].i64()
			metadata: row.vals[11]
		}
	}

	return error('File not found')
}
