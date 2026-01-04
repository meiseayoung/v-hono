module hono

import net.http
import compress.gzip
import compress.zlib

// CompressEncoding 枚举 - 支持的压缩编码类型
pub enum CompressEncoding {
	gzip
	deflate
}

// CompressOptions 结构体 - 压缩配置选项
pub struct CompressOptions {
pub:
	encoding  ?CompressEncoding  // 指定编码，none 表示自动选择
	threshold int = 1024         // 最小压缩大小（字节），默认 1KB
	level     int = 128          // 压缩级别 (0-4095 for gzip)
}

// compress - 压缩中间件工厂函数
// 返回一个 ContextMiddleware，用于压缩响应体
pub fn compress(options ...CompressOptions) ContextMiddleware {
	opts := if options.len > 0 { options[0] } else { CompressOptions{} }
	
	return fn [opts] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 先执行后续处理器获取响应
		mut response := next(mut c)
		
		// 检查 Cache-Control: no-transform
		if has_no_transform(response) {
			return response
		}
		
		// 检查响应体大小是否达到阈值
		if response.body.len < opts.threshold {
			return response
		}
		
		// 检查 Content-Type 是否可压缩
		content_type := get_response_content_type(response)
		if !is_compressible_content_type(content_type) {
			return response
		}
		
		// 检查响应是否已经被压缩
		if is_already_compressed(response) {
			return response
		}
		
		// 获取客户端支持的编码
		accept_encoding := c.req.header.get_custom('Accept-Encoding') or { '' }
		if accept_encoding.len == 0 {
			return response
		}
		
		// 选择压缩编码
		encoding := select_encoding(accept_encoding, opts.encoding)
		if encoding == none {
			return response
		}
		
		// 执行压缩
		selected_encoding := encoding or { return response }
		compressed_body := compress_body(response.body, selected_encoding, opts.level) or {
			// 压缩失败，返回原始响应
			return response
		}
		
		// 如果压缩后更大，返回原始响应
		if compressed_body.len >= response.body.len {
			return response
		}
		
		// 构建新的响应头
		mut new_header := http.new_header()
		
		// 复制原有头部
		for key in response.header.keys() {
			values := response.header.custom_values(key)
			for value in values {
				// 跳过 Content-Length，稍后重新设置
				if key.to_lower() != 'content-length' {
					new_header.add_custom(key, value) or { continue }
				}
			}
		}
		
		// 设置 Content-Encoding
		encoding_str := if selected_encoding == .gzip { 'gzip' } else { 'deflate' }
		new_header.add_custom('Content-Encoding', encoding_str) or {}
		
		// 设置新的 Content-Length
		new_header.add_custom('Content-Length', compressed_body.len.str()) or {}
		
		// 添加 Vary 头，表示响应根据 Accept-Encoding 变化
		new_header.add_custom('Vary', 'Accept-Encoding') or {}
		
		return http.Response{
			status_code: response.status_code
			header: new_header
			body: compressed_body.bytestr()
		}
	}
}

// has_no_transform - 检查响应是否包含 Cache-Control: no-transform
fn has_no_transform(response http.Response) bool {
	cache_control := response.header.get_custom('Cache-Control') or { '' }
	return cache_control.contains('no-transform')
}

// get_response_content_type - 获取响应的 Content-Type
fn get_response_content_type(response http.Response) string {
	return response.header.get_custom('Content-Type') or { '' }
}

// is_compressible_content_type - 检查 Content-Type 是否可压缩
fn is_compressible_content_type(content_type string) bool {
	if content_type.len == 0 {
		return true  // 默认可压缩
	}
	
	ct_lower := content_type.to_lower()
	
	// 可压缩的 MIME 类型
	compressible_types := [
		'text/',
		'application/json',
		'application/javascript',
		'application/xml',
		'application/xhtml+xml',
		'application/rss+xml',
		'application/atom+xml',
		'application/x-javascript',
		'application/x-font-ttf',
		'font/opentype',
		'font/ttf',
		'font/eot',
		'image/svg+xml',
		'image/x-icon',
		'image/vnd.microsoft.icon',
	]
	
	for ct in compressible_types {
		if ct_lower.starts_with(ct) || ct_lower.contains(ct) {
			return true
		}
	}
	
	// 不可压缩的类型（已压缩的格式）
	non_compressible_types := [
		'image/png',
		'image/jpeg',
		'image/gif',
		'image/webp',
		'video/',
		'audio/',
		'application/zip',
		'application/gzip',
		'application/x-gzip',
		'application/x-compress',
		'application/x-compressed',
		'application/x-bzip',
		'application/x-bzip2',
		'application/x-rar-compressed',
		'application/x-7z-compressed',
	]
	
	for ct in non_compressible_types {
		if ct_lower.starts_with(ct) || ct_lower.contains(ct) {
			return false
		}
	}
	
	return true
}

// is_already_compressed - 检查响应是否已经被压缩
fn is_already_compressed(response http.Response) bool {
	content_encoding := response.header.get_custom('Content-Encoding') or { '' }
	return content_encoding.len > 0
}

// select_encoding - 选择最佳压缩编码
fn select_encoding(accept_encoding string, preferred ?CompressEncoding) ?CompressEncoding {
	// 如果指定了首选编码，检查客户端是否支持
	if pref := preferred {
		match pref {
			.gzip {
				if accepts_gzip(accept_encoding) {
					return .gzip
				}
			}
			.deflate {
				if accepts_deflate(accept_encoding) {
					return .deflate
				}
			}
		}
		return none
	}
	
	// 自动选择：优先 gzip，其次 deflate
	if accepts_gzip(accept_encoding) {
		return .gzip
	}
	if accepts_deflate(accept_encoding) {
		return .deflate
	}
	
	return none
}

// accepts_gzip - 检查是否接受 gzip 编码
fn accepts_gzip(accept_encoding string) bool {
	return accept_encoding.contains('gzip') || accept_encoding.contains('*')
}

// accepts_deflate - 检查是否接受 deflate 编码
fn accepts_deflate(accept_encoding string) bool {
	return accept_encoding.contains('deflate') || accept_encoding.contains('*')
}

// compress_body - 压缩响应体
fn compress_body(body string, encoding CompressEncoding, level int) ![]u8 {
	data := body.bytes()
	
	match encoding {
		.gzip {
			return gzip.compress(data, gzip.CompressParams{
				compression_level: level
			})
		}
		.deflate {
			return zlib.compress(data)
		}
	}
}

// decompress_gzip - 解压 gzip 数据（用于测试）
pub fn decompress_gzip(data []u8) ![]u8 {
	return gzip.decompress(data)
}

// decompress_deflate - 解压 deflate 数据（用于测试）
pub fn decompress_deflate(data []u8) ![]u8 {
	return zlib.decompress(data)
}
