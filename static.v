module hono

import os
import net.http

// 静态文件服务配置
pub struct StaticOptions {
pub:
	root        string = './public'  // 静态文件根目录
	path        string = '/'         // URL路径前缀
	index       string = 'index.html' // 默认索引文件
	dotfiles    bool                  // 是否允许访问以.开头的文件
	etag        bool   = true        // 是否启用ETag
	last_modified bool = true        // 是否启用Last-Modified
	max_age     int                  // 缓存时间（秒）
	headers     map[string]string    // 自定义响应头
}

// 默认静态文件配置
pub fn default_static_options() StaticOptions {
	return StaticOptions{
		root: './public'
		path: '/'
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 0
		headers: map[string]string{}
	}
}

// 静态文件服务中间件
pub fn serve_static(options StaticOptions) fn (mut Context, fn (mut Context) http.Response) http.Response {
	return fn [options] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 检查请求路径是否匹配静态文件路径
		if !c.path.starts_with(options.path) {
			return next(mut c)
		}
		
		// 提取文件路径
		mut file_path := c.path[options.path.len..]
		if file_path.starts_with('/') {
			file_path = file_path[1..]
		}
		if file_path == '' {
			file_path = options.index
		}
		
		// 调试信息
		println('[DEBUG] Static file request:')
		println('  Path: ${c.path}')
		println('  Path prefix: ${options.path}')
		println('  File path: ${file_path}')
		println('  Root: ${options.root}')
		
		// 安全检查：防止路径遍历攻击
		// 注意：不检查文件扩展名，因为这可能是 API 路由而不是静态文件
		// 如果文件不存在，会在后面调用 next(mut c) 继续处理
		validation_options := PathValidationOptions{
			allow_absolute_paths: false
			allow_hidden_files: options.dotfiles
			check_file_extension: false  // 不检查扩展名，让文件存在性检查来决定
			allowed_base_paths: []
		}
		
		safe_file_path := validate_file_path(file_path, validation_options) or {
			println('  [DEBUG] Path validation failed: $err')
			// 路径验证失败（如包含 .. 等危险模式），传递给下一个处理器
			// 只有真正的安全问题才返回 403
			if err.msg().contains('Dangerous') {
				c.status(403)
				return c.text('Forbidden')
			}
			// 其他情况（如无扩展名）传递给下一个处理器
			return next(mut c)
		}
		
		// 检查是否允许访问点文件
		if !options.dotfiles && file_path.starts_with('.') {
			println('  [DEBUG] Dot file access blocked')
			c.status(403)
			return c.text('Forbidden')
		}
		
		// 构建完整的文件路径
		full_path := os.join_path(options.root, safe_file_path)
		println('  Full path: ${full_path}')
		
		// 检查文件是否存在
		if !os.exists(full_path) {
			println('  [DEBUG] File not found: ${full_path}')
			return next(mut c)
		}
		
		println('  [DEBUG] File found, serving...')
		
		// 检查是否为目录
		if os.is_dir(full_path) {
			// 尝试提供索引文件
			index_path := os.join_path(full_path, options.index)
			if os.exists(index_path) {
				return serve_file(mut c, index_path, options)
			}
			// 如果没有索引文件，返回404
			c.status(404)
			return c.text('Not Found')
		}
		
		// 提供文件
		return serve_file(mut c, full_path, options)
	}
}

// 提供单个文件
fn serve_file(mut c Context, file_path string, options StaticOptions) http.Response {
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
	c.status(200)
	
	// 设置Content-Type
	content_type := get_safe_content_type(file_path)
	c.headers['Content-Type'] = content_type
	
	// 设置Content-Length
	c.headers['Content-Length'] = file_content.len.str()
	
	// 设置Last-Modified
	if options.last_modified {
		last_modified := format_http_date(file_info.mtime)
		c.headers['Last-Modified'] = last_modified
	}
	
	// 设置ETag
	if options.etag {
		etag := generate_etag(file_content, file_info.mtime)
		c.headers['ETag'] = etag
		
		// 检查If-None-Match
		if_none_match := c.req.header.get_custom('If-None-Match') or { '' }
		if if_none_match == etag {
			c.status(304)
			// 构建响应头
			mut headers := http.new_header()
			headers.add_custom('Connection', 'keep-alive') or { }
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
	} else {
		c.headers['Cache-Control'] = 'no-cache'
	}
	
	// 设置自定义头部
	for key, value in options.headers {
		c.headers[key] = value
	}
	
	// 设置 Keep-Alive
	c.headers['Connection'] = 'keep-alive'
	
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

// 根据文件扩展名获取Content-Type
fn get_content_type(file_path string) string {
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

// 格式化HTTP日期
fn format_http_date(time i64) string {
	// 简化的HTTP日期格式化
	// 实际应用中可能需要更复杂的实现
	return time.str()
}

// 生成ETag
fn generate_etag(content string, mod_time i64) string {
	// 简化的ETag生成
	// 实际应用中可能需要更复杂的哈希算法
	return '"${content.len}-${mod_time}"'
}

// 便捷函数：使用默认配置的静态文件服务
pub fn serve_static_default() fn (mut Context, fn (mut Context) http.Response) http.Response {
	return serve_static(default_static_options())
}

// 便捷函数：指定根目录的静态文件服务
pub fn serve_static_root(root string) fn (mut Context, fn (mut Context) http.Response) http.Response {
	options := StaticOptions{
		root: root
		path: '/'
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 0
		headers: map[string]string{}
	}
	return serve_static(options)
}

// 便捷函数：指定路径前缀的静态文件服务
pub fn serve_static_path(path string, root string) fn (mut Context, fn (mut Context) http.Response) http.Response {
	options := StaticOptions{
		root: root
		path: path
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 0
		headers: map[string]string{}
	}
	return serve_static(options)
} 