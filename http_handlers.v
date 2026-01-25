module hono

import net.http
import x.json2
import os
import time

// ============================================================================
// HTTP 请求/响应结构
// ============================================================================

// 文件上传请求（JSON 格式）
pub struct UploadRequest {
pub:
	bucket       string @[json: 'bucket']
	filename     string @[json: 'filename']
	content_type string @[json: 'content_type']
	metadata     string @[json: 'metadata']
}

// 分片上传初始化请求
pub struct InitMultipartRequest {
pub:
	bucket       string @[json: 'bucket']
	filename     string @[json: 'filename']
	file_size    i64    @[json: 'file_size']
	content_type string @[json: 'content_type']
	chunk_size   int    @[json: 'chunk_size']
}

// 分片上传完成请求
pub struct CompleteMultipartRequest {
pub:
	upload_id string @[json: 'upload_id']
}

// 分片上传取消请求
pub struct AbortMultipartRequest {
pub:
	upload_id string @[json: 'upload_id']
}

// 预签名 URL 请求
pub struct PresignRequest {
pub:
	file_uuid  string @[json: 'file_uuid']
	expires_in int    @[json: 'expires_in']
	method     string @[json: 'method']
}

// 文件列表请求
pub struct ListFilesRequest {
pub:
	bucket       string @[json: 'bucket']
	prefix       string @[json: 'prefix']
	storage_type string @[json: 'storage_type']
	limit        int    @[json: 'limit']
	offset       int    @[json: 'offset']
}

// 通用 API 响应
pub struct StorageApiResponse {
pub:
	success bool   @[json: 'success']
	message string @[json: 'message']
	data    string @[json: 'data'] // JSON 编码的数据
}

// 存储错误响应
pub struct StorageErrorResponse {
pub:
	success bool   @[json: 'success']
	error   string @[json: 'error']
	code    int    @[json: 'code']
}

// ============================================================================
// HTTP 处理器
// ============================================================================

// 处理文件上传（单文件）
// POST /upload
// Content-Type: multipart/form-data
// 表单字段: file (文件), bucket (可选), metadata (可选 JSON)
pub fn (mut fs FileService) handle_upload(mut ctx Context) http.Response {
	// 解析 multipart 表单数据
	content_type := ctx.req.header.get(.content_type) or { '' }
	
	if !content_type.starts_with('multipart/form-data') {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Content-Type must be multipart/form-data'
			code: 400
		}))
	}
	
	// 使用 v-hono 的 multipart 解析器
	parser := new_multipart_parser(content_type, ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to parse multipart data: ${err}'
			code: 400
		}))
	}
	
	items := parser.parse() or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to parse form data: ${err}'
			code: 400
		}))
	}
	
	// 提取表单字段
	mut file_data := []u8{}
	mut filename := ''
	mut file_content_type := 'application/octet-stream'
	mut bucket := ''
	mut metadata := ''
	
	for item in items {
		match item.name {
			'file' {
				file_data = item.content.bytes()
				filename = item.filename
				if item.content_type != '' {
					file_content_type = item.content_type
				}
			}
			'bucket' {
				bucket = item.content
			}
			'metadata' {
				metadata = item.content
			}
			'content_type' {
				file_content_type = item.content
			}
			else {}
		}
	}
	
	if file_data.len == 0 || filename == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file data or filename'
			code: 400
		}))
	}
	
	// 上传文件
	result := fs.upload_file(UploadParams{
		bucket: bucket
		filename: filename
		content_type: file_content_type
		metadata: metadata
	}, file_data) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Upload failed: ${err}'
			code: 500
		}))
	}
	
	ctx.status(201)
	return ctx.json(json2.encode[UploadResult](result))
}

// 处理文件下载
// GET /download/:file_uuid
pub fn (mut fs FileService) handle_download(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	// 获取文件信息
	file_info := fs.get_file_info(file_uuid) or {
		ctx.status(404)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'File not found: ${err}'
			code: 404
		}))
	}
	
	// 检查 Range 请求
	range_header := ctx.req.header.get_custom('Range') or { '' }
	
	if range_header != '' {
		return fs.handle_range_download(mut ctx, file_info, range_header)
	}
	
	// 下载文件
	data := fs.download_file(file_uuid) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Download failed: ${err}'
			code: 500
		}))
	}
	
	// 设置响应头
	ctx.headers['Content-Type'] = file_info.file_type
	ctx.headers['Content-Length'] = data.len.str()
	ctx.headers['Content-Disposition'] = 'attachment; filename="${file_info.file_name}"'
	ctx.headers['Accept-Ranges'] = 'bytes'
	ctx.headers['ETag'] = '"${file_info.file_hash}"'
	
	ctx.status(200)
	mut headers := http.new_header()
	for key, value in ctx.headers {
		headers.add_custom(key, value) or { continue }
	}
	
	return http.Response{
		status_code: 200
		header: headers
		body: data.bytestr()
	}
}

// 处理 Range 请求下载
fn (mut fs FileService) handle_range_download(mut ctx Context, file_info FileInfo, range_header string) http.Response {
	// 解析 Range 头
	if !range_header.starts_with('bytes=') {
		ctx.status(416)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid Range header'
			code: 416
		}))
	}
	
	range_spec := range_header[6..]
	parts := range_spec.split('-')
	if parts.len != 2 {
		ctx.status(416)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid Range format'
			code: 416
		}))
	}
	
	file_size := file_info.file_size
	mut start := i64(0)
	mut end := file_size - 1
	
	if parts[0] != '' {
		start = parts[0].i64()
	}
	if parts[1] != '' {
		end = parts[1].i64()
	}
	
	// 验证范围
	if start < 0 || start >= file_size || end < start || end >= file_size {
		ctx.status(416)
		ctx.headers['Content-Range'] = 'bytes */${file_size}'
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Range not satisfiable'
			code: 416
		}))
	}
	
	// 下载完整文件
	data := fs.download_file(file_info.file_uuid) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Download failed: ${err}'
			code: 500
		}))
	}
	
	// 提取范围数据
	range_data := data[int(start)..int(end) + 1]
	content_length := end - start + 1
	
	// 设置响应头
	ctx.headers['Content-Type'] = file_info.file_type
	ctx.headers['Content-Length'] = content_length.str()
	ctx.headers['Content-Range'] = 'bytes ${start}-${end}/${file_size}'
	ctx.headers['Accept-Ranges'] = 'bytes'
	ctx.headers['ETag'] = '"${file_info.file_hash}"'
	
	ctx.status(206)
	mut headers := http.new_header()
	for key, value in ctx.headers {
		headers.add_custom(key, value) or { continue }
	}
	
	return http.Response{
		status_code: 206
		header: headers
		body: range_data.bytestr()
	}
}

// 处理文件删除
// DELETE /files/:file_uuid
pub fn (mut fs FileService) handle_delete(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	// 删除文件
	fs.delete_file(file_uuid) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Delete failed: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[StorageApiResponse](StorageApiResponse{
		success: true
		message: 'File deleted successfully'
		data: ''
	}))
}


// ============================================================================
// 分片上传处理器
// ============================================================================

// 初始化分片上传
// POST /multipart/init
pub fn (mut fs FileService) handle_init_multipart(mut ctx Context) http.Response {
	// 解析请求体
	req := json2.decode[InitMultipartRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.filename == '' || req.file_size <= 0 {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing required fields: filename and file_size'
			code: 400
		}))
	}
	
	// 生成对象键
	object_key := generate_multipart_object_key(req.filename)
	
	// 初始化分片上传
	upload := fs.init_multipart_upload(InitMultipartParams{
		bucket: req.bucket
		object_key: object_key
		file_name: req.filename
		file_size: req.file_size
		content_type: req.content_type
		chunk_size: req.chunk_size
	}) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to init multipart upload: ${err}'
			code: 500
		}))
	}
	
	ctx.status(201)
	return ctx.json(json2.encode[MultipartUpload](upload))
}

// 上传分片
// POST /multipart/upload/:upload_id/:part_number
pub fn (mut fs FileService) handle_upload_part(mut ctx Context) http.Response {
	upload_id := ctx.params['upload_id'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id parameter'
			code: 400
		}))
	}
	
	part_number_str := ctx.params['part_number'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing part_number parameter'
			code: 400
		}))
	}
	
	part_number := part_number_str.int()
	if part_number < 1 {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid part_number: must be >= 1'
			code: 400
		}))
	}
	
	// 获取分片数据
	data := ctx.body.bytes()
	if data.len == 0 {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Empty part data'
			code: 400
		}))
	}
	
	// 上传分片
	result := fs.upload_part(upload_id, part_number, data) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to upload part: ${err}'
			code: 500
		}))
	}
	
	if !result.success {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: result.error_msg
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[ChunkUploadResult](result))
}

// 完成分片上传
// POST /multipart/complete
pub fn (mut fs FileService) handle_complete_multipart(mut ctx Context) http.Response {
	// 解析请求体
	req := json2.decode[CompleteMultipartRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.upload_id == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id'
			code: 400
		}))
	}
	
	// 完成上传
	result := fs.complete_multipart_upload(req.upload_id) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to complete multipart upload: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[StorageResult](result))
}

// 取消分片上传
// POST /multipart/abort
pub fn (mut fs FileService) handle_abort_multipart(mut ctx Context) http.Response {
	// 解析请求体
	req := json2.decode[AbortMultipartRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.upload_id == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id'
			code: 400
		}))
	}
	
	// 取消上传
	fs.abort_multipart_upload(req.upload_id) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to abort multipart upload: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[StorageApiResponse](StorageApiResponse{
		success: true
		message: 'Multipart upload aborted'
		data: ''
	}))
}

// 获取上传进度
// GET /multipart/progress/:upload_id
pub fn (fs FileService) handle_upload_progress(mut ctx Context) http.Response {
	upload_id := ctx.params['upload_id'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing upload_id parameter'
			code: 400
		}))
	}
	
	// 获取进度
	progress := fs.get_upload_progress(upload_id) or {
		ctx.status(404)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Upload not found: ${err}'
			code: 404
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[UploadProgress](progress))
}


// ============================================================================
// 文件列表和元数据处理器
// ============================================================================

// 获取文件列表
// GET /files?bucket=xxx&prefix=xxx&limit=100&offset=0
pub fn (fs FileService) handle_list_files(mut ctx Context) http.Response {
	bucket := ctx.query['bucket'] or { '' }
	prefix := ctx.query['prefix'] or { '' }
	storage_type := ctx.query['storage_type'] or { '' }
	limit_str := ctx.query['limit'] or { '100' }
	offset_str := ctx.query['offset'] or { '0' }
	
	limit := limit_str.int()
	offset := offset_str.int()
	
	// 查询文件列表
	result := fs.list_files(FileListOptions{
		bucket: bucket
		prefix: prefix
		storage_type: storage_type
		limit: if limit > 0 { limit } else { 100 }
		offset: if offset >= 0 { offset } else { 0 }
	}) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to list files: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[FileListResult](result))
}

// 获取文件信息
// GET /files/:file_uuid/info
pub fn (fs FileService) handle_get_file_info(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	// 获取文件信息
	file_info := fs.get_file_info(file_uuid) or {
		ctx.status(404)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'File not found: ${err}'
			code: 404
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[FileInfo](file_info))
}

// 获取预签名 URL
// POST /presign
pub fn (mut fs FileService) handle_presign(mut ctx Context) http.Response {
	// 解析请求体
	req := json2.decode[PresignRequest](ctx.body) or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Invalid request body: ${err}'
			code: 400
		}))
	}
	
	if req.file_uuid == '' {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid'
			code: 400
		}))
	}
	
	expires_in := if req.expires_in > 0 { req.expires_in } else { 3600 }
	
	// 生成预签名 URL
	result := fs.get_presigned_url(req.file_uuid, expires_in) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to generate presigned URL: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[PresignResult](result))
}

// 获取预签名 URL (GET 方式)
// GET /presign/:file_uuid?expires_in=3600
pub fn (mut fs FileService) handle_presign_get(mut ctx Context) http.Response {
	file_uuid := ctx.params['file_uuid'] or {
		ctx.status(400)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Missing file_uuid parameter'
			code: 400
		}))
	}
	
	expires_in_str := ctx.query['expires_in'] or { '3600' }
	mut expires_in := expires_in_str.int()
	if expires_in <= 0 {
		expires_in = 3600
	}
	
	// 生成预签名 URL
	result := fs.get_presigned_url(file_uuid, expires_in) or {
		ctx.status(500)
		return ctx.json(json2.encode[StorageErrorResponse](StorageErrorResponse{
			success: false
			error: 'Failed to generate presigned URL: ${err}'
			code: 500
		}))
	}
	
	ctx.status(200)
	return ctx.json(json2.encode[PresignResult](result))
}


// ============================================================================
// 辅助函数
// ============================================================================

// 生成分片上传的对象键
fn generate_multipart_object_key(filename string) string {
	now := time.now()
	date_prefix := now.custom_format('YYYY/MM/DD')
	uuid := generate_file_uuid()
	ext := os.file_ext(filename)
	return '${date_prefix}/${uuid}${ext}'
}

// ============================================================================
// 路由注册
// ============================================================================

// 注册所有文件服务路由
// prefix: 路由前缀，例如 "/api/storage"
pub fn (mut fs FileService) register_routes(mut app Hono, prefix string) {
	// 文件上传
	app.post('${prefix}/upload', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_upload(mut ctx)
	})
	
	// 文件下载
	app.get('${prefix}/download/:file_uuid', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_download(mut ctx)
	})
	
	// 文件删除
	app.delete('${prefix}/files/:file_uuid', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_delete(mut ctx)
	})
	
	// 文件列表
	app.get('${prefix}/files', fn [fs] (mut ctx Context) http.Response {
		return fs.handle_list_files(mut ctx)
	})
	
	// 文件信息
	app.get('${prefix}/files/:file_uuid/info', fn [fs] (mut ctx Context) http.Response {
		return fs.handle_get_file_info(mut ctx)
	})
	
	// 预签名 URL (POST)
	app.post('${prefix}/presign', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_presign(mut ctx)
	})
	
	// 预签名 URL (GET)
	app.get('${prefix}/presign/:file_uuid', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_presign_get(mut ctx)
	})
	
	// 分片上传 - 初始化
	app.post('${prefix}/multipart/init', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_init_multipart(mut ctx)
	})
	
	// 分片上传 - 上传分片
	app.post('${prefix}/multipart/upload/:upload_id/:part_number', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_upload_part(mut ctx)
	})
	
	// 分片上传 - 完成
	app.post('${prefix}/multipart/complete', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_complete_multipart(mut ctx)
	})
	
	// 分片上传 - 取消
	app.post('${prefix}/multipart/abort', fn [mut fs] (mut ctx Context) http.Response {
		return fs.handle_abort_multipart(mut ctx)
	})
	
	// 分片上传 - 进度查询
	app.get('${prefix}/multipart/progress/:upload_id', fn [fs] (mut ctx Context) http.Response {
		return fs.handle_upload_progress(mut ctx)
	})
}

// 注册简化的路由（不带前缀）
pub fn (mut fs FileService) register_default_routes(mut app Hono) {
	fs.register_routes(mut app, '/storage')
}
