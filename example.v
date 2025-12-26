import net.http
import hono
import os
import json
import strings

fn main() {
	println('🚀 V-Hono 完整示例启动中...')
	
	// 应用初始化
	mut app := hono.Hono.new()
	mut upload_manager := hono.new_chunk_upload_manager(hono.ChunkUploadConfig{})
	
	// 配置中间件
	setup_middleware(mut app)
	
	// 配置静态文件服务
	setup_static_file_services(mut app)
	
	// 配置分块上传功能
	setup_chunk_upload_routes(mut app, mut upload_manager)
	
	// 配置基础路由
	setup_basic_routes(mut app)
	
	// 配置API路由
	setup_api_routes(mut app)
	
	// 配置动态路由
	setup_dynamic_routes(mut app)
	
	// 配置HTTP方法示例
	setup_http_method_examples(mut app)
	
	// 配置文件服务功能
	setup_file_service_routes(mut app)
	
	// 配置错误处理
	setup_error_handling(mut app)
	
	// 打印启动信息
	print_startup_info()
	
	// 启动服务器
	app.listen(':8080')
}

// 配置中间件
fn setup_middleware(mut app hono.Hono) {
	// 错误处理中间件（最先添加）
	app.use(hono.error_handling_middleware())
	
	// 日志中间件
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println('[LOG] ${c.req.method} ${c.path}')
		return next(mut c)
	})
	
	// 认证中间件
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		println("url path: ${c.path}")
		token := c.query['token']
		if c.path != "/" &&  token == '' {
			return c.unauthorized('Token required for this endpoint')
		}
		return next(mut c)
	})
}

// 配置静态文件服务
fn setup_static_file_services(mut app hono.Hono) {
	// 默认静态文件服务（./public 目录）
	app.use(hono.serve_static_default())
	
	// 资源文件服务（./static 目录）
	app.use(hono.serve_static_path('/assets', './static'))
	
	// 上传文件服务（./uploads 目录）
	options := hono.StaticOptions{
		root: './uploads'
		path: '/files'
		index: 'index.html'
		dotfiles: false
		etag: true
		last_modified: true
		max_age: 3600  // 1小时缓存
		headers: {
			'X-Served-By': 'V-Hono'
			'X-Static-Files': 'true'
		}
	}
	app.use(hono.serve_static(options))
}
// 配置分块上传功能
fn setup_chunk_upload_routes(mut app hono.Hono, mut upload_manager hono.ChunkUploadManager) {
	// 分片上传接口
	app.post('/upload/chunk', fn [mut upload_manager] (mut c hono.Context) http.Response {
		return upload_manager.handle_chunk_upload(mut c)
	})

	// 查询上传状态接口
	app.get('/upload/status', fn [mut upload_manager] (mut c hono.Context) http.Response {
		return upload_manager.get_upload_status(mut c)
	})

	// 查询已上传分片接口
	app.get('/upload/chunks', fn [mut upload_manager] (mut c hono.Context) http.Response {
		return handle_upload_chunks_query(mut c, mut upload_manager)
	})

	// 检查分片是否存在接口（秒传功能）
	app.get('/upload/chunk_exists', fn [mut upload_manager] (mut c hono.Context) http.Response {
		return handle_chunk_exists_check(mut c, mut upload_manager)
	})

	// 文件管理API
	setup_file_management_api(mut app, mut upload_manager)
}

// 处理上传分片查询
fn handle_upload_chunks_query(mut c hono.Context, mut upload_manager hono.ChunkUploadManager) http.Response {
	file_hash := c.query['file_hash'] or {
		return c.missing_parameter('file_hash')
	}
	upload_status := upload_manager.uploads[file_hash] or {
		// 如果内存中没有记录，检查是否有最终文件（已完成上传）
		final_path := './uploads/${file_hash.trim_space()}'
		if os.exists(final_path) {
			// 文件已存在，返回所有分片已上传
			mut uploaded_chunks := []int{}
			uploaded_chunks << 0 // 假设只有一个分片
			return c.json('{"uploaded_chunks": ${json.encode(uploaded_chunks)}, "total_chunks": 1, "completed": true}')
		}
		return c.resource_not_found('upload', file_hash)
	}
	
	// 检查是否所有分片都已上传（使用分片大小记录文件）
	chunk_dir := os.join_path(os.join_path('./uploads/chunks', file_hash.trim_space()), upload_status.chunk_size.str())
	mut total_chunk_size := u64(0)
	mut chunk_count := upload_status.uploaded_chunks.len
	
	if os.exists(chunk_dir) {
		// 读取分片大小记录文件
		size_record_path := os.join_path(chunk_dir, 'total_size.record')
		if os.exists(size_record_path) {
			size_data := os.read_file(size_record_path) or { '0' }
			total_chunk_size = size_data.u64()
		}
	}
	
	is_completed := total_chunk_size >= u64(upload_status.file_size)
	
	return c.json('{"uploaded_chunks": ${json.encode(upload_status.uploaded_chunks)}, "total_chunks": $chunk_count, "completed": $is_completed}')
}

// 处理分片存在性检查
fn handle_chunk_exists_check(mut c hono.Context, mut upload_manager hono.ChunkUploadManager) http.Response {
	// 获取查询参数
	file_hash := c.query['file_hash'] or {
		return c.missing_parameter('file_hash')
	}
	chunk_index := c.query['chunk_index'] or {
		return c.missing_parameter('chunk_index')
	}
	file_size_str := c.query['file_size'] or {
		return c.missing_parameter('file_size')
	}
	file_size := file_size_str.int()

	// 确定分片大小
	trunk_size_str := c.query['trunk_size'] or { '' }
	mut chunk_size := upload_manager.config.chunk_size
	if trunk_size_str != '' {
		chunk_size = trunk_size_str.int()
	} else if upload_status := upload_manager.uploads[file_hash] {
		chunk_size = upload_status.chunk_size
	}

	// 构建分片路径
	chunk_path := os.join_path(os.join_path(os.join_path('./uploads/chunks', file_hash.trim_space()), chunk_size.str()), 'chunk_${chunk_index}.part')
	println('[DEBUG] Checking chunk: $chunk_path')
	
	// 清理无效的上传状态
	upload_manager.cleanup_invalid_status()
	
	exists := os.exists(chunk_path)
	println('[DEBUG] File exists: $exists')
	
	// 检查是否所有分片都已上传
	all_chunk_uploaded := check_all_chunks_uploaded(file_hash, file_size, chunk_size, mut upload_manager)
	println('[DEBUG] All chunk uploaded: $all_chunk_uploaded')
	
	return c.json('{"exists": $exists, "all_chunk_uploaded": $all_chunk_uploaded}')
}

// 检查所有分片是否已上传
fn check_all_chunks_uploaded(file_hash string, file_size int, chunk_size int, mut upload_manager hono.ChunkUploadManager) bool {
	mut all_chunk_uploaded := false
	
	// 方案1：优先检查最终文件是否存在
	uploads_dir := './uploads/files'
	if os.exists(uploads_dir) {
		// 从上传状态中获取文件扩展名
		mut file_ext := ''
		if upload_status := upload_manager.uploads[file_hash] {
			file_ext = get_file_extension(upload_status.filename)
		}
		
		// 如果内存中没有记录，尝试从数据库获取
		if file_ext == '' {
			if file_info := upload_manager.db.get_file_by_hash(file_hash) {
				file_ext = file_info.file_type
			}
		}
		
		// 构建最终文件名
		final_filename := '${file_hash.trim_space()}${file_ext}'
		final_path := os.join_path(uploads_dir, final_filename)
		
		if os.exists(final_path) {
			println('[DEBUG] Found final file: $final_path')
			return true
		}
	}
	
	// 方案2：如果最终文件不存在，检查分片文件
	chunk_dir := os.join_path(os.join_path('./uploads/chunks', file_hash.trim_space()), chunk_size.str())
	if os.exists(chunk_dir) {
		// 使用分片大小记录文件，避免遍历
		mut total_chunk_size := u64(0)
		mut chunk_count := 0
		
		// 读取分片大小记录文件
		size_record_path := os.join_path(chunk_dir, 'total_size.record')
		if os.exists(size_record_path) {
			size_data := os.read_file(size_record_path) or { '0' }
			total_chunk_size = size_data.u64()
		}
		
		// 从内存中的上传状态获取分片数量
		if upload_status := upload_manager.uploads[file_hash] {
			chunk_count = upload_status.uploaded_chunks.len
		} else {
			// 如果内存中没有状态，遍历分片文件来计算实际分片数量
			mut actual_chunk_count := 0
			for i := 0; ; i++ {
				chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')
				if os.exists(chunk_path) {
					actual_chunk_count++
				} else {
					break
				}
			}
			chunk_count = actual_chunk_count
		}
		
		// 使用传入的文件大小
		expected_file_size := u64(file_size)
		println('[DEBUG] Total chunk size: $total_chunk_size, Expected file size: $expected_file_size, Chunk count: $chunk_count')
		
		// 计算理论上需要的分片数量
		expected_chunks := (expected_file_size + u64(chunk_size) - 1) / u64(chunk_size)
		println('[DEBUG] Expected chunks: $expected_chunks')
		
		// 只有当分片数量达到预期且总大小 >= 文件大小时，才认为上传完成
		if chunk_count >= int(expected_chunks) && total_chunk_size >= expected_file_size {
			all_chunk_uploaded = true
			println('[DEBUG] All chunks uploaded: chunk_count=$chunk_count >= expected_chunks=$expected_chunks && total_size=$total_chunk_size >= file_size=$expected_file_size')
		} else {
			println('[DEBUG] Not all chunks uploaded: chunk_count=$chunk_count < expected_chunks=$expected_chunks || total_size=$total_chunk_size < file_size=$expected_file_size')
		}
	}
	
	return all_chunk_uploaded
}

// 配置文件管理API
fn setup_file_management_api(mut app hono.Hono, mut upload_manager hono.ChunkUploadManager) {
	// 获取所有文件信息
	app.get('/api/files', fn [mut upload_manager] (mut c hono.Context) http.Response {
		files := upload_manager.db.get_all_files() or {
			return c.database_error('get_all_files', err.msg())
		}
		return c.json(json.encode(files))
	})

	// 根据文件UUID获取文件信息
	app.get('/api/files/:uuid', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_uuid := c.params['uuid'] or {
			return c.missing_parameter('uuid')
		}
		
		file_info := upload_manager.db.get_file_by_uuid(file_uuid) or {
			return c.resource_not_found('file', file_uuid)
		}
		
		return c.json(json.encode(file_info))
	})

	// 根据文件hash获取文件信息
	app.get('/api/files/hash/:hash', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_hash := c.params['hash'] or {
			return c.missing_parameter('hash')
		}
		
		file_info := upload_manager.db.get_file_by_hash(file_hash) or {
			return c.resource_not_found('file', file_hash)
		}
		
		return c.json(json.encode(file_info))
	})

	// 删除文件信息
	app.delete('/api/files/:uuid', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_uuid := c.params['uuid'] or {
			return c.missing_parameter('uuid')
		}
		
		upload_manager.db.delete_file(file_uuid) or {
			return c.database_error('delete_file', err.msg())
		}
		
		return c.json('{"success": true, "message": "File deleted successfully"}')
	})

	// 获取上传配置信息
	app.get('/api/upload-config', fn [mut upload_manager] (mut c hono.Context) http.Response {
		config := {
			'chunk_size': upload_manager.config.chunk_size.str()
			'max_file_size': upload_manager.config.max_file_size.str()
			'max_chunk_size': upload_manager.config.max_chunk_size.str()
			'temp_dir': upload_manager.config.temp_dir
			'upload_dir': upload_manager.config.upload_dir
			'cleanup_delay': upload_manager.config.cleanup_delay.str()
			'clear_chunks_on_complete': upload_manager.config.clear_chunks_on_complete.str()
	}
	return c.json(json.encode(config))
})
}

// 配置基础路由
fn setup_basic_routes(mut app hono.Hono) {
	// 根路径 - 欢迎页面
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.html(generate_welcome_page())
	})
	
	// 基础路由
	app.get('/hello', fn (mut c hono.Context) http.Response {
		return c.text('Hello, World!')
	})
	
	// Path 信息展示路由
	app.get('/path-info', fn (mut c hono.Context) http.Response {
		// 使用字符串插值优化JSON构建
		response := '{"path_info": {"path": "${c.path}", "url": "${c.url}"}}'
		return c.json(response)
	})
}

// 配置API路由
fn setup_api_routes(mut app hono.Hono) {
	// 健康检查
	app.get('/api/health', fn (mut c hono.Context) http.Response {
		c.status(200)
		return c.json('{"status": "ok", "message": "Health check passed"}')
	})
	
	// 静态文件服务状态
	app.get('/api/status', fn (mut c hono.Context) http.Response {
		return c.json('{"status": "ok", "static_files": "enabled"}')
	})
	
	// 静态文件服务信息
	app.get('/api/static-info', fn (mut c hono.Context) http.Response {
		return c.json('{
			"static_directories": [
				{"path": "/", "root": "./public"},
				{"path": "/assets", "root": "./static"},
				{"path": "/files", "root": "./uploads"}
			],
			"features": [
				"Path traversal protection",
				"Auto index files",
				"ETag support",
				"Last-Modified headers",
				"Configurable caching",
				"Custom headers",
				"Chunk upload support"
			]
		}')
	})
}

// 配置动态路由
fn setup_dynamic_routes(mut app hono.Hono) {
	// 单参数路由
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		return c.json('{"user_id": "${user_id}", "name": "John Doe"}')
	})
	
	// 多参数路由
	app.get('/posts/:id/comments/:comment_id', fn (mut c hono.Context) http.Response {
		post_id := c.params['id']
		comment_id := c.params['comment_id']
		return c.json('{"post_id": "${post_id}", "comment_id": "${comment_id}", "content": "Great post!"}')
	})
	
	// 嵌套参数路由
	app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
		user_id := c.params['user_id']
		post_id := c.params['post_id']
		return c.json('{"user_id": "${user_id}", "post_id": "${post_id}", "title": "Sample Post"}')
	})
	
	// 路径分析路由
	app.get('/analyze/*path', fn (mut c hono.Context) http.Response {
		requested_path := c.params['path']
		
		// 使用字符串插值优化JSON构建
		response := '{"path_analysis": {"original_path": "${c.path}", "requested_path": "${requested_path}"}}'
		return c.json(response)
	})
}

// 配置HTTP方法示例
fn setup_http_method_examples(mut app hono.Hono) {
	// POST 请求
	app.post('/api/users', fn (mut c hono.Context) http.Response {
		println('=== POST 请求信息 ===')
		println('请求体: ${c.body}')
		println('查询参数: ${c.query}')
		
		c.status(201)
		return c.json('{"message": "User created", "data": "${c.body}"}')
	})
	
	// 带参数的 POST 请求
	app.post('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		
		println('=== 带参数的 POST 请求信息 ===')
		println('用户ID: ${user_id}')
		println('请求体: ${c.body}')
		println('查询参数: ${c.query}')
		
		c.status(200)
		return c.json('{"message": "User updated", "user_id": "${user_id}", "data": "${c.body}"}')
	})
	
	// 复杂的 POST 请求
	app.post('/api/test/:action/:id', fn (mut c hono.Context) http.Response {
		action := c.params['action']
		id := c.params['id']
		
		println('=== 复杂 POST 请求信息 ===')
		println('动作: ${action}')
		println('ID: ${id}')
		println('查询参数: ${c.query}')
		println('请求体: ${c.body}')
		
		// 使用strings.Builder优化JSON构建
		mut response := strings.new_builder(256)
		response.write_string('{"message": "复杂测试", "params": {"action": "${action}", "id": "${id}"}, "query": {')
		
		// 添加查询参数
		mut query_count := 0
		for key, value in c.query {
			if query_count > 0 {
				response.write_string(', ')
			}
			response.write_string('"${key}": "${value}"')
			query_count++
		}
		
		response.write_string('}, "body": "${c.body}"}')
		
		c.status(200)
		return c.json(response.str())
	})
	
	// 其他HTTP方法
	setup_other_http_methods(mut app)
}

// 配置其他HTTP方法
fn setup_other_http_methods(mut app hono.Hono) {
	// PUT 请求示例
	app.put('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		c.status(200)
		return c.json('{"message": "User replaced", "user_id": "${user_id}", "data": "${c.body}"}')
	})
	
	// DELETE 请求示例
	app.delete('/api/users/:id', fn (mut c hono.Context) http.Response {
		_ := c.params['id'] // 忽略用户ID
		c.status(204)
		return c.text('')
	})
	
	// PATCH 请求示例
	app.patch('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		c.status(200)
		return c.json('{"message": "User partially updated", "user_id": "${user_id}", "data": "${c.body}"}')
	})
	
	// HEAD 请求示例
	app.head('/api/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id']
		c.headers['X-User-ID'] = user_id
		c.status(200)
		return c.text('')
	})
	
	// OPTIONS 请求示例
	app.options('/api/users/:id', fn (mut c hono.Context) http.Response {
		c.headers['Allow'] = 'GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS'
		c.headers['Access-Control-Allow-Origin'] = '*'
		c.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS'
		c.status(200)
		return c.text('')
	})
}

// 配置文件服务功能
fn setup_file_service_routes(mut app hono.Hono) {
	// 基本文件服务示例
	app.get('/file/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		file_path := 'public/${filename}'
		return c.file(file_path)
	})
	
	// 带选项的文件服务示例
	app.get('/file-cached/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		file_path := 'public/${filename}'
		
		options := hono.FileOptions{
			max_age: 3600  // 缓存1小时
			headers: {
				'X-Served-By': 'v-hono'
			}
		}
		
		return c.file_with_options(file_path, options)
	})
	
	// 自定义Content-Type的文件服务
	app.get('/download/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		file_path := 'uploads/${filename}'
		
		options := hono.FileOptions{
			content_type: 'application/octet-stream'
			headers: {
				'Content-Disposition': 'attachment; filename="${filename}"'
			}
		}
		
		return c.file_with_options(file_path, options)
	})
	
	// 图片文件服务示例
	app.get('/image/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		file_path := 'static/${filename}'
		
		options := hono.FileOptions{
			max_age: 86400  // 缓存24小时
			headers: {
				'X-Image-Type': 'static'
			}
		}
		
		return c.file_with_options(file_path, options)
	})
	
	// 禁用缓存的文件服务
	app.get('/dynamic/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		file_path := 'dynamic/${filename}'
		
		options := hono.FileOptions{
			no_cache: true
			headers: {
				'X-Dynamic': 'true'
			}
		}
		
		return c.file_with_options(file_path, options)
	})
}

// 配置错误处理
fn setup_error_handling(mut app hono.Hono) {
	// 安全文件服务
	app.get('/safe-file/:filename', fn (mut c hono.Context) http.Response {
		filename := c.params['filename']
		
		// 安全检查：只允许访问特定目录
		if filename.contains('..') || filename.starts_with('/') {
			return c.forbidden('Access denied: unsafe file path')
		}
		
		file_path := 'public/${filename}'
		return c.file(file_path)
	})
	
	// 404 错误处理
	app.get('/**', fn (mut c hono.Context) http.Response {
		return c.not_found('The requested resource was not found')
	})
}

// 生成欢迎页面HTML
fn generate_welcome_page() string {
	return '<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>V-Hono 完整示例</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .endpoint { background: #f5f5f5; padding: 10px; margin: 5px 0; border-radius: 3px; }
        .feature { color: #2c5aa0; font-weight: bold; }
        .static-section { background: #e8f4fd; border-left: 4px solid #2196F3; }
        .api-section { background: #f3e5f5; border-left: 4px solid #9C27B0; }
        .file-section { background: #e8f5e8; border-left: 4px solid #4CAF50; }
        .route-section { background: #fff3e0; border-left: 4px solid #FF9800; }
        .upload-section { background: #fff8e1; border-left: 4px solid #FFC107; }
    </style>
</head>
<body>
    <h1>🚀 V-Hono 完整示例</h1>
    <p>A lightweight web framework for V with static file serving and chunk upload</p>
    
    <div class="section static-section">
        <h2>📁 静态文件服务</h2>
        <div class="endpoint">
            <strong>默认目录:</strong> <code>/</code> → <code>./public</code>
        </div>
        <div class="endpoint">
            <strong>资源目录:</strong> <code>/assets</code> → <code>./static</code>
        </div>
        <div class="endpoint">
            <strong>文件目录:</strong> <code>/files</code> → <code>./uploads</code>
        </div>
        <p><strong>测试文件:</strong></p>
        <ul>
            <li><a href="/test.txt">/test.txt</a> (来自 ./public/test.txt)</li>
            <li><a href="/assets/style.css">/assets/style.css</a> (来自 ./static/style.css)</li>
            <li><a href="/files/sample.json">/files/sample.json</a> (来自 ./uploads/sample.json)</li>
        </ul>
    </div>
    
    <div class="section api-section">
        <h2>🔧 API 端点</h2>
        <div class="endpoint">
            <strong>健康检查:</strong> <a href="/api/health">/api/health</a>
        </div>
        <div class="endpoint">
            <strong>静态文件状态:</strong> <a href="/api/status">/api/status</a>
        </div>
        <div class="endpoint">
            <strong>静态文件信息:</strong> <a href="/api/static-info">/api/static-info</a>
        </div>
        <div class="endpoint">
            <strong>基础路由:</strong> <a href="/hello">/hello</a>
        </div>
    </div>
    
    <div class="section file-section">
        <h2>📄 文件服务端点</h2>
        <div class="endpoint">
            <strong>基本文件服务:</strong> <a href="/file/test.txt">/file/test.txt</a>
        </div>
        <div class="endpoint">
            <strong>缓存文件服务:</strong> <a href="/file-cached/test.txt">/file-cached/test.txt</a>
        </div>
        <div class="endpoint">
            <strong>文件下载:</strong> <a href="/download/downloadable.txt">/download/downloadable.txt</a>
        </div>
        <div class="endpoint">
            <strong>图片文件服务:</strong> <a href="/image/style.css">/image/style.css</a>
        </div>
        <div class="endpoint">
            <strong>安全文件服务:</strong> <a href="/safe-file/test.txt">/safe-file/test.txt</a>
        </div>
    </div>
    
    <div class="section route-section">
        <h2>🎯 动态路由示例</h2>
        <div class="endpoint">
            <strong>单参数:</strong> <a href="/users/123">/users/123</a>
        </div>
        <div class="endpoint">
            <strong>多参数:</strong> <a href="/posts/456/comments/789">/posts/456/comments/789</a>
        </div>
        <div class="endpoint">
            <strong>嵌套参数:</strong> <a href="/api/users/101/posts/202">/api/users/101/posts/202</a>
        </div>
    </div>
    
    <div class="section upload-section">
        <h2>📤 分块上传功能</h2>
        <div class="endpoint">
            <strong>分片上传:</strong> <a href="/upload/chunk">POST /upload/chunk</a>
        </div>
        <div class="endpoint">
            <strong>上传状态:</strong> <a href="/upload/status">GET /upload/status</a>
        </div>
        <div class="endpoint">
            <strong>分片查询:</strong> <a href="/upload/chunks">GET /upload/chunks</a>
        </div>
        <div class="endpoint">
            <strong>分片检查:</strong> <a href="/upload/chunk_exists">GET /upload/chunk_exists</a>
        </div>
        <div class="endpoint">
            <strong>文件管理:</strong> <a href="/api/files">GET /api/files</a>
        </div>
        <p><strong>特性:</strong></p>
        <ul>
            <li class="feature">🚀 大文件分片上传</li>
            <li class="feature">🔄 断点续传</li>
            <li class="feature">⚡ 秒传功能</li>
            <li class="feature">📊 上传进度监控</li>
            <li class="feature">🛡️ 文件完整性验证</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>✨ 特性</h2>
        <ul>
            <li class="feature">🚀 高性能路由系统（Trie + Hybrid）</li>
            <li class="feature">🛡️ 路径遍历攻击防护</li>
            <li class="feature">📁 自动索引文件支持</li>
            <li class="feature">🔒 点文件访问控制</li>
            <li class="feature">🏷️ ETag 和 Last-Modified 支持</li>
            <li class="feature">💾 可配置缓存策略</li>
            <li class="feature">🎯 智能 Content-Type 检测</li>
            <li class="feature">🔧 洋葱模型中间件</li>
            <li class="feature">🔄 支持所有 HTTP 方法</li>
            <li class="feature">📊 路由性能统计</li>
            <li class="feature">📤 分块上传支持</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>🧪 测试命令</h2>
        <pre>
# 静态文件测试
curl http://localhost:8080/test.txt
curl http://localhost:8080/assets/style.css
curl http://localhost:8080/files/sample.json

# 文件服务测试
curl http://localhost:8080/file/test.txt
curl http://localhost:8080/file-cached/test.txt
curl http://localhost:8080/download/downloadable.txt
curl http://localhost:8080/image/style.css
curl http://localhost:8080/safe-file/test.txt

# API 测试
curl http://localhost:8080/api/health
curl http://localhost:8080/api/status
curl http://localhost:8080/hello

# 动态路由测试
curl http://localhost:8080/users/123
curl http://localhost:8080/posts/456/comments/789

# 分块上传测试
curl -X POST http://localhost:8080/upload/chunk -F "file_hash=test123" -F "chunk_index=0" -F "chunk=@test.txt"
curl http://localhost:8080/upload/status?file_hash=test123
curl http://localhost:8080/api/files

# POST 测试
curl -X POST http://localhost:8080/api/users -d "{\\"name\\":\\"John\\"}"
curl -X POST "http://localhost:8080/api/test/create/456?token=abc123" -d "{\\"name\\":\\"Test\\"}"
        </pre>
    </div>
</body>
</html>'
}

// 打印启动信息
fn print_startup_info() {
	println('📍 服务器地址: http://localhost:8080')
	println('')
	println('📁 静态文件服务:')
	println('  - 默认: ./public (访问路径: /)')
	println('  - 资源: ./static (访问路径: /assets)')
	println('  - 文件: ./uploads (访问路径: /files)')
	println('')
	println('🔧 API 端点:')
	println('  - GET /api/health')
	println('  - GET /api/status')
	println('  - GET /api/static-info')
	println('  - GET /hello')
	println('  - GET /path-info')
	println('  - GET /analyze/*path')
	println('')
	println('📄 文件服务端点:')
	println('  - GET /file/:filename - 基本文件服务')
	println('  - GET /file-cached/:filename - 缓存文件服务')
	println('  - GET /download/:filename - 文件下载')
	println('  - GET /image/:filename - 图片文件服务')
	println('  - GET /dynamic/:filename - 动态文件服务')
	println('  - GET /safe-file/:filename - 安全文件服务')
	println('')
	println('📤 分块上传端点:')
	println('  - POST /upload/chunk - 分片上传')
	println('  - GET /upload/status - 上传状态')
	println('  - GET /upload/chunks - 分片查询')
	println('  - GET /upload/chunk_exists - 分片检查')
	println('  - GET /api/files - 文件管理')
	println('')
	println('🎯 动态路由:')
	println('  - GET /users/123')
	println('  - GET /posts/456/comments/789')
	println('  - GET /api/users/101/posts/202')
	println('')
	println('📝 HTTP 方法示例:')
	println('  - POST /api/users')
	println('  - POST /api/users/123')
	println('  - POST /api/test/create/456')
	println('  - PUT /api/users/123')
	println('  - DELETE /api/users/123')
	println('  - PATCH /api/users/123')
	println('  - HEAD /api/users/123')
	println('  - OPTIONS /api/users/123')
}

// 获取文件扩展名
fn get_file_extension(filename string) string {
	println('[DEBUG] Getting extension for filename: "$filename"')
	parts := filename.split('.')
	println('[DEBUG] Split parts: $parts')
	if parts.len > 1 {
		ext := '.${parts.last()}'
		println('[DEBUG] Extracted extension: "$ext"')
		return ext
	}
	println('[DEBUG] No extension found, returning empty string')
	return ''
} 