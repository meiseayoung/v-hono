module main

import rand
import time
import os
import db.sqlite
import crypto.rand as crand

// ============================================================================
// Property 2: Metadata Round Trip
// Feature: v-hono-upload-integration, Property 2: Metadata Round Trip
// Validates: Requirements 1.5, 8.1, 8.2
//
// *For any* file with metadata, storing the file and then retrieving its metadata
// should return all original metadata fields (uuid, hash, name, size, type, timestamps)
// unchanged.
// ============================================================================

const test_iterations = 100
const test_db_path = './test_metadata_roundtrip.db'

// ============================================================================
// Type definitions (copied from database.v for standalone testing)
// ============================================================================

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

struct FileListOptions {
pub:
	bucket       string
	prefix       string
	storage_type string
	limit        int = 100
	offset       int
	order_by     string = 'created_at'
	order_desc   bool   = true
}

struct FileListResult {
pub:
	files       []FileInfo
	total_count int
	has_more    bool
}

// 数据库管理器
struct DatabaseManager {
mut:
	db sqlite.DB
}

// 创建数据库管理器
fn new_database_manager(db_path string) !DatabaseManager {
	mut db := sqlite.connect(db_path) or {
		return error('Failed to connect to database: ${err}')
	}

	// 创建文件信息表
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

	return DatabaseManager{
		db: db
	}
}

// 生成文件UUID
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

// SQL 字符串转义
fn escape_sql(s string) string {
	return s.replace("'", "''")
}

// 插入文件信息
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

// 根据UUID获取文件信息
fn (dm DatabaseManager) get_file_by_uuid(file_uuid string) !FileInfo {
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
fn (dm DatabaseManager) get_file_by_hash(file_hash string) !FileInfo {
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

// 更新文件信息
fn (mut dm DatabaseManager) update_file(file_uuid string, file_name string, file_type string, metadata string) !FileInfo {
	now := time.now().unix()

	dm.db.exec("UPDATE file_info SET file_name = '${escape_sql(file_name)}', file_type = '${file_type}', metadata = '${escape_sql(metadata)}', updated_at = ${now} WHERE file_uuid = '${file_uuid}'") or {
		return error('Failed to update file info: ${err}')
	}

	return dm.get_file_by_uuid(file_uuid)
}

// 删除文件信息
fn (mut dm DatabaseManager) delete_file(file_uuid string) ! {
	dm.db.exec("DELETE FROM file_info WHERE file_uuid = '${file_uuid}'") or {
		return error('Failed to delete file info: ${err}')
	}
}

// 检查文件是否存在
fn (dm DatabaseManager) file_exists(file_uuid string) bool {
	rows := dm.db.exec("SELECT 1 FROM file_info WHERE file_uuid = '${file_uuid}' LIMIT 1") or {
		return false
	}
	return rows.len > 0
}

// 根据 bucket 和 object_key 获取文件
fn (dm DatabaseManager) get_file_by_key(bucket string, object_key string) !FileInfo {
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

// 关闭数据库连接
fn (mut dm DatabaseManager) close() {
	dm.db.close() or {}
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
	println('\n=== Metadata Round Trip 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

// 生成随机字符串
fn generate_random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	len := rand.int_in_range(min_len, max_len) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	return result
}

// 生成随机文件名
fn generate_random_filename() string {
	name := generate_random_string(5, 20)
	extensions := ['.txt', '.bin', '.dat', '.json', '.xml', '.png', '.jpg']
	ext_idx := rand.int_in_range(0, extensions.len) or { 0 }
	return name + extensions[ext_idx]
}

// 生成随机 hash (模拟 MD5)
fn generate_random_hash() string {
	mut hash := ''
	for _ in 0 .. 32 {
		idx := rand.int_in_range(0, 16) or { 0 }
		hash += '0123456789abcdef'[idx].ascii_str()
	}
	return hash
}

// 生成随机 content_type
fn generate_random_content_type() string {
	types := [
		'text/plain',
		'application/octet-stream',
		'application/json',
		'image/png',
		'image/jpeg',
		'application/xml',
		'text/html',
	]
	idx := rand.int_in_range(0, types.len) or { 0 }
	return types[idx]
}

// 生成随机存储类型
fn generate_random_storage_type() string {
	types := ['local', 's3', 'aliyun_oss', 'tencent_cos']
	idx := rand.int_in_range(0, types.len) or { 0 }
	return types[idx]
}

// 生成随机 bucket 名称
fn generate_random_bucket() string {
	return 'bucket-' + generate_random_string(5, 10)
}

// 生成随机 object key
fn generate_random_object_key() string {
	depth := rand.int_in_range(0, 4) or { 1 }
	mut parts := []string{}
	for _ in 0 .. depth {
		parts << generate_random_string(3, 10)
	}
	parts << generate_random_filename()
	return parts.join('/')
}

// 生成随机文件大小
fn generate_random_file_size() i64 {
	return rand.i64_in_range(0, 10_000_000) or { 1000 }
}

// 生成随机 JSON 元数据
fn generate_random_metadata() string {
	key := generate_random_string(3, 10)
	value := generate_random_string(5, 20)
	return '{"${key}": "${value}"}'
}

// 清理测试数据库
fn cleanup_test_db() {
	os.rm(test_db_path) or {}
}

// 创建测试数据库管理器
fn create_test_db() !DatabaseManager {
	return new_database_manager(test_db_path)
}


// ============================================================================
// Property 2.1: Basic Metadata Round Trip
// For any file metadata, inserting and retrieving by UUID should return identical fields
// ============================================================================
fn test_property_2_1_basic_metadata_roundtrip() bool {
	cleanup_test_db()
	defer {
		cleanup_test_db()
	}

	mut db := create_test_db() or {
		println('  Failed to create database: ${err}')
		return false
	}
	defer {
		db.close()
	}

	for i in 0 .. test_iterations {
		// Generate random file info
		file_hash := generate_random_hash()
		file_name := generate_random_filename()
		file_size := generate_random_file_size()
		file_type := generate_random_content_type()
		storage_type := generate_random_storage_type()
		bucket := generate_random_bucket()
		object_key := generate_random_object_key()
		metadata := generate_random_metadata()

		original := FileInfo{
			file_hash: file_hash
			file_name: file_name
			file_size: file_size
			file_type: file_type
			storage_type: storage_type
			bucket: bucket
			object_key: object_key
			metadata: metadata
		}

		// Insert
		inserted := db.insert_file(original) or {
			println('  Iteration ${i}: Insert failed: ${err}')
			return false
		}

		// Retrieve by UUID
		retrieved := db.get_file_by_uuid(inserted.file_uuid) or {
			println('  Iteration ${i}: Get by UUID failed: ${err}')
			return false
		}

		// Verify all fields match
		if retrieved.file_uuid != inserted.file_uuid {
			println('  Iteration ${i}: UUID mismatch: ${retrieved.file_uuid} vs ${inserted.file_uuid}')
			return false
		}
		if retrieved.file_hash != file_hash {
			println('  Iteration ${i}: Hash mismatch: ${retrieved.file_hash} vs ${file_hash}')
			return false
		}
		if retrieved.file_name != file_name {
			println('  Iteration ${i}: Name mismatch: ${retrieved.file_name} vs ${file_name}')
			return false
		}
		if retrieved.file_size != file_size {
			println('  Iteration ${i}: Size mismatch: ${retrieved.file_size} vs ${file_size}')
			return false
		}
		if retrieved.file_type != file_type {
			println('  Iteration ${i}: Type mismatch: ${retrieved.file_type} vs ${file_type}')
			return false
		}
		if retrieved.storage_type != storage_type {
			println('  Iteration ${i}: Storage type mismatch: ${retrieved.storage_type} vs ${storage_type}')
			return false
		}
		if retrieved.bucket != bucket {
			println('  Iteration ${i}: Bucket mismatch: ${retrieved.bucket} vs ${bucket}')
			return false
		}
		if retrieved.object_key != object_key {
			println('  Iteration ${i}: Object key mismatch: ${retrieved.object_key} vs ${object_key}')
			return false
		}
		if retrieved.metadata != metadata {
			println('  Iteration ${i}: Metadata mismatch: ${retrieved.metadata} vs ${metadata}')
			return false
		}

		// Verify timestamps are set
		if retrieved.created_at <= 0 {
			println('  Iteration ${i}: created_at not set')
			return false
		}
		if retrieved.updated_at <= 0 {
			println('  Iteration ${i}: updated_at not set')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 2.2: Hash Query Round Trip
// For any file metadata, inserting and retrieving by hash should return the file
// ============================================================================
fn test_property_2_2_hash_query_roundtrip() bool {
	cleanup_test_db()
	defer {
		cleanup_test_db()
	}

	mut db := create_test_db() or {
		println('  Failed to create database: ${err}')
		return false
	}
	defer {
		db.close()
	}

	for i in 0 .. test_iterations {
		// Generate random file info
		file_hash := generate_random_hash()
		file_name := generate_random_filename()
		file_size := generate_random_file_size()
		file_type := generate_random_content_type()
		storage_type := generate_random_storage_type()
		bucket := generate_random_bucket()
		object_key := generate_random_object_key()

		original := FileInfo{
			file_hash: file_hash
			file_name: file_name
			file_size: file_size
			file_type: file_type
			storage_type: storage_type
			bucket: bucket
			object_key: object_key
			metadata: ''
		}

		// Insert
		inserted := db.insert_file(original) or {
			println('  Iteration ${i}: Insert failed: ${err}')
			return false
		}

		// Retrieve by hash
		retrieved := db.get_file_by_hash(file_hash) or {
			println('  Iteration ${i}: Get by hash failed: ${err}')
			return false
		}

		// Verify UUID matches
		if retrieved.file_uuid != inserted.file_uuid {
			println('  Iteration ${i}: UUID mismatch when querying by hash')
			return false
		}

		// Verify hash matches
		if retrieved.file_hash != file_hash {
			println('  Iteration ${i}: Hash mismatch: ${retrieved.file_hash} vs ${file_hash}')
			return false
		}
	}

	return true
}


// ============================================================================
// Property 2.3: Update Preserves Immutable Fields
// For any file, updating metadata should preserve immutable fields (uuid, hash, size, timestamps)
// ============================================================================
fn test_property_2_3_update_preserves_immutable_fields() bool {
	cleanup_test_db()
	defer {
		cleanup_test_db()
	}

	mut db := create_test_db() or {
		println('  Failed to create database: ${err}')
		return false
	}
	defer {
		db.close()
	}

	for i in 0 .. test_iterations {
		// Generate and insert original file info
		file_hash := generate_random_hash()
		file_name := generate_random_filename()
		file_size := generate_random_file_size()
		file_type := generate_random_content_type()
		storage_type := generate_random_storage_type()
		bucket := generate_random_bucket()
		object_key := generate_random_object_key()
		metadata := generate_random_metadata()

		original := FileInfo{
			file_hash: file_hash
			file_name: file_name
			file_size: file_size
			file_type: file_type
			storage_type: storage_type
			bucket: bucket
			object_key: object_key
			metadata: metadata
		}

		inserted := db.insert_file(original) or {
			println('  Iteration ${i}: Insert failed: ${err}')
			return false
		}

		// Generate new values for mutable fields
		new_file_name := generate_random_filename()
		new_file_type := generate_random_content_type()
		new_metadata := generate_random_metadata()

		// Update
		updated := db.update_file(inserted.file_uuid, new_file_name, new_file_type, new_metadata) or {
			println('  Iteration ${i}: Update failed: ${err}')
			return false
		}

		// Verify immutable fields are preserved
		if updated.file_uuid != inserted.file_uuid {
			println('  Iteration ${i}: UUID changed after update')
			return false
		}
		if updated.file_hash != file_hash {
			println('  Iteration ${i}: Hash changed after update')
			return false
		}
		if updated.file_size != file_size {
			println('  Iteration ${i}: Size changed after update')
			return false
		}
		if updated.storage_type != storage_type {
			println('  Iteration ${i}: Storage type changed after update')
			return false
		}
		if updated.bucket != bucket {
			println('  Iteration ${i}: Bucket changed after update')
			return false
		}
		if updated.object_key != object_key {
			println('  Iteration ${i}: Object key changed after update')
			return false
		}
		if updated.created_at != inserted.created_at {
			println('  Iteration ${i}: created_at changed after update')
			return false
		}

		// Verify mutable fields are updated
		if updated.file_name != new_file_name {
			println('  Iteration ${i}: Name not updated: ${updated.file_name} vs ${new_file_name}')
			return false
		}
		if updated.file_type != new_file_type {
			println('  Iteration ${i}: Type not updated: ${updated.file_type} vs ${new_file_type}')
			return false
		}
		if updated.metadata != new_metadata {
			println('  Iteration ${i}: Metadata not updated: ${updated.metadata} vs ${new_metadata}')
			return false
		}

		// Verify updated_at is changed
		if updated.updated_at < inserted.updated_at {
			println('  Iteration ${i}: updated_at not updated')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 2.4: Delete Removes File Metadata
// For any file, deleting should make it unretrievable
// ============================================================================
fn test_property_2_4_delete_removes_file() bool {
	cleanup_test_db()
	defer {
		cleanup_test_db()
	}

	mut db := create_test_db() or {
		println('  Failed to create database: ${err}')
		return false
	}
	defer {
		db.close()
	}

	for i in 0 .. test_iterations {
		// Generate and insert file info
		original := FileInfo{
			file_hash: generate_random_hash()
			file_name: generate_random_filename()
			file_size: generate_random_file_size()
			file_type: generate_random_content_type()
			storage_type: generate_random_storage_type()
			bucket: generate_random_bucket()
			object_key: generate_random_object_key()
			metadata: ''
		}

		inserted := db.insert_file(original) or {
			println('  Iteration ${i}: Insert failed: ${err}')
			return false
		}

		// Verify file exists
		if !db.file_exists(inserted.file_uuid) {
			println('  Iteration ${i}: File should exist after insert')
			return false
		}

		// Delete
		db.delete_file(inserted.file_uuid) or {
			println('  Iteration ${i}: Delete failed: ${err}')
			return false
		}

		// Verify file no longer exists
		if db.file_exists(inserted.file_uuid) {
			println('  Iteration ${i}: File should not exist after delete')
			return false
		}

		// Verify get_file_by_uuid returns error
		_ := db.get_file_by_uuid(inserted.file_uuid) or {
			// Expected error
			continue
		}
		println('  Iteration ${i}: get_file_by_uuid should return error after delete')
		return false
	}

	return true
}

// ============================================================================
// Property 2.5: Bucket and Key Query Round Trip
// For any file, querying by bucket and object_key should return the correct file
// ============================================================================
fn test_property_2_5_bucket_key_query_roundtrip() bool {
	cleanup_test_db()
	defer {
		cleanup_test_db()
	}

	mut db := create_test_db() or {
		println('  Failed to create database: ${err}')
		return false
	}
	defer {
		db.close()
	}

	for i in 0 .. test_iterations {
		// Generate random file info
		file_hash := generate_random_hash()
		file_name := generate_random_filename()
		file_size := generate_random_file_size()
		file_type := generate_random_content_type()
		storage_type := generate_random_storage_type()
		bucket := generate_random_bucket()
		object_key := generate_random_object_key()

		original := FileInfo{
			file_hash: file_hash
			file_name: file_name
			file_size: file_size
			file_type: file_type
			storage_type: storage_type
			bucket: bucket
			object_key: object_key
			metadata: ''
		}

		// Insert
		inserted := db.insert_file(original) or {
			println('  Iteration ${i}: Insert failed: ${err}')
			return false
		}

		// Retrieve by bucket and key
		retrieved := db.get_file_by_key(bucket, object_key) or {
			println('  Iteration ${i}: Get by key failed: ${err}')
			return false
		}

		// Verify UUID matches
		if retrieved.file_uuid != inserted.file_uuid {
			println('  Iteration ${i}: UUID mismatch when querying by bucket/key')
			return false
		}

		// Verify bucket and key match
		if retrieved.bucket != bucket {
			println('  Iteration ${i}: Bucket mismatch: ${retrieved.bucket} vs ${bucket}')
			return false
		}
		if retrieved.object_key != object_key {
			println('  Iteration ${i}: Object key mismatch: ${retrieved.object_key} vs ${object_key}')
			return false
		}
	}

	return true
}


fn main() {
	println('🚀 开始 Metadata Round Trip 属性测试...')
	println('Feature: v-hono-upload-integration, Property 2: Metadata Round Trip')
	println('Validates: Requirements 1.5, 8.1, 8.2')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(12345)])

	mut stats := PropertyTestStats{}

	// Run property tests
	stats.run_property_test('Property 2.1: Basic Metadata Round Trip', test_property_2_1_basic_metadata_roundtrip)
	stats.run_property_test('Property 2.2: Hash Query Round Trip', test_property_2_2_hash_query_roundtrip)
	stats.run_property_test('Property 2.3: Update Preserves Immutable Fields', test_property_2_3_update_preserves_immutable_fields)
	stats.run_property_test('Property 2.4: Delete Removes File Metadata', test_property_2_4_delete_removes_file)
	stats.run_property_test('Property 2.5: Bucket and Key Query Round Trip', test_property_2_5_bucket_key_query_roundtrip)

	// Print summary
	stats.print_summary()

	// Cleanup
	cleanup_test_db()

	// Exit with error code if any tests failed
	if stats.failed_tests > 0 {
		exit(1)
	}
}
