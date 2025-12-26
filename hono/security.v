module hono

import os

// 文件类型白名单
const allowed_file_extensions = [
	// 文档类型
	'.txt', '.md', '.pdf', '.doc', '.docx',
	// 图片类型
	'.jpg', '.jpeg', '.png', '.gif', '.svg', '.ico', '.webp',
	// 音视频类型
	'.mp3', '.mp4', '.wav', '.avi', '.mov', '.webm',
	// 压缩文件
	'.zip', '.rar', '.7z', '.tar', '.gz',
	// Web 文件
	'.html', '.htm', '.css', '.js', '.json', '.xml',
	// 字体文件
	'.ttf', '.otf', '.woff', '.woff2', '.eot'
]

// 危险字符列表
const dangerous_chars = ['<', '>', '"', '|', '?', '*', '\x00', '\r', '\n']

// 危险路径模式
const dangerous_patterns = [
	'..',      // 路径遍历
	'~',       // 用户目录
	'$',       // 环境变量
	'%',       // Windows 环境变量
	'\\\\',    // UNC 路径
	'/..',     // Unix 路径遍历
	'\\..',    // Windows 路径遍历
	'../',     // 相对路径遍历
	'..\\',    // Windows 相对路径遍历
]

// 安全路径验证选项
pub struct PathValidationOptions {
pub:
	allow_absolute_paths   bool     // 是否允许绝对路径
	allow_hidden_files     bool     // 是否允许隐藏文件（以.开头）
	check_file_extension   bool = true   // 是否检查文件扩展名白名单
	max_path_length        int = 260     // 最大路径长度（Windows限制）
	allowed_base_paths     []string      // 允许的基础路径列表
	custom_allowed_extensions []string   // 自定义允许的扩展名
}

// 默认路径验证选项
pub fn default_path_validation_options() PathValidationOptions {
	return PathValidationOptions{}
}

// 增强的路径安全检查
pub fn validate_file_path(path string, options PathValidationOptions) !string {
	// 1. 基本检查
	if path.len == 0 {
		return error('Empty path not allowed')
	}
	
	if path.len > options.max_path_length {
		return error('Path too long: ${path.len} > ${options.max_path_length}')
	}
	
	// 2. 规范化路径
	clean_path := normalize_path(path)
	
	// 3. 检查危险字符
	for dangerous_char in dangerous_chars {
		if clean_path.contains(dangerous_char) {
			return error('Dangerous character detected: ${dangerous_char}')
		}
	}
	
	// 4. 检查危险模式
	for pattern in dangerous_patterns {
		if clean_path.contains(pattern) {
			return error('Dangerous path pattern detected: ${pattern}')
		}
	}
	
	// 5. 检查绝对路径
	if !options.allow_absolute_paths {
		if is_absolute_path(clean_path) {
			return error('Absolute paths not allowed')
		}
	}
	
	// 6. 检查隐藏文件
	if !options.allow_hidden_files {
		if is_hidden_file(clean_path) {
			return error('Hidden files not allowed')
		}
	}
	
	// 7. 检查文件扩展名
	if options.check_file_extension {
		if !is_allowed_file_type(clean_path, options.custom_allowed_extensions) {
			return error('File type not allowed')
		}
	}
	
	// 8. 检查基础路径限制
	if options.allowed_base_paths.len > 0 {
		if !is_within_allowed_paths(clean_path, options.allowed_base_paths) {
			return error('Path outside allowed directories')
		}
	}
	
	return clean_path
}

// 路径规范化
fn normalize_path(path string) string {
	// 移除多余的空白字符
	mut clean_path := path.trim_space()
	
	// 统一路径分隔符为 /
	clean_path = clean_path.replace('\\', '/')
	
	// 移除重复的路径分隔符
	for clean_path.contains('//') {
		clean_path = clean_path.replace('//', '/')
	}
	
	// 移除末尾的路径分隔符
	if clean_path.ends_with('/') && clean_path.len > 1 {
		clean_path = clean_path[..clean_path.len - 1]
	}
	
	return clean_path
}

// 检查是否为绝对路径
fn is_absolute_path(path string) bool {
	// Unix/Linux 绝对路径
	if path.starts_with('/') {
		return true
	}
	
	// Windows 绝对路径 (C:, D: 等)
	if path.len >= 2 && path[1] == `:` {
		return true
	}
	
	// UNC 路径 (\\server\share)
	if path.starts_with('//') {
		return true
	}
	
	return false
}

// 检查是否为隐藏文件
fn is_hidden_file(path string) bool {
	// 获取文件名部分
	parts := path.split('/')
	if parts.len == 0 {
		return false
	}
	
	filename := parts.last()
	return filename.starts_with('.') && filename != '.' && filename != '..'
}

// 检查文件类型是否被允许
fn is_allowed_file_type(path string, custom_extensions []string) bool {
	ext := os.file_ext(path).to_lower()
	
	// 如果没有扩展名，拒绝
	if ext == '' {
		return false
	}
	
	// 检查自定义扩展名列表
	if custom_extensions.len > 0 {
		return ext in custom_extensions
	}
	
	// 检查默认白名单
	return ext in allowed_file_extensions
}

// 检查路径是否在允许的基础路径内
fn is_within_allowed_paths(path string, allowed_paths []string) bool {
	for allowed_path in allowed_paths {
		normalized_allowed := normalize_path(allowed_path)
		if path.starts_with(normalized_allowed) {
			return true
		}
	}
	return false
}

// 便捷函数：基本路径安全检查（向后兼容）
pub fn is_safe_path(path string) bool {
	result := validate_file_path(path, default_path_validation_options()) or { return false }
	return result.len > 0
}

// 便捷函数：文件路径安全检查（向后兼容）
pub fn is_safe_file_path(path string) bool {
	return is_safe_path(path)
}

// 输入验证：文件哈希
pub fn validate_file_hash(hash string) !string {
	if hash.len == 0 {
		return error('File hash cannot be empty')
	}
	
	// MD5 哈希长度检查
	if hash.len != 32 {
		return error('Invalid hash length: expected 32, got ${hash.len}')
	}
	
	// 检查是否只包含十六进制字符
	for ch in hash {
		if !ch.is_hex_digit() {
			return error('Invalid hash character: ${ch}')
		}
	}
	
	return hash.to_lower()
}

// 输入验证：分片索引
pub fn validate_chunk_index(index_str string, max_chunks int) !int {
	if index_str.len == 0 {
		return error('Chunk index cannot be empty')
	}
	
	// 检查是否只包含数字
	for ch in index_str {
		if !ch.is_digit() {
			return error('Chunk index must be a number')
		}
	}
	
	index := index_str.int()
	
	if index < 0 {
		return error('Chunk index cannot be negative')
	}
	
	if max_chunks > 0 && index >= max_chunks {
		return error('Chunk index ${index} exceeds maximum ${max_chunks}')
	}
	
	return index
}

// 输入验证：文件大小
pub fn validate_file_size(size_str string, max_size int) !int {
	if size_str.len == 0 {
		return error('File size cannot be empty')
	}
	
	// 检查是否只包含数字
	for ch in size_str {
		if !ch.is_digit() {
			return error('File size must be a number')
		}
	}
	
	size := size_str.int()
	
	if size <= 0 {
		return error('File size must be positive')
	}
	
	if size > max_size {
		return error('File size ${size} exceeds maximum ${max_size}')
	}
	
	return size
}

// 输入验证：文件名
pub fn validate_filename(filename string) !string {
	if filename.len == 0 {
		return error('Filename cannot be empty')
	}
	
	if filename.len > 255 {
		return error('Filename too long: ${filename.len} > 255')
	}
	
	// 检查危险字符
	for dangerous_char in dangerous_chars {
		if filename.contains(dangerous_char) {
			return error('Dangerous character in filename: ${dangerous_char}')
		}
	}
	
	// 检查保留名称 (Windows)
	reserved_names := ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 
					   'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 
					   'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9']
	
	name_without_ext := filename.split('.')[0].to_upper()
	if name_without_ext in reserved_names {
		return error('Reserved filename not allowed: ${filename}')
	}
	
	return filename
}

// 安全的内容类型检测
pub fn get_safe_content_type(file_path string) string {
	ext := os.file_ext(file_path).to_lower()
	
	// 只返回已知安全的内容类型
	match ext {
		'.html', '.htm' { return 'text/html; charset=utf-8' }
		'.css' { return 'text/css; charset=utf-8' }
		'.js' { return 'application/javascript; charset=utf-8' }
		'.json' { return 'application/json; charset=utf-8' }
		'.xml' { return 'application/xml; charset=utf-8' }
		'.txt' { return 'text/plain; charset=utf-8' }
		'.md' { return 'text/markdown; charset=utf-8' }
		'.pdf' { return 'application/pdf' }
		'.png' { return 'image/png' }
		'.jpg', '.jpeg' { return 'image/jpeg' }
		'.gif' { return 'image/gif' }
		'.svg' { return 'image/svg+xml' }
		'.ico' { return 'image/x-icon' }
		'.woff' { return 'font/woff' }
		'.woff2' { return 'font/woff2' }
		'.ttf' { return 'font/ttf' }
		'.eot' { return 'application/vnd.ms-fontobject' }
		'.otf' { return 'font/otf' }
		'.mp4' { return 'video/mp4' }
		'.webm' { return 'video/webm' }
		'.mp3' { return 'audio/mpeg' }
		'.wav' { return 'audio/wav' }
		'.zip' { return 'application/zip' }
		'.tar' { return 'application/x-tar' }
		'.gz' { return 'application/gzip' }
		else { 
			// 对于未知类型，返回安全的默认类型
			return 'application/octet-stream'
		}
	}
}