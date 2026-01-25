module main

import rand
import time
import os
import db.sqlite
import crypto.md5
import crypto.rand as crand

// ============================================================================
// Property 5: Multipart Upload Completeness
// Feature: v-hono-upload-integration, Property 5: Multipart Upload Completeness
// Validates: Requirements 7.1, 7.3, 7.5
//
// *For any* file split into chunks, initiating a multipart upload, uploading
// all chunks, and completing the upload should result in a file identical
// to the original when downloaded.
// ============================================================================

const test_iterations = 100
const test_base_path = './test_multipart_completeness'
const test_db_path = './test_multipart_completeness/test.db'
const test_bucket = 'test-bucket'

// ============================================================================
// Type definitions (copied from storage modules for standalone testing)
// ============================================================================

struct StorageResult {
pub:
	success    bool
	object_key string
	etag       string
	size       i64
	error_msg  string
}

struct ObjectInfo {
pub:
	key           string
	size          i64
	etag          string
	content_type  string
	last_modified i64
	metadata      map[string]string
}

struct PartInfo {
pub:
	part_number int
	etag        string
	size        i64
}

struct LocalStorageConfig {
pub:
	base_path   string = './storage'
	url_prefix  string = '/files'
	create_dirs bool   = true
}

struct FileInfo {
pub:
	id           int
	file_uuid    string
	file_hash    string
	file_name    string
	file_size    i64
	file_type    string
	storage_type string
	bucket       string
	object_key   string
	created_at   i64
	updated_at   i64
	metadata     string
}

struct MultipartUpload {
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
	status       string
	created_at   i64
	updated_at   i64
}

struct UploadedPart {
pub:
	id          int
	upload_id   string
	part_number int
	etag        string
	size        i64
	uploaded_at i64
}


// ============================================================================
// LocalStorage implementation (copied for standalone testing)
// ============================================================================

struct LocalStorage {
	config LocalStorageConfig
mut:
	multipart_uploads map[string]MultipartUploadState
}

struct MultipartUploadState {
mut:
	bucket       string
	key          string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

fn new_local_storage(config LocalStorageConfig) !LocalStorage {
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

fn (s LocalStorage) get_full_path(bucket string, key string) string {
	return os.join_path(s.config.base_path, bucket, key)
}

fn (s LocalStorage) get_bucket_path(bucket string) string {
	return os.join_path(s.config.base_path, bucket)
}

fn calculate_etag(data []u8) string {
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return '"${result}"'
}

fn new_storage_result(object_key string, etag string, size i64) StorageResult {
	return StorageResult{
		success: true
		object_key: object_key
		etag: etag
		size: size
		error_msg: ''
	}
}

fn new_part_info(part_number int, etag string, size i64) PartInfo {
	return PartInfo{
		part_number: part_number
		etag: etag
		size: size
	}
}

fn (mut s LocalStorage) upload(bucket string, key string, data []u8, content_type string) !StorageResult {
	bucket_path := s.get_bucket_path(bucket)
	if s.config.create_dirs {
		os.mkdir_all(bucket_path) or {
			return error('Failed to create bucket directory: ${err}')
		}
	}

	full_path := s.get_full_path(bucket, key)
	parent_dir := os.dir(full_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {
			return error('Failed to create parent directory: ${err}')
		}
	}

	os.write_file_array(full_path, data) or {
		return error('Failed to write file: ${err}')
	}

	etag := calculate_etag(data)
	return new_storage_result(key, etag, i64(data.len))
}

fn (s LocalStorage) download(bucket string, key string) ![]u8 {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error('Object not found: ${bucket}/${key}')
	}

	data := os.read_bytes(full_path) or {
		return error('Failed to read file: ${err}')
	}

	return data
}

fn (s LocalStorage) delete(bucket string, key string) ! {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return
	}

	os.rm(full_path) or {
		return error('Failed to delete file: ${err}')
	}
}

fn (s LocalStorage) exists(bucket string, key string) !bool {
	full_path := s.get_full_path(bucket, key)
	return os.exists(full_path) && os.is_file(full_path)
}

fn (s LocalStorage) create_bucket(bucket string) ! {
	bucket_path := s.get_bucket_path(bucket)

	if os.exists(bucket_path) {
		return
	}

	os.mkdir_all(bucket_path) or {
		return error('Failed to create bucket: ${err}')
	}
}

fn (mut s LocalStorage) init_multipart(bucket string, key string, content_type string) !string {
	upload_id := generate_upload_id()
	s.multipart_uploads[upload_id] = MultipartUploadState{
		bucket: bucket
		key: key
		content_type: content_type
		parts: map[int]PartInfo{}
		created_at: time.now().unix()
	}
	return upload_id
}

fn (mut s LocalStorage) upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string {
	if upload_id !in s.multipart_uploads {
		return error('Upload not found: ${upload_id}')
	}

	etag := calculate_etag(data)

	// Store part data in temp file
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	os.mkdir_all(temp_dir) or {
		return error('Failed to create temp directory: ${err}')
	}

	part_path := os.join_path(temp_dir, '${part_number}')
	os.write_file_array(part_path, data) or {
		return error('Failed to write part: ${err}')
	}

	s.multipart_uploads[upload_id].parts[part_number] = new_part_info(part_number, etag, i64(data.len))

	return etag
}

fn (mut s LocalStorage) complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult {
	if upload_id !in s.multipart_uploads {
		return error('Upload not found: ${upload_id}')
	}

	// Merge all parts
	mut all_data := []u8{}
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)

	mut sorted_parts := parts.clone()
	sorted_parts.sort(a.part_number < b.part_number)

	for part in sorted_parts {
		part_path := os.join_path(temp_dir, '${part.part_number}')
		part_data := os.read_bytes(part_path) or {
			return error('Failed to read part ${part.part_number}: ${err}')
		}
		all_data << part_data
	}

	// Write final file
	result := s.upload(bucket, key, all_data, s.multipart_uploads[upload_id].content_type)!

	// Cleanup temp files
	os.rmdir_all(temp_dir) or {}
	s.multipart_uploads.delete(upload_id)

	return result
}

fn (mut s LocalStorage) abort_multipart(bucket string, key string, upload_id string) ! {
	if upload_id !in s.multipart_uploads {
		return
	}

	// Cleanup temp files
	temp_dir := os.join_path(s.config.base_path, '.multipart', upload_id)
	os.rmdir_all(temp_dir) or {}
	s.multipart_uploads.delete(upload_id)
}

fn (s LocalStorage) provider_name() string {
	return 'local'
}


// ============================================================================
// DatabaseManager implementation (copied for standalone testing)
// ============================================================================

struct DatabaseManager {
mut:
	db sqlite.DB
}

fn new_database_manager(db_path string) !DatabaseManager {
	// Ensure directory exists
	parent_dir := os.dir(db_path)
	if parent_dir != '' && parent_dir != '.' {
		os.mkdir_all(parent_dir) or {}
	}

	mut db := sqlite.connect(db_path) or {
		return error('Failed to connect to database: ${err}')
	}

	// Create tables
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

	db.exec('CREATE TABLE IF NOT EXISTS uploaded_parts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		upload_id TEXT NOT NULL,
		part_number INTEGER NOT NULL,
		etag TEXT NOT NULL,
		size INTEGER NOT NULL,
		uploaded_at INTEGER NOT NULL,
		UNIQUE(upload_id, part_number)
	);') or { return error('Failed to create uploaded_parts table: ${err}') }

	db.exec("CREATE TABLE IF NOT EXISTS file_info (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_uuid TEXT UNIQUE NOT NULL,
		file_hash TEXT NOT NULL,
		file_name TEXT NOT NULL,
		file_size INTEGER NOT NULL,
		file_type TEXT NOT NULL,
		storage_type TEXT NOT NULL DEFAULT 'local',
		bucket TEXT NOT NULL DEFAULT 'default',
		object_key TEXT NOT NULL,
		created_at INTEGER NOT NULL,
		updated_at INTEGER NOT NULL,
		metadata TEXT
	);") or { return error('Failed to create file_info table: ${err}') }

	return DatabaseManager{
		db: db
	}
}

fn generate_file_uuid() string {
	random_bytes := crand.bytes(16) or { return '' }
	mut uuid := ''
	for i, b in random_bytes {
		if i == 4 || i == 6 || i == 8 || i == 10 {
			uuid += '-'
		}
		uuid += '${b:02x}'
	}
	return uuid
}

fn generate_upload_id() string {
	random_bytes := crand.bytes(16) or { return '' }
	mut id := ''
	for b in random_bytes {
		id += '${b:02x}'
	}
	return id
}

fn escape_sql(s string) string {
	return s.replace("'", "''")
}

fn (mut dm DatabaseManager) create_multipart_upload(upload MultipartUpload) !MultipartUpload {
	now := time.now().unix()
	upload_id := if upload.upload_id != '' { upload.upload_id } else { generate_upload_id() }
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

fn (dm DatabaseManager) get_multipart_upload(upload_id string) !MultipartUpload {
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

fn (mut dm DatabaseManager) update_multipart_status(upload_id string, status string) ! {
	now := time.now().unix()
	dm.db.exec("UPDATE multipart_uploads SET status = '${status}', updated_at = ${now} WHERE upload_id = '${upload_id}'") or {
		return error('Failed to update multipart status: ${err}')
	}
}

fn (mut dm DatabaseManager) delete_multipart_upload(upload_id string) ! {
	dm.db.exec("DELETE FROM uploaded_parts WHERE upload_id = '${upload_id}'") or {
		return error('Failed to delete uploaded parts: ${err}')
	}
	dm.db.exec("DELETE FROM multipart_uploads WHERE upload_id = '${upload_id}'") or {
		return error('Failed to delete multipart upload: ${err}')
	}
}

fn (dm DatabaseManager) list_pending_multipart_uploads() ![]MultipartUpload {
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

fn (mut dm DatabaseManager) record_uploaded_part(upload_id string, part_number int, etag string, size i64) !UploadedPart {
	now := time.now().unix()

	dm.db.exec("INSERT OR REPLACE INTO uploaded_parts (upload_id, part_number, etag, size, uploaded_at) VALUES ('${upload_id}', ${part_number}, '${etag}', ${size}, ${now})") or {
		return error('Failed to record uploaded part: ${err}')
	}

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

fn (dm DatabaseManager) get_uploaded_parts(upload_id string) ![]UploadedPart {
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

fn (dm DatabaseManager) is_part_uploaded(upload_id string, part_number int) bool {
	rows := dm.db.exec("SELECT 1 FROM uploaded_parts WHERE upload_id = '${upload_id}' AND part_number = ${part_number} LIMIT 1") or {
		return false
	}
	return rows.len > 0
}

fn (mut dm DatabaseManager) insert_file(file FileInfo) !FileInfo {
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

fn (mut dm DatabaseManager) close() {
	dm.db.close() or {}
}


// ============================================================================
// ChunkManager implementation (copied for standalone testing)
// ============================================================================

struct ChunkManagerConfig {
pub:
	default_chunk_size int = 5 * 1024 * 1024
	max_chunk_size     int = 100 * 1024 * 1024
	min_chunk_size     int = 1024 * 1024
	max_parts          int = 10000
	retry_count        int = 3
	retry_delay_ms     int = 1000
}

struct UploadProgress {
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

struct InitMultipartParams {
pub:
	bucket       string
	object_key   string
	file_name    string
	file_size    i64
	content_type string
	chunk_size   int
}

struct ChunkUploadResult {
pub:
	upload_id   string
	part_number int
	etag        string
	size        i64
	success     bool
	error_msg   string
}

@[heap]
struct ChunkManager {
mut:
	db       DatabaseManager
	storage  LocalStorage
	config   ChunkManagerConfig
}

fn new_chunk_manager(mut db DatabaseManager, mut storage LocalStorage, config ChunkManagerConfig) ChunkManager {
	return ChunkManager{
		db: db
		storage: storage
		config: config
	}
}

fn (cm ChunkManager) validate_chunk_size(size int) int {
	if size < cm.config.min_chunk_size {
		return cm.config.min_chunk_size
	}
	if size > cm.config.max_chunk_size {
		return cm.config.max_chunk_size
	}
	return size
}

fn (cm ChunkManager) calculate_total_chunks(file_size i64, chunk_size int) int {
	chunks := file_size / i64(chunk_size)
	if file_size % i64(chunk_size) > 0 {
		return int(chunks) + 1
	}
	return int(chunks)
}

fn calculate_chunk_file_hash(upload_id string, file_size i64) string {
	data := '${upload_id}-${file_size}'.bytes()
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return result
}

fn (mut cm ChunkManager) init_multipart(params InitMultipartParams) !MultipartUpload {
	if params.bucket == '' {
		return error('Bucket name is required')
	}
	if params.object_key == '' {
		return error('Object key is required')
	}
	if params.file_size <= 0 {
		return error('File size must be positive')
	}

	chunk_size := if params.chunk_size > 0 {
		cm.validate_chunk_size(params.chunk_size)
	} else {
		cm.config.default_chunk_size
	}

	total_chunks := cm.calculate_total_chunks(params.file_size, chunk_size)
	if total_chunks > cm.config.max_parts {
		return error('File too large: would require ${total_chunks} parts, max is ${cm.config.max_parts}')
	}

	provider_upload_id := cm.storage.init_multipart(params.bucket, params.object_key, params.content_type)!

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

fn (mut cm ChunkManager) upload_part(upload_id string, part_number int, data []u8) !ChunkUploadResult {
	upload := cm.db.get_multipart_upload(upload_id) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Upload not found: ${upload_id}'
		}
	}

	if upload.status != 'uploading' {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Upload is not in uploading state: ${upload.status}'
		}
	}

	if part_number < 1 || part_number > upload.total_chunks {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Invalid part number: ${part_number}, expected 1-${upload.total_chunks}'
		}
	}

	etag := cm.storage.upload_part(upload.bucket, upload.object_key, upload_id, part_number, data) or {
		return ChunkUploadResult{
			upload_id: upload_id
			part_number: part_number
			success: false
			error_msg: 'Failed to upload part: ${err}'
		}
	}

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

fn (mut cm ChunkManager) complete_multipart(upload_id string) !StorageResult {
	upload := cm.db.get_multipart_upload(upload_id)!

	if upload.status != 'uploading' {
		return error('Upload is not in uploading state: ${upload.status}')
	}

	uploaded_parts := cm.db.get_uploaded_parts(upload_id)!

	if uploaded_parts.len != upload.total_chunks {
		return error('Not all parts uploaded: ${uploaded_parts.len}/${upload.total_chunks}')
	}

	mut parts := []PartInfo{}
	for part in uploaded_parts {
		parts << new_part_info(part.part_number, part.etag, part.size)
	}

	parts.sort(a.part_number < b.part_number)

	result := cm.storage.complete_multipart(upload.bucket, upload.object_key, upload_id, parts)!

	cm.db.update_multipart_status(upload_id, 'completed')!

	file_hash := calculate_chunk_file_hash(upload_id, upload.file_size)
	cm.db.insert_file(FileInfo{
		file_uuid: upload.file_uuid
		file_hash: file_hash
		file_name: upload.file_name
		file_size: upload.file_size
		file_type: upload.content_type
		storage_type: cm.storage.provider_name()
		bucket: upload.bucket
		object_key: upload.object_key
		metadata: ''
	}) or {}

	return result
}

fn (mut cm ChunkManager) abort_multipart(upload_id string) ! {
	upload := cm.db.get_multipart_upload(upload_id) or {
		return error('Upload not found: ${upload_id}')
	}

	cm.storage.abort_multipart(upload.bucket, upload.object_key, upload_id) or {}

	cm.db.update_multipart_status(upload_id, 'aborted')!
	cm.db.delete_multipart_upload(upload_id)!
}

fn (cm ChunkManager) get_upload_progress(upload_id string) !UploadProgress {
	upload := cm.db.get_multipart_upload(upload_id)!
	uploaded_parts := cm.db.get_uploaded_parts(upload_id)!

	mut uploaded_bytes := i64(0)
	mut uploaded_part_numbers := map[int]bool{}
	for part in uploaded_parts {
		uploaded_bytes += part.size
		uploaded_part_numbers[part.part_number] = true
	}

	mut pending_parts := []int{}
	for i in 1 .. upload.total_chunks + 1 {
		if i !in uploaded_part_numbers {
			pending_parts << i
		}
	}

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


// ============================================================================
// Test infrastructure
// ============================================================================

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats PropertyTestStats) run_property_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🔬 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== Multipart Upload Completeness 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

fn generate_random_bytes(len int) []u8 {
	mut result := []u8{len: len}
	for i in 0 .. len {
		result[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

fn generate_random_filename() string {
	chars := 'abcdefghijklmnopqrstuvwxyz0123456789'
	len := rand.int_in_range(5, 15) or { 10 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result + '.bin'
}

fn cleanup_test_dir() {
	os.rmdir_all(test_base_path) or {}
}

fn create_test_environment() !(LocalStorage, DatabaseManager) {
	os.mkdir_all(test_base_path) or {
		return error('Failed to create test directory: ${err}')
	}

	storage_config := LocalStorageConfig{
		base_path: test_base_path
		url_prefix: '/files'
		create_dirs: true
	}
	storage := new_local_storage(storage_config)!

	db := new_database_manager(test_db_path)!

	return storage, db
}

fn split_into_chunks(data []u8, chunk_size int) [][]u8 {
	mut chunks := [][]u8{}
	mut offset := 0

	for offset < data.len {
		end := if offset + chunk_size > data.len { data.len } else { offset + chunk_size }
		chunks << data[offset..end]
		offset = end
	}

	return chunks
}


// ============================================================================
// Property 5.1: Basic Multipart Upload Round Trip
// For any random file data split into chunks, the complete multipart upload
// process should result in identical content when downloaded
// ============================================================================
fn test_property_5_1_basic_multipart_roundtrip() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage, mut db := create_test_environment() or {
		println('  Failed to create test environment: ${err}')
		return false
	}
	defer {
		db.close()
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	config := ChunkManagerConfig{
		default_chunk_size: 1024
		min_chunk_size: 256
		max_chunk_size: 10240
		max_parts: 1000
		retry_count: 3
		retry_delay_ms: 100
	}
	mut cm := new_chunk_manager(mut db, mut storage, config)

	for i in 0 .. test_iterations {
		file_size := rand.int_in_range(1024, 10240) or { 2048 }
		original_data := generate_random_bytes(file_size)
		filename := generate_random_filename()
		object_key := 'multipart/${filename}'

		params := InitMultipartParams{
			bucket: test_bucket
			object_key: object_key
			file_name: filename
			file_size: i64(original_data.len)
			content_type: 'application/octet-stream'
			chunk_size: 1024
		}

		upload := cm.init_multipart(params) or {
			println('  Iteration ${i}: Failed to init multipart: ${err}')
			return false
		}

		chunks := split_into_chunks(original_data, upload.chunk_size)

		for part_num, chunk in chunks {
			result := cm.upload_part(upload.upload_id, part_num + 1, chunk) or {
				println('  Iteration ${i}: Failed to upload part ${part_num + 1}: ${err}')
				return false
			}

			if !result.success {
				println('  Iteration ${i}: Part ${part_num + 1} upload failed: ${result.error_msg}')
				return false
			}
		}

		complete_result := cm.complete_multipart(upload.upload_id) or {
			println('  Iteration ${i}: Failed to complete multipart: ${err}')
			return false
		}

		if !complete_result.success {
			println('  Iteration ${i}: Complete returned failure: ${complete_result.error_msg}')
			return false
		}

		downloaded := storage.download(test_bucket, object_key) or {
			println('  Iteration ${i}: Failed to download: ${err}')
			return false
		}

		if original_data != downloaded {
			println('  Iteration ${i}: Content mismatch! Original: ${original_data.len} bytes, Downloaded: ${downloaded.len} bytes')
			return false
		}

		storage.delete(test_bucket, object_key) or {}
	}

	return true
}

// ============================================================================
// Property 5.2: Chunk Count Consistency
// For any file, the number of chunks calculated should match the actual
// number of chunks needed to upload the complete file
// ============================================================================
fn test_property_5_2_chunk_count_consistency() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage, mut db := create_test_environment() or {
		println('  Failed to create test environment: ${err}')
		return false
	}
	defer {
		db.close()
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	config := ChunkManagerConfig{
		default_chunk_size: 1024
		min_chunk_size: 256
		max_chunk_size: 10240
		max_parts: 1000
		retry_count: 3
		retry_delay_ms: 100
	}
	mut cm := new_chunk_manager(mut db, mut storage, config)

	for i in 0 .. test_iterations {
		file_size := rand.int_in_range(100, 10000) or { 1000 }
		chunk_size := rand.int_in_range(256, 2048) or { 512 }

		original_data := generate_random_bytes(file_size)
		filename := generate_random_filename()
		object_key := 'chunks/${filename}'

		params := InitMultipartParams{
			bucket: test_bucket
			object_key: object_key
			file_name: filename
			file_size: i64(original_data.len)
			content_type: 'application/octet-stream'
			chunk_size: chunk_size
		}

		upload := cm.init_multipart(params) or {
			println('  Iteration ${i}: Failed to init multipart: ${err}')
			return false
		}

		expected_chunks := (file_size + upload.chunk_size - 1) / upload.chunk_size

		if upload.total_chunks != expected_chunks {
			println('  Iteration ${i}: Chunk count mismatch! Expected: ${expected_chunks}, Got: ${upload.total_chunks}')
			println('    File size: ${file_size}, Chunk size: ${upload.chunk_size}')
			cm.abort_multipart(upload.upload_id) or {}
			return false
		}

		cm.abort_multipart(upload.upload_id) or {}
	}

	return true
}


// ============================================================================
// Property 5.3: Partial Upload Abort
// For any partially uploaded file, aborting should clean up all chunks
// and the file should not exist
// ============================================================================
fn test_property_5_3_partial_upload_abort() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage, mut db := create_test_environment() or {
		println('  Failed to create test environment: ${err}')
		return false
	}
	defer {
		db.close()
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	config := ChunkManagerConfig{
		default_chunk_size: 1024
		min_chunk_size: 256
		max_chunk_size: 10240
		max_parts: 1000
		retry_count: 3
		retry_delay_ms: 100
	}
	mut cm := new_chunk_manager(mut db, mut storage, config)

	for i in 0 .. test_iterations {
		file_size := rand.int_in_range(2048, 8192) or { 4096 }
		original_data := generate_random_bytes(file_size)
		filename := generate_random_filename()
		object_key := 'abort/${filename}'

		params := InitMultipartParams{
			bucket: test_bucket
			object_key: object_key
			file_name: filename
			file_size: i64(original_data.len)
			content_type: 'application/octet-stream'
			chunk_size: 1024
		}

		upload := cm.init_multipart(params) or {
			println('  Iteration ${i}: Failed to init multipart: ${err}')
			return false
		}

		chunks := split_into_chunks(original_data, upload.chunk_size)
		chunks_to_upload := rand.int_in_range(1, chunks.len) or { 1 }

		for j in 0 .. chunks_to_upload {
			cm.upload_part(upload.upload_id, j + 1, chunks[j]) or {}
		}

		cm.abort_multipart(upload.upload_id) or {
			println('  Iteration ${i}: Failed to abort: ${err}')
			return false
		}

		exists := storage.exists(test_bucket, object_key) or { false }
		if exists {
			println('  Iteration ${i}: File should not exist after abort')
			return false
		}

		_ := cm.get_upload_progress(upload.upload_id) or {
			continue
		}
		println('  Iteration ${i}: Upload record should be deleted after abort')
		return false
	}

	return true
}

// ============================================================================
// Property 5.4: Size Consistency
// For any completed multipart upload, the final file size should match
// the sum of all chunk sizes
// ============================================================================
fn test_property_5_4_size_consistency() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage, mut db := create_test_environment() or {
		println('  Failed to create test environment: ${err}')
		return false
	}
	defer {
		db.close()
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	config := ChunkManagerConfig{
		default_chunk_size: 1024
		min_chunk_size: 256
		max_chunk_size: 10240
		max_parts: 1000
		retry_count: 3
		retry_delay_ms: 100
	}
	mut cm := new_chunk_manager(mut db, mut storage, config)

	for i in 0 .. test_iterations {
		file_size := rand.int_in_range(1024, 8192) or { 2048 }
		original_data := generate_random_bytes(file_size)
		filename := generate_random_filename()
		object_key := 'size/${filename}'

		params := InitMultipartParams{
			bucket: test_bucket
			object_key: object_key
			file_name: filename
			file_size: i64(original_data.len)
			content_type: 'application/octet-stream'
			chunk_size: 1024
		}

		upload := cm.init_multipart(params) or {
			println('  Iteration ${i}: Failed to init multipart: ${err}')
			return false
		}

		chunks := split_into_chunks(original_data, upload.chunk_size)
		mut total_uploaded := i64(0)

		for part_num, chunk in chunks {
			result := cm.upload_part(upload.upload_id, part_num + 1, chunk) or {
				println('  Iteration ${i}: Failed to upload part: ${err}')
				cm.abort_multipart(upload.upload_id) or {}
				return false
			}
			total_uploaded += result.size
		}

		if total_uploaded != i64(original_data.len) {
			println('  Iteration ${i}: Total uploaded size mismatch! Expected: ${original_data.len}, Got: ${total_uploaded}')
			cm.abort_multipart(upload.upload_id) or {}
			return false
		}

		complete_result := cm.complete_multipart(upload.upload_id) or {
			println('  Iteration ${i}: Failed to complete: ${err}')
			return false
		}

		if complete_result.size != i64(original_data.len) {
			println('  Iteration ${i}: Final size mismatch! Expected: ${original_data.len}, Got: ${complete_result.size}')
			return false
		}

		storage.delete(test_bucket, object_key) or {}
	}

	return true
}

// ============================================================================
// Property 5.5: Out of Order Upload
// For any file, uploading chunks in random order should still result in
// correct file content after completion
// ============================================================================
fn test_property_5_5_out_of_order_upload() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage, mut db := create_test_environment() or {
		println('  Failed to create test environment: ${err}')
		return false
	}
	defer {
		db.close()
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	config := ChunkManagerConfig{
		default_chunk_size: 512
		min_chunk_size: 256
		max_chunk_size: 10240
		max_parts: 1000
		retry_count: 3
		retry_delay_ms: 100
	}
	mut cm := new_chunk_manager(mut db, mut storage, config)

	for i in 0 .. test_iterations {
		file_size := rand.int_in_range(2048, 6144) or { 3072 }
		original_data := generate_random_bytes(file_size)
		filename := generate_random_filename()
		object_key := 'outoforder/${filename}'

		params := InitMultipartParams{
			bucket: test_bucket
			object_key: object_key
			file_name: filename
			file_size: i64(original_data.len)
			content_type: 'application/octet-stream'
			chunk_size: 512
		}

		upload := cm.init_multipart(params) or {
			println('  Iteration ${i}: Failed to init multipart: ${err}')
			return false
		}

		chunks := split_into_chunks(original_data, upload.chunk_size)

		mut order := []int{}
		for j in 0 .. chunks.len {
			order << j
		}
		for j := chunks.len - 1; j > 0; j-- {
			k := rand.int_in_range(0, j + 1) or { 0 }
			tmp := order[j]
			order[j] = order[k]
			order[k] = tmp
		}

		for idx in order {
			result := cm.upload_part(upload.upload_id, idx + 1, chunks[idx]) or {
				println('  Iteration ${i}: Failed to upload part ${idx + 1}: ${err}')
				cm.abort_multipart(upload.upload_id) or {}
				return false
			}

			if !result.success {
				println('  Iteration ${i}: Part ${idx + 1} failed: ${result.error_msg}')
				cm.abort_multipart(upload.upload_id) or {}
				return false
			}
		}

		cm.complete_multipart(upload.upload_id) or {
			println('  Iteration ${i}: Failed to complete: ${err}')
			return false
		}

		downloaded := storage.download(test_bucket, object_key) or {
			println('  Iteration ${i}: Failed to download: ${err}')
			return false
		}

		if original_data != downloaded {
			println('  Iteration ${i}: Content mismatch after out-of-order upload!')
			return false
		}

		storage.delete(test_bucket, object_key) or {}
	}

	return true
}


// ============================================================================
// Main function
// ============================================================================

fn main() {
	println('🚀 开始 Multipart Upload Completeness 属性测试...')
	println('Feature: v-hono-upload-integration, Property 5: Multipart Upload Completeness')
	println('Validates: Requirements 7.1, 7.3, 7.5')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(12345)])

	mut stats := PropertyTestStats{}

	stats.run_property_test('Property 5.1: Basic Multipart Upload Round Trip', test_property_5_1_basic_multipart_roundtrip)
	stats.run_property_test('Property 5.2: Chunk Count Consistency', test_property_5_2_chunk_count_consistency)
	stats.run_property_test('Property 5.3: Partial Upload Abort', test_property_5_3_partial_upload_abort)
	stats.run_property_test('Property 5.4: Size Consistency', test_property_5_4_size_consistency)
	stats.run_property_test('Property 5.5: Out of Order Upload', test_property_5_5_out_of_order_upload)

	stats.print_summary()

	cleanup_test_dir()

	if stats.failed_tests > 0 {
		exit(1)
	}
}
