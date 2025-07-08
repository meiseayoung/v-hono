module hono

import net.http
import net.urllib
import os

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
	// 安全检查：防止路径遍历攻击
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
	
	// 读取文件内容
	file_content := os.read_file(file_path) or {
		c.status(500)
		return c.text('Internal Server Error')
	}
	
	// 获取文件信息
	file_info := os.stat(file_path) or {
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
		content_type := get_file_content_type(file_path)
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
	status_code    int = 0              // 自定义状态码，0表示使用默认200
	content_type   string = ''          // 自定义Content-Type
	last_modified  bool = true          // 是否设置Last-Modified头
	etag          bool = true           // 是否设置ETag头
	max_age       int = 0               // 缓存时间（秒）
	no_cache      bool = false          // 是否禁用缓存
	headers       map[string]string     // 自定义响应头
}

// 安全检查：防止路径遍历攻击
fn is_safe_file_path(path string) bool {
	// 检查是否包含 .. 或绝对路径
	if path.contains('..') || path.starts_with('/') || path.starts_with('\\') {
		return false
	}
	
	// 检查是否包含危险字符
	dangerous_chars := ['<', '>', ':', '"', '|', '?', '*']
	for dangerous_char in dangerous_chars {
		if path.contains(dangerous_char) {
			return false
		}
	}
	
	return true
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
