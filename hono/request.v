module hono

import net.http
import net.urllib
import os
import strings

// Context 结构体，类似 Hono.js 的实现
pub struct Context {
pub:
	req    http.Request
	params map[string]string
	query  map[string]string
	url    string
	path   string  // 当前请求的路径
pub mut:
	status_code int = 200
	headers     map[string]string
	body        string
}

// Context 构造函数
pub fn Context.new(req http.Request, params map[string]string, query map[string]string, body string) Context {
	// 解析URL获取路径
	url := urllib.parse(req.url) or {
		urllib.URL{
			path: '/'
		}
	}
	return Context{
		req: req
		params: params
		query: query
		body: body
		url: url.str()  // 设置为完整的URL字符串
		path: url.path  // 设置 path 属性
		headers: map[string]string{}
	}
}

// Context 的便捷方法 - 直接返回 http.Response
pub fn (mut c Context) json(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'application/json; charset=utf-8') or { }
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

pub fn (mut c Context) text(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/plain; charset=utf-8') or { }
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

pub fn (mut c Context) html(data string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/html; charset=utf-8') or { }
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: data
	}
}

// file method - serve a file directly from the context
pub fn (mut c Context) file(file_path string) http.Response {
	return c.file_with_options(file_path, FileOptions{})
}

// file_with_options method - serve a file with custom options
pub fn (mut c Context) file_with_options(file_path string, options FileOptions) http.Response {
	// 增强的安全检查
	validation_options := PathValidationOptions{
		allow_absolute_paths: false
		allow_hidden_files: false
		check_file_extension: true
	}
	
	safe_file_path := validate_file_path(file_path, validation_options) or {
		c.status(403)
		return c.text('Forbidden: $err')
	}
	
	// 检查文件是否存在
	if !os.exists(safe_file_path) {
		c.status(404)
		return c.text('File Not Found')
	}
	
	// 检查是否为目录
	if os.is_dir(safe_file_path) {
		c.status(400)
		return c.text('Cannot serve directory')
	}
	
	// 读取文件内容
	file_content := os.read_file(safe_file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	// 获取文件信息
	file_info := os.stat(safe_file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	// 设置状态码
	if options.status_code > 0 {
		c.status(options.status_code)
	} else {
		c.status(200)
	}
	
	// 设置Content-Type
	if options.content_type != '' {
		c.headers['Content-Type'] = options.content_type
	} else {
		content_type := get_safe_content_type(safe_file_path)
		c.headers['Content-Type'] = content_type
	}
	
	// 设置Content-Length
	c.headers['Content-Length'] = file_content.len.str()
	
	// 设置Last-Modified
	if options.last_modified {
		last_modified := format_http_date(file_info.mtime)
		c.headers['Last-Modified'] = last_modified
	}
	
	// 设置ETag
	if options.etag {
		etag := generate_file_etag(file_content, file_info.mtime)
		c.headers['ETag'] = etag
		
		// 检查If-None-Match
		if_none_match := c.req.header.get_custom('If-None-Match') or { '' }
		if if_none_match == etag {
			c.status(304)
			// 构建响应头
			mut headers := http.new_header()
			for key, value in c.headers {
				headers.add_custom(key, value) or { continue }
			}
			return http.Response{
				status_code: c.status_code
				header: headers
				body: ''
			}
		}
	}
	
	// 设置Cache-Control
	if options.max_age > 0 {
		c.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
	} else if options.no_cache {
		c.headers['Cache-Control'] = 'no-cache'
	}
	
	// 设置自定义头部
	for key, value in options.headers {
		c.headers[key] = value
	}
	
	// 返回文件内容
	mut headers := http.new_header()
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: file_content
	}
}

// FileOptions struct for configuring file serving
pub struct FileOptions {
pub:
	status_code    int              // 自定义状态码，0表示使用默认200
	content_type   string          // 自定义Content-Type
	last_modified  bool = true          // 是否设置Last-Modified头
	etag          bool = true           // 是否设置ETag头
	max_age       int               // 缓存时间（秒）
	no_cache      bool          // 是否禁用缓存
	headers       map[string]string     // 自定义响应头
	// 流式传输配置
	stream_threshold u64 = 50 * 1024 * 1024  // 50MB，超过此大小使用流式传输
	buffer_size      int = 8192              // 流式传输缓冲区大小（8KB）
	enable_range     bool = true             // 是否支持Range请求
	compress         bool                    // 是否启用压缩（对流式传输）
}

// 根据文件扩展名获取Content-Type
fn get_file_content_type(file_path string) string {
	ext := os.file_ext(file_path).to_lower()
	
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
		else { return 'application/octet-stream' }
	}
}

// 生成ETag
fn generate_file_etag(content string, mod_time i64) string {
	// 简化的ETag生成
	// 实际应用中可能需要更复杂的哈希算法
	return '"${content.len}-${mod_time}"'
}

pub fn (mut c Context) status(code int) {
	c.status_code = code
}



// 处理器接口，使用 Context
pub interface IHandler {
	path string
	handle(mut c Context) http.Response
}

// 泛型处理器类型，使用 Context
pub type ContextHandlerFn = fn (mut Context) http.Response

// Context 处理器结构体
pub struct ContextHandler {
pub:
	path    string
	handler fn (mut Context) http.Response = unsafe { nil }
}

// 实现 IHandler 接口
pub fn (ch ContextHandler) handle(mut c Context) http.Response {
	return ch.handler(mut c)
}

// Range 请求结构体
struct RangeRequest {
	start u64
	end   u64
	total u64
}

// 解析 Range 请求头
fn parse_range_header(range_header string, file_size u64) ?RangeRequest {
	if !range_header.starts_with('bytes=') {
		return none
	}
	
	range_part := range_header[6..] // 移除 'bytes=' 前缀
	parts := range_part.split('-')
	
	if parts.len != 2 {
		return none
	}
	
	start_str := parts[0].trim_space()
	end_str := parts[1].trim_space()
	
	mut start := u64(0)
	mut end := file_size - 1
	
	if start_str != '' {
		start = start_str.u64()
	}
	
	if end_str != '' {
		end = end_str.u64()
		if end >= file_size {
			end = file_size - 1
		}
	}
	
	if start > end || start >= file_size {
		return none
	}
	
	return RangeRequest{
		start: start
		end: end
		total: file_size
	}
}

// 流式文件传输方法
pub fn (mut c Context) file_stream(file_path string) http.Response {
	return c.file_stream_with_options(file_path, FileOptions{})
}

// 带选项的流式文件传输方法
pub fn (mut c Context) file_stream_with_options(file_path string, options FileOptions) http.Response {
	// 安全检查
	if !is_safe_file_path(file_path) {
		c.status(403)
		return c.text('Forbidden')
	}
	
	// 检查文件是否存在
	if !os.exists(file_path) {
		c.status(404)
		return c.text('File Not Found')
	}
	
	// 检查是否为目录
	if os.is_dir(file_path) {
		c.status(400)
		return c.text('Cannot serve directory')
	}
	
	// 获取文件信息
	file_info := os.stat(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	file_size := u64(file_info.size)
	
	// 检查是否处理 Range 请求
	mut range_req := ?RangeRequest(none)
	if options.enable_range {
		if range_header := c.req.header.get_custom('Range') {
			range_req = parse_range_header(range_header, file_size)
		}
	}
	
	// 设置基本响应头
	if options.content_type != '' {
		c.headers['Content-Type'] = options.content_type
	} else {
		content_type := get_file_content_type(file_path)
		c.headers['Content-Type'] = content_type
	}
	
	// 设置缓存相关头部
	if options.last_modified {
		last_modified := format_http_date(file_info.mtime)
		c.headers['Last-Modified'] = last_modified
	}
	
	if options.max_age > 0 {
		c.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
	} else if options.no_cache {
		c.headers['Cache-Control'] = 'no-cache'
	}
	
	// 设置自定义头部
	for key, value in options.headers {
		c.headers[key] = value
	}
	
	// 处理 Range 请求
	if range_request := range_req {
		return c.handle_range_request(file_path, range_request, options)
	}
	
	// 设置完整文件响应头
	c.headers['Content-Length'] = file_size.str()
	c.headers['Accept-Ranges'] = 'bytes'
	
	// 如果文件较小，直接读取到内存
	if file_size <= options.stream_threshold {
		file_content := os.read_file(file_path) or {
			c.status(500)
			return c.text('Internal Server Error')
		}
		
		// 设置ETag（仅对小文件）
		if options.etag {
			etag := generate_file_etag(file_content, file_info.mtime)
			c.headers['ETag'] = etag
			
			// 检查If-None-Match
			if_none_match := c.req.header.get_custom('If-None-Match') or { '' }
			if if_none_match == etag {
				c.status(304)
				return c.build_headers_response('')
			}
		}
		
		c.status(200)
		return c.build_headers_response(file_content)
	}
	
	// 大文件使用流式传输
	c.status(200)
	return c.stream_large_file(file_path, file_size, options)
}

// 处理 Range 请求
fn (mut c Context) handle_range_request(file_path string, range_req RangeRequest, options FileOptions) http.Response {
	content_length := range_req.end - range_req.start + 1
	
	// 设置 Range 响应头
	c.status(206) // Partial Content
	c.headers['Content-Length'] = content_length.str()
	c.headers['Content-Range'] = 'bytes ${range_req.start}-${range_req.end}/${range_req.total}'
	c.headers['Accept-Ranges'] = 'bytes'
	
	// 读取指定范围的文件内容
	mut file := os.open(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	defer { file.close() }
	
	// 跳转到起始位置
	file.seek(int(range_req.start), .start) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	// 读取范围内容
	mut buffer := []u8{len: int(content_length)}
	bytes_read := file.read(mut buffer) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	if bytes_read != int(content_length) {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	return c.build_headers_response(buffer.bytestr())
}

// 流式传输大文件
fn (mut c Context) stream_large_file(file_path string, file_size u64, options FileOptions) http.Response {
	// 注意：V语言的http.Response不直接支持流式传输
	// 这里我们实现一个分块读取的方法，但仍需要将整个文件读入内存
	// 对于真正的流式传输，需要在框架层面支持
	
	mut file := os.open(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	defer { file.close() }
	
	mut content := strings.new_builder(int(file_size))
	mut buffer := []u8{len: options.buffer_size}
	
	for {
		bytes_read := file.read(mut buffer) or { break }
		if bytes_read == 0 {
			break
		}
		content.write(buffer[..bytes_read]) or { break }
		if bytes_read < options.buffer_size {
			break
		}
	}
	
	return c.build_headers_response(content.str())
}

// 构建带头部的响应
fn (mut c Context) build_headers_response(body string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Connection', 'keep-alive') or { }
	for key, value in c.headers {
		headers.add_custom(key, value) or { continue }
	}
	return http.Response{
		status_code: c.status_code
		header: headers
		body: body
	}
}

// 智能文件服务方法（自动选择流式或内存传输）
pub fn (mut c Context) file_smart(file_path string) http.Response {
	return c.file_smart_with_options(file_path, FileOptions{})
}

// 带选项的智能文件服务方法
pub fn (mut c Context) file_smart_with_options(file_path string, options FileOptions) http.Response {
	// 获取文件大小
	if !os.exists(file_path) {
		c.status(404)
		return c.text('File Not Found')
	}
	
	file_info := os.stat(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	file_size := u64(file_info.size)
	
	// 根据文件大小选择传输方式
	if file_size > options.stream_threshold {
		return c.file_stream_with_options(file_path, options)
	} else {
		return c.file_with_options(file_path, options)
	}
}

