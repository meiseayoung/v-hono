module main

import rand
import time
import os
import db.sqlite
import crypto.rand as crand

// ============================================================================
// Property 7: List Operation Completeness
// Feature: v-hono-upload-integration, Property 7: List Operation Completeness
// Validates: Requirements 8.5
//
// *For any* set of uploaded files in a bucket, the list operation should return
// all files, and pagination should not lose or duplicate any files.
// ============================================================================

const test_iterations = 50
const test_db_path = './test_list_operation.db'

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
	db.exec('CREATE INDEX IF NOT EXISTS idx_storage_type ON file_info(storage_type);') or {
		return error('Failed to create idx_storage_type index: ${err}')
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

// 分页列表查询
fn (dm DatabaseManager) list_files(options FileListOptions) !FileListResult {
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
	println('\n=== List Operation Completeness 属性测试总结 ===')
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
	chars := 'abcdefghijklmnopqrstuvwxyz0123456789'
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
	name := generate_random_string(5, 15)
	extensions := ['.txt', '.bin', '.dat', '.json', '.xml']
	ext_idx := rand.int_in_range(0, extensions.len) or { 0 }
	return name + extensions[ext_idx]
}

// 生成随机 hash
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
	types := ['text/plain', 'application/octet-stream', 'application/json', 'image/png']
	idx := rand.int_in_range(0, types.len) or { 0 }
	return types[idx]
}

// 生成随机存储类型
fn generate_random_storage_type() string {
	types := ['local', 's3', 'aliyun_oss', 'tencent_cos']
	idx := rand.int_in_range(0, types.len) or { 0 }
	return types[idx]
}

// 生成随机文件大小
fn generate_random_file_size() i64 {
	return rand.i64_in_range(100, 1_000_000) or { 1000 }
}

// 清理测试数据库
fn cleanup_test_db() {
	os.rm(test_db_path) or {}
}

// 创建测试数据库管理器
fn create_test_db() !DatabaseManager {
	return new_database_manager(test_db_path)
}

// 生成随机 FileInfo
fn generate_random_file_info(bucket string, prefix string) FileInfo {
	object_key := if prefix != '' {
		prefix + '/' + generate_random_filename()
	} else {
		generate_random_filename()
	}

	return FileInfo{
		file_hash: generate_random_hash()
		file_name: generate_random_filename()
		file_size: generate_random_file_size()
		file_type: generate_random_content_type()
		storage_type: generate_random_storage_type()
		bucket: bucket
		object_key: object_key
		metadata: ''
	}
}


// ============================================================================
// Property 7.1: List Returns All Files
// For any set of files inserted into a bucket, list should return all of them
// ============================================================================
fn test_property_7_1_list_returns_all_files() bool {
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

	for iteration in 0 .. test_iterations {
		// Generate random number of files (1-20)
		num_files := rand.int_in_range(1, 21) or { 5 }
		bucket := 'test-bucket-${iteration}'

		// Insert files and track UUIDs
		mut inserted_uuids := []string{}
		for _ in 0 .. num_files {
			file_info := generate_random_file_info(bucket, '')
			inserted := db.insert_file(file_info) or {
				println('  Iteration ${iteration}: Insert failed: ${err}')
				return false
			}
			inserted_uuids << inserted.file_uuid
		}

		// List all files in bucket
		result := db.list_files(FileListOptions{
			bucket: bucket
			limit: 1000
		}) or {
			println('  Iteration ${iteration}: List failed: ${err}')
			return false
		}

		// Verify count matches
		if result.files.len != num_files {
			println('  Iteration ${iteration}: Count mismatch. Expected: ${num_files}, Got: ${result.files.len}')
			return false
		}

		// Verify total_count matches
		if result.total_count != num_files {
			println('  Iteration ${iteration}: Total count mismatch. Expected: ${num_files}, Got: ${result.total_count}')
			return false
		}

		// Verify all inserted UUIDs are in the result
		mut found_uuids := []string{}
		for file in result.files {
			found_uuids << file.file_uuid
		}

		for uuid in inserted_uuids {
			if uuid !in found_uuids {
				println('  Iteration ${iteration}: UUID ${uuid} not found in list result')
				return false
			}
		}
	}

	return true
}

// ============================================================================
// Property 7.2: Pagination Does Not Lose Files
// For any set of files, paginating through all pages should return all files exactly once
// ============================================================================
fn test_property_7_2_pagination_no_loss() bool {
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

	for iteration in 0 .. test_iterations {
		// Generate random number of files (10-50)
		num_files := rand.int_in_range(10, 51) or { 20 }
		bucket := 'pagination-bucket-${iteration}'
		page_size := rand.int_in_range(3, 10) or { 5 }

		// Insert files and track UUIDs
		mut inserted_uuids := []string{}
		for _ in 0 .. num_files {
			file_info := generate_random_file_info(bucket, '')
			inserted := db.insert_file(file_info) or {
				println('  Iteration ${iteration}: Insert failed: ${err}')
				return false
			}
			inserted_uuids << inserted.file_uuid
		}

		// Paginate through all files
		mut all_found_uuids := []string{}
		mut offset := 0

		for {
			result := db.list_files(FileListOptions{
				bucket: bucket
				limit: page_size
				offset: offset
			}) or {
				println('  Iteration ${iteration}: List failed at offset ${offset}: ${err}')
				return false
			}

			for file in result.files {
				all_found_uuids << file.file_uuid
			}

			if !result.has_more {
				break
			}

			offset += page_size
		}

		// Verify all files were found
		if all_found_uuids.len != num_files {
			println('  Iteration ${iteration}: Total files mismatch. Expected: ${num_files}, Got: ${all_found_uuids.len}')
			return false
		}

		// Verify no duplicates
		mut seen := map[string]bool{}
		for uuid in all_found_uuids {
			if uuid in seen {
				println('  Iteration ${iteration}: Duplicate UUID found: ${uuid}')
				return false
			}
			seen[uuid] = true
		}

		// Verify all inserted UUIDs are found
		for uuid in inserted_uuids {
			if uuid !in all_found_uuids {
				println('  Iteration ${iteration}: UUID ${uuid} not found through pagination')
				return false
			}
		}
	}

	return true
}


// ============================================================================
// Property 7.3: Prefix Filter Works Correctly
// For any set of files with different prefixes, filtering by prefix should return only matching files
// ============================================================================
fn test_property_7_3_prefix_filter() bool {
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

	for iteration in 0 .. test_iterations {
		bucket := 'prefix-bucket-${iteration}'

		// Create files with different prefixes
		prefixes := ['images', 'documents', 'videos', 'data']
		mut files_per_prefix := map[string]int{}

		for prefix in prefixes {
			num_files := rand.int_in_range(2, 8) or { 3 }
			files_per_prefix[prefix] = num_files

			for _ in 0 .. num_files {
				file_info := generate_random_file_info(bucket, prefix)
				db.insert_file(file_info) or {
					println('  Iteration ${iteration}: Insert failed: ${err}')
					return false
				}
			}
		}

		// Test filtering by each prefix
		for prefix in prefixes {
			result := db.list_files(FileListOptions{
				bucket: bucket
				prefix: prefix
				limit: 1000
			}) or {
				println('  Iteration ${iteration}: List with prefix ${prefix} failed: ${err}')
				return false
			}

			expected_count := files_per_prefix[prefix]
			if result.files.len != expected_count {
				println('  Iteration ${iteration}: Prefix ${prefix} count mismatch. Expected: ${expected_count}, Got: ${result.files.len}')
				return false
			}

			// Verify all returned files have the correct prefix
			for file in result.files {
				if !file.object_key.starts_with(prefix) {
					println('  Iteration ${iteration}: File ${file.object_key} does not start with prefix ${prefix}')
					return false
				}
			}
		}
	}

	return true
}

// ============================================================================
// Property 7.4: Storage Type Filter Works Correctly
// For any set of files with different storage types, filtering should return only matching files
// ============================================================================
fn test_property_7_4_storage_type_filter() bool {
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

	for iteration in 0 .. test_iterations {
		bucket := 'storage-type-bucket-${iteration}'

		// Create files with different storage types
		storage_types := ['local', 's3', 'aliyun_oss', 'tencent_cos']
		mut files_per_type := map[string]int{}

		for st in storage_types {
			num_files := rand.int_in_range(2, 6) or { 3 }
			files_per_type[st] = num_files

			for _ in 0 .. num_files {
				file_info := FileInfo{
					file_hash: generate_random_hash()
					file_name: generate_random_filename()
					file_size: generate_random_file_size()
					file_type: generate_random_content_type()
					storage_type: st
					bucket: bucket
					object_key: generate_random_filename()
					metadata: ''
				}
				db.insert_file(file_info) or {
					println('  Iteration ${iteration}: Insert failed: ${err}')
					return false
				}
			}
		}

		// Test filtering by each storage type
		for st in storage_types {
			result := db.list_files(FileListOptions{
				bucket: bucket
				storage_type: st
				limit: 1000
			}) or {
				println('  Iteration ${iteration}: List with storage_type ${st} failed: ${err}')
				return false
			}

			expected_count := files_per_type[st]
			if result.files.len != expected_count {
				println('  Iteration ${iteration}: Storage type ${st} count mismatch. Expected: ${expected_count}, Got: ${result.files.len}')
				return false
			}

			// Verify all returned files have the correct storage type
			for file in result.files {
				if file.storage_type != st {
					println('  Iteration ${iteration}: File has storage_type ${file.storage_type}, expected ${st}')
					return false
				}
			}
		}
	}

	return true
}

// ============================================================================
// Property 7.5: Empty Bucket Returns Empty List
// For any empty bucket, list should return an empty result
// ============================================================================
fn test_property_7_5_empty_bucket() bool {
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

	for iteration in 0 .. test_iterations {
		// Generate a random bucket name that doesn't exist
		bucket := 'empty-bucket-${iteration}-${generate_random_string(5, 10)}'

		result := db.list_files(FileListOptions{
			bucket: bucket
			limit: 100
		}) or {
			println('  Iteration ${iteration}: List failed: ${err}')
			return false
		}

		if result.files.len != 0 {
			println('  Iteration ${iteration}: Expected empty list, got ${result.files.len} files')
			return false
		}

		if result.total_count != 0 {
			println('  Iteration ${iteration}: Expected total_count 0, got ${result.total_count}')
			return false
		}

		if result.has_more {
			println('  Iteration ${iteration}: has_more should be false for empty bucket')
			return false
		}
	}

	return true
}


fn main() {
	println('🚀 开始 List Operation Completeness 属性测试...')
	println('Feature: v-hono-upload-integration, Property 7: List Operation Completeness')
	println('Validates: Requirements 8.5')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(67890)])

	mut stats := PropertyTestStats{}

	// Run property tests
	stats.run_property_test('Property 7.1: List Returns All Files', test_property_7_1_list_returns_all_files)
	stats.run_property_test('Property 7.2: Pagination Does Not Lose Files', test_property_7_2_pagination_no_loss)
	stats.run_property_test('Property 7.3: Prefix Filter Works Correctly', test_property_7_3_prefix_filter)
	stats.run_property_test('Property 7.4: Storage Type Filter Works Correctly', test_property_7_4_storage_type_filter)
	stats.run_property_test('Property 7.5: Empty Bucket Returns Empty List', test_property_7_5_empty_bucket)

	// Print summary
	stats.print_summary()

	// Cleanup
	cleanup_test_db()

	// Exit with error code if any tests failed
	if stats.failed_tests > 0 {
		exit(1)
	}
}
