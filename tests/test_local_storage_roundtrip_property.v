module main

import rand
import time
import os
import crypto.md5

// ============================================================================
// Property 1: Upload-Download Round Trip (Local)
// Feature: v-hono-upload-integration, Property 1: Upload-Download Round Trip
// Validates: Requirements 1.2, 2.3
//
// *For any* valid file data and any storage provider (Local, S3, OSS, COS),
// uploading the file and then downloading it should return identical content.
// ============================================================================

const test_iterations = 100
const test_base_path = './test_storage_roundtrip'
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

struct ListOptions {
pub:
	prefix      string
	delimiter   string
	max_keys    int = 1000
	start_after string
}

struct ListResult {
pub:
	objects         []ObjectInfo
	common_prefixes []string
	is_truncated    bool
	next_marker     string
}

struct PresignOptions {
pub:
	expires_in   int    = 3600
	method       string = 'GET'
	content_type string
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

// 创建本地存储提供者
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

fn new_list_result(objects []ObjectInfo, common_prefixes []string, is_truncated bool, next_marker string) ListResult {
	return ListResult{
		objects: objects
		common_prefixes: common_prefixes
		is_truncated: is_truncated
		next_marker: next_marker
	}
}

fn new_part_info(part_number int, etag string, size i64) PartInfo {
	return PartInfo{
		part_number: part_number
		etag: etag
		size: size
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
	println('\n=== Upload-Download Round Trip 属性测试总结 ===')
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

fn generate_random_content_type() string {
	types := [
		'text/plain',
		'application/octet-stream',
		'application/json',
		'image/png',
		'application/xml',
	]
	idx := rand.int_in_range(0, types.len) or { 0 }
	return types[idx]
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
// Property 1.1: Basic Upload-Download Round Trip
// For any random file data, uploading and downloading should return identical content
// ============================================================================
fn test_property_1_1_basic_roundtrip() bool {
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
		data := generate_random_bytes(1, 10000)
		filename := generate_random_filename()
		content_type := generate_random_content_type()

		result := storage.upload(test_bucket, filename, data, content_type) or {
			println('  Iteration ${i}: Upload failed: ${err}')
			return false
		}

		if !result.success {
			println('  Iteration ${i}: Upload returned failure: ${result.error_msg}')
			return false
		}

		downloaded := storage.download(test_bucket, filename) or {
			println('  Iteration ${i}: Download failed: ${err}')
			return false
		}

		if data != downloaded {
			println('  Iteration ${i}: Content mismatch! Original: ${data.len} bytes, Downloaded: ${downloaded.len} bytes')
			return false
		}

		storage.delete(test_bucket, filename) or {}
	}

	return true
}

// ============================================================================
// Property 1.2: Empty File Round Trip
// For empty files, uploading and downloading should return empty content
// ============================================================================
fn test_property_1_2_empty_file_roundtrip() bool {
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
		data := []u8{}
		filename := generate_random_filename()

		result := storage.upload(test_bucket, filename, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Upload failed: ${err}')
			return false
		}

		if !result.success {
			println('  Iteration ${i}: Upload returned failure')
			return false
		}

		downloaded := storage.download(test_bucket, filename) or {
			println('  Iteration ${i}: Download failed: ${err}')
			return false
		}

		if downloaded.len != 0 {
			println('  Iteration ${i}: Expected empty file, got ${downloaded.len} bytes')
			return false
		}

		storage.delete(test_bucket, filename) or {}
	}

	return true
}


// ============================================================================
// Property 1.3: Large File Round Trip
// For larger files (up to 500KB), uploading and downloading should return identical content
// ============================================================================
fn test_property_1_3_large_file_roundtrip() bool {
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

	// Run fewer iterations for large files
	for i in 0 .. 10 {
		data := generate_random_bytes(100000, 500000)
		filename := generate_random_filename()

		result := storage.upload(test_bucket, filename, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Upload failed: ${err}')
			return false
		}

		if !result.success {
			println('  Iteration ${i}: Upload returned failure')
			return false
		}

		if result.size != i64(data.len) {
			println('  Iteration ${i}: Size mismatch in result. Expected: ${data.len}, Got: ${result.size}')
			return false
		}

		downloaded := storage.download(test_bucket, filename) or {
			println('  Iteration ${i}: Download failed: ${err}')
			return false
		}

		if data != downloaded {
			println('  Iteration ${i}: Content mismatch! Original: ${data.len} bytes, Downloaded: ${downloaded.len} bytes')
			return false
		}

		storage.delete(test_bucket, filename) or {}
	}

	return true
}

// ============================================================================
// Property 1.4: Nested Path Round Trip
// For files with nested paths, uploading and downloading should work correctly
// ============================================================================
fn test_property_1_4_nested_path_roundtrip() bool {
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
		data := generate_random_bytes(100, 5000)

		depth := rand.int_in_range(1, 5) or { 2 }
		mut path_parts := []string{}
		for _ in 0 .. depth {
			part_len := rand.int_in_range(3, 10) or { 5 }
			mut part := ''
			for _ in 0 .. part_len {
				idx := rand.int_in_range(0, 26) or { 0 }
				part += ('a'[0] + u8(idx)).ascii_str()
			}
			path_parts << part
		}
		path_parts << generate_random_filename()
		filename := path_parts.join('/')

		result := storage.upload(test_bucket, filename, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Upload failed for path "${filename}": ${err}')
			return false
		}

		if !result.success {
			println('  Iteration ${i}: Upload returned failure')
			return false
		}

		downloaded := storage.download(test_bucket, filename) or {
			println('  Iteration ${i}: Download failed for path "${filename}": ${err}')
			return false
		}

		if data != downloaded {
			println('  Iteration ${i}: Content mismatch for path "${filename}"')
			return false
		}

		storage.delete(test_bucket, filename) or {}
	}

	return true
}


// ============================================================================
// Property 1.5: ETag Consistency
// For any file, the ETag returned on upload should be consistent with the content
// ============================================================================
fn test_property_1_5_etag_consistency() bool {
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
		data := generate_random_bytes(100, 5000)
		filename := generate_random_filename()

		result := storage.upload(test_bucket, filename, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Upload failed: ${err}')
			return false
		}

		if result.etag == '' {
			println('  Iteration ${i}: ETag is empty')
			return false
		}

		filename2 := generate_random_filename()
		result2 := storage.upload(test_bucket, filename2, data, 'application/octet-stream') or {
			println('  Iteration ${i}: Second upload failed: ${err}')
			return false
		}

		if result.etag != result2.etag {
			println('  Iteration ${i}: ETags differ for same content: ${result.etag} vs ${result2.etag}')
			return false
		}

		storage.delete(test_bucket, filename) or {}
		storage.delete(test_bucket, filename2) or {}
	}

	return true
}

fn main() {
	println('🚀 开始 Upload-Download Round Trip 属性测试...')
	println('Feature: v-hono-upload-integration, Property 1: Upload-Download Round Trip (Local)')
	println('Validates: Requirements 1.2, 2.3')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	rand.seed([u32(time.now().unix()), u32(54321)])

	mut stats := PropertyTestStats{}

	stats.run_property_test('Property 1.1: Basic Upload-Download Round Trip', test_property_1_1_basic_roundtrip)
	stats.run_property_test('Property 1.2: Empty File Round Trip', test_property_1_2_empty_file_roundtrip)
	stats.run_property_test('Property 1.3: Large File Round Trip', test_property_1_3_large_file_roundtrip)
	stats.run_property_test('Property 1.4: Nested Path Round Trip', test_property_1_4_nested_path_roundtrip)
	stats.run_property_test('Property 1.5: ETag Consistency', test_property_1_5_etag_consistency)

	stats.print_summary()

	cleanup_test_dir()

	if stats.failed_tests > 0 {
		exit(1)
	}
}
