module main

import rand
import time
import os
import crypto.md5

// ============================================================================
// Property 6: File Existence Consistency
// Feature: v-hono-upload-integration, Property 6: File Existence Consistency
// Validates: Requirements 2.2, 8.4
//
// *For any* file, after upload the `exists()` method should return true,
// and after deletion it should return false.
// ============================================================================

const test_iterations = 100
const test_base_path = './test_storage_existence'
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


// LocalStorage 本地存储提供者
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

fn new_object_info(key string, size i64, etag string, content_type string, last_modified i64) ObjectInfo {
	return ObjectInfo{
		key: key
		size: size
		etag: etag
		content_type: content_type
		last_modified: last_modified
		metadata: map[string]string{}
	}
}


// ============================================================================
// LocalStorage implementation (copied for standalone testing)
// ============================================================================

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

fn (s LocalStorage) delete(bucket string, key string) ! {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error('Object not found: ${bucket}/${key}')
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

fn (s LocalStorage) delete_bucket(bucket string) ! {
	bucket_path := s.get_bucket_path(bucket)

	if !os.exists(bucket_path) {
		return error('Bucket not found: ${bucket}')
	}

	entries := os.ls(bucket_path) or { []string{} }
	if entries.len > 0 {
		return error('Bucket is not empty')
	}

	os.rmdir(bucket_path) or {
		return error('Failed to delete bucket: ${err}')
	}
}

fn (s LocalStorage) bucket_exists(bucket string) !bool {
	bucket_path := s.get_bucket_path(bucket)
	return os.exists(bucket_path) && os.is_dir(bucket_path)
}

fn (s LocalStorage) head(bucket string, key string) !ObjectInfo {
	full_path := s.get_full_path(bucket, key)

	if !os.exists(full_path) {
		return error('Object not found: ${bucket}/${key}')
	}

	file_size := os.file_size(full_path)
	mtime := os.file_last_mod_unix(full_path)

	data := os.read_bytes(full_path) or {
		return error('Failed to read file for metadata: ${err}')
	}
	etag := calculate_etag(data)
	content_type := infer_content_type(key)

	return new_object_info(key, i64(file_size), etag, content_type, mtime)
}

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
		'.pdf' { return 'application/pdf' }
		'.zip' { return 'application/zip' }
		else { return 'application/octet-stream' }
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
	println('\n=== File Existence Consistency 属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}

fn generate_random_bytes(min_len int, max_len int) []u8 {
	len := rand.int_in_range(min_len, max_len) or { min_len }
	mut result := []u8{len: len}
	for i in 0 .. len {
		result[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	return result
}

fn generate_random_filename() string {
	chars := 'abcdefghijklmnopqrstuvwxyz0123456789'
	len := rand.int_in_range(5, 20) or { 10 }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx].ascii_str()
	}
	extensions := ['.txt', '.bin', '.dat', '.json', '.xml']
	ext_idx := rand.int_in_range(0, extensions.len) or { 0 }
	return result + extensions[ext_idx]
}

fn cleanup_test_dir() {
	os.rmdir_all(test_base_path) or {}
}

fn create_test_storage() !LocalStorage {
	config := LocalStorageConfig{
		base_path: test_base_path
		url_prefix: '/files'
		create_dirs: true
	}
	return new_local_storage(config)
}


// ============================================================================
// Property 6.1: File Exists After Upload
// For any file, after upload the exists() method should return true
// ============================================================================
fn test_property_6_1_exists_after_upload() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage := create_test_storage() or {
		println('  Failed to create storage: ${err}')
		return false
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	for i in 0 .. test_iterations {
		data := generate_random_bytes(1, 5000)
		filename := generate_random_filename()

		exists_before := storage.exists(test_bucket, filename) or {
			println('  Iteration ${i}: exists() failed before upload: ${err}')
			return false
		}

		if exists_before {
			println('  Iteration ${i}: File exists before upload')
			return false
		}

		result := storage.upload(test_bucket, filename, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Upload failed: ${err}')
			return false
		}

		if !result.success {
			println('  Iteration ${i}: Upload returned failure')
			return false
		}

		exists_after := storage.exists(test_bucket, filename) or {
			println('  Iteration ${i}: exists() failed after upload: ${err}')
			return false
		}

		if !exists_after {
			println('  Iteration ${i}: File does not exist after upload')
			return false
		}

		storage.delete(test_bucket, filename) or {}
	}

	return true
}

// ============================================================================
// Property 6.2: File Does Not Exist After Delete
// For any file, after deletion the exists() method should return false
// ============================================================================
fn test_property_6_2_not_exists_after_delete() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage := create_test_storage() or {
		println('  Failed to create storage: ${err}')
		return false
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	for i in 0 .. test_iterations {
		data := generate_random_bytes(1, 5000)
		filename := generate_random_filename()

		storage.upload(test_bucket, filename, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Upload failed: ${err}')
			return false
		}

		exists_before_delete := storage.exists(test_bucket, filename) or {
			println('  Iteration ${i}: exists() failed before delete: ${err}')
			return false
		}

		if !exists_before_delete {
			println('  Iteration ${i}: File does not exist before delete')
			return false
		}

		storage.delete(test_bucket, filename) or {
			println('  Iteration ${i}: Delete failed: ${err}')
			return false
		}

		exists_after_delete := storage.exists(test_bucket, filename) or {
			println('  Iteration ${i}: exists() failed after delete: ${err}')
			return false
		}

		if exists_after_delete {
			println('  Iteration ${i}: File still exists after delete')
			return false
		}
	}

	return true
}


// ============================================================================
// Property 6.3: Non-Existent File Returns False
// For any random filename that was never uploaded, exists() should return false
// ============================================================================
fn test_property_6_3_non_existent_file() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage := create_test_storage() or {
		println('  Failed to create storage: ${err}')
		return false
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	for i in 0 .. test_iterations {
		filename := generate_random_filename()

		exists := storage.exists(test_bucket, filename) or {
			println('  Iteration ${i}: exists() failed: ${err}')
			return false
		}

		if exists {
			println('  Iteration ${i}: Non-existent file reported as existing')
			return false
		}
	}

	return true
}

// ============================================================================
// Property 6.4: Existence Consistency with Head Operation
// For any file, exists() and head() should be consistent
// ============================================================================
fn test_property_6_4_existence_head_consistency() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage := create_test_storage() or {
		println('  Failed to create storage: ${err}')
		return false
	}

	storage.create_bucket(test_bucket) or {
		println('  Failed to create bucket: ${err}')
		return false
	}

	for i in 0 .. test_iterations {
		data := generate_random_bytes(1, 5000)
		filename := generate_random_filename()

		storage.upload(test_bucket, filename, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Upload failed: ${err}')
			return false
		}

		exists := storage.exists(test_bucket, filename) or {
			println('  Iteration ${i}: exists() failed: ${err}')
			return false
		}

		info := storage.head(test_bucket, filename) or {
			println('  Iteration ${i}: head() failed but exists() returned ${exists}: ${err}')
			return false
		}

		if !exists {
			println('  Iteration ${i}: exists() returned false but head() succeeded')
			return false
		}

		if info.size != i64(data.len) {
			println('  Iteration ${i}: head() returned wrong size. Expected: ${data.len}, Got: ${info.size}')
			return false
		}

		storage.delete(test_bucket, filename) or {}

		exists_after := storage.exists(test_bucket, filename) or {
			println('  Iteration ${i}: exists() failed after delete: ${err}')
			return false
		}

		if exists_after {
			println('  Iteration ${i}: exists() returned true after delete')
			return false
		}

		storage.head(test_bucket, filename) or {
			continue
		}

		println('  Iteration ${i}: head() succeeded after delete')
		return false
	}

	return true
}


// ============================================================================
// Property 6.5: Bucket Existence Consistency
// For any bucket, bucket_exists() should be consistent with create/delete operations
// ============================================================================
fn test_property_6_5_bucket_existence_consistency() bool {
	cleanup_test_dir()
	defer {
		cleanup_test_dir()
	}

	mut storage := create_test_storage() or {
		println('  Failed to create storage: ${err}')
		return false
	}

	for i in 0 .. test_iterations {
		bucket_name := 'test-bucket-${i}-${rand.int_in_range(1000, 9999) or { 1000 }}'

		exists_before := storage.bucket_exists(bucket_name) or {
			println('  Iteration ${i}: bucket_exists() failed before create: ${err}')
			return false
		}

		if exists_before {
			println('  Iteration ${i}: Bucket exists before create')
			return false
		}

		storage.create_bucket(bucket_name) or {
			println('  Iteration ${i}: create_bucket() failed: ${err}')
			return false
		}

		exists_after_create := storage.bucket_exists(bucket_name) or {
			println('  Iteration ${i}: bucket_exists() failed after create: ${err}')
			return false
		}

		if !exists_after_create {
			println('  Iteration ${i}: Bucket does not exist after create')
			return false
		}

		storage.delete_bucket(bucket_name) or {
			println('  Iteration ${i}: delete_bucket() failed: ${err}')
			return false
		}

		exists_after_delete := storage.bucket_exists(bucket_name) or {
			println('  Iteration ${i}: bucket_exists() failed after delete: ${err}')
			return false
		}

		if exists_after_delete {
			println('  Iteration ${i}: Bucket still exists after delete')
			return false
		}
	}

	return true
}

fn main() {
	println('🚀 开始 File Existence Consistency 属性测试...')
	println('Feature: v-hono-upload-integration, Property 6: File Existence Consistency')
	println('Validates: Requirements 2.2, 8.4')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(67890)])

	mut stats := PropertyTestStats{}

	stats.run_property_test('Property 6.1: File Exists After Upload', test_property_6_1_exists_after_upload)
	stats.run_property_test('Property 6.2: File Does Not Exist After Delete', test_property_6_2_not_exists_after_delete)
	stats.run_property_test('Property 6.3: Non-Existent File Returns False', test_property_6_3_non_existent_file)
	stats.run_property_test('Property 6.4: Existence Consistency with Head Operation', test_property_6_4_existence_head_consistency)
	stats.run_property_test('Property 6.5: Bucket Existence Consistency', test_property_6_5_bucket_existence_consistency)

	stats.print_summary()

	cleanup_test_dir()

	if stats.failed_tests > 0 {
		exit(1)
	}
}
