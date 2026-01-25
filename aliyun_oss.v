module hono

import io
import net.http
import net.urllib
import time
import crypto.sha1
import crypto.md5
import encoding.base64

// AliyunOSS 阿里云 OSS 存储提供者
pub struct AliyunOSS {
	config AliyunOSSConfig
mut:
	// 用于跟踪分片上传的内存存储
	multipart_uploads map[string]OSSMultipartUploadState
	// 是否使用内网端点
	use_internal bool
}

// OSS 分片上传状态
struct OSSMultipartUploadState {
mut:
	bucket       string
	key          string
	upload_id    string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

// 创建阿里云 OSS 存储提供者
pub fn new_aliyun_oss(config AliyunOSSConfig) !AliyunOSS {
	// 验证配置
	validation := validate_aliyun_oss_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return AliyunOSS{
		config: config
		multipart_uploads: map[string]OSSMultipartUploadState{}
		use_internal: false
	}
}

// 创建使用内网端点的阿里云 OSS 存储提供者
pub fn new_aliyun_oss_internal(config AliyunOSSConfig) !AliyunOSS {
	// 验证配置
	validation := validate_aliyun_oss_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	if config.internal_endpoint == '' {
		return error('Internal endpoint is not configured')
	}

	return AliyunOSS{
		config: config
		multipart_uploads: map[string]OSSMultipartUploadState{}
		use_internal: true
	}
}


// 切换到内网端点
pub fn (mut o AliyunOSS) switch_to_internal() ! {
	if o.config.internal_endpoint == '' {
		return error('Internal endpoint is not configured')
	}
	o.use_internal = true
}

// 切换到外网端点
pub fn (mut o AliyunOSS) switch_to_external() {
	o.use_internal = false
}

// 获取当前使用的端点
pub fn (o AliyunOSS) get_current_endpoint() string {
	if o.use_internal && o.config.internal_endpoint != '' {
		return o.config.internal_endpoint
	}
	return o.config.endpoint
}

// ============================================================================
// 阿里云 OSS 签名算法实现 (OSS Signature V1)
// ============================================================================

// 签名请求所需的信息
struct OSSSigningInfo {
	method                    string
	content_md5               string
	content_type              string
	date                      string
	canonicalized_oss_headers string
	canonicalized_resource    string
}

// 创建签名信息
fn (o AliyunOSS) create_signing_info(method string, bucket string, key string, headers map[string]string, query_params map[string]string) OSSSigningInfo {
	// 获取 Content-MD5
	content_md5 := headers['Content-MD5'] or { '' }

	// 获取 Content-Type
	content_type := headers['Content-Type'] or { '' }

	// 获取日期
	date := headers['Date'] or { '' }

	// 构建规范化的 OSS 头
	canonicalized_oss_headers := o.build_canonicalized_oss_headers(headers)

	// 构建规范化的资源
	canonicalized_resource := o.build_canonicalized_resource(bucket, key, query_params)

	return OSSSigningInfo{
		method: method
		content_md5: content_md5
		content_type: content_type
		date: date
		canonicalized_oss_headers: canonicalized_oss_headers
		canonicalized_resource: canonicalized_resource
	}
}

// 构建规范化的 OSS 头
fn (o AliyunOSS) build_canonicalized_oss_headers(headers map[string]string) string {
	// 收集所有以 x-oss- 开头的头
	mut oss_headers := map[string]string{}
	for key, value in headers {
		lower_key := key.to_lower()
		if lower_key.starts_with('x-oss-') {
			oss_headers[lower_key] = value.trim_space()
		}
	}

	if oss_headers.len == 0 {
		return ''
	}

	// 按键排序
	mut keys := oss_headers.keys()
	keys.sort()

	// 构建规范化字符串
	mut result := ''
	for key in keys {
		result += '${key}:${oss_headers[key]}\n'
	}

	return result
}


// 构建规范化的资源
fn (o AliyunOSS) build_canonicalized_resource(bucket string, key string, query_params map[string]string) string {
	mut resource := ''

	// 添加 bucket
	if bucket != '' {
		resource = '/${bucket}'
	}

	// 添加 key
	if key != '' {
		resource += '/${key}'
	} else if bucket != '' {
		resource += '/'
	} else {
		resource = '/'
	}

	// 添加子资源参数（需要排序）
	sub_resources := [
		'acl', 'uploads', 'location', 'cors', 'logging', 'website', 'referer',
		'lifecycle', 'delete', 'append', 'tagging', 'objectMeta', 'uploadId',
		'partNumber', 'security-token', 'position', 'img', 'style', 'styleName',
		'replication', 'replicationProgress', 'replicationLocation', 'cname',
		'bucketInfo', 'comp', 'qos', 'live', 'status', 'vod', 'startTime',
		'endTime', 'symlink', 'x-oss-process', 'response-content-type',
		'response-content-language', 'response-expires', 'response-cache-control',
		'response-content-disposition', 'response-content-encoding',
	]

	mut sub_params := []string{}
	for param in sub_resources {
		if param in query_params {
			value := query_params[param]
			if value != '' {
				sub_params << '${param}=${value}'
			} else {
				sub_params << param
			}
		}
	}

	if sub_params.len > 0 {
		resource += '?' + sub_params.join('&')
	}

	return resource
}

// 构建待签名字符串
fn (o AliyunOSS) build_string_to_sign(info OSSSigningInfo) string {
	// 如果有 OSS 头，需要在它和资源之间加换行
	if info.canonicalized_oss_headers != '' {
		return '${info.method}\n${info.content_md5}\n${info.content_type}\n${info.date}\n${info.canonicalized_oss_headers}${info.canonicalized_resource}'
	}

	return '${info.method}\n${info.content_md5}\n${info.content_type}\n${info.date}\n${info.canonicalized_resource}'
}

// 计算签名
fn (o AliyunOSS) calculate_signature(string_to_sign string) string {
	// 使用 HMAC-SHA1 计算签名
	signature := oss_hmac_sha1(o.config.access_key_secret.bytes(), string_to_sign.bytes())
	// Base64 编码
	return base64.encode(signature)
}

// HMAC-SHA1 实现
fn oss_hmac_sha1(key []u8, data []u8) []u8 {
	block_size := 64
	mut k := key.clone()

	// 如果 key 长度大于 block_size，先进行 hash
	if k.len > block_size {
		k = sha1.sum(k)
	}

	// 如果 key 长度小于 block_size，用 0 填充
	for k.len < block_size {
		k << u8(0)
	}

	// 计算 inner 和 outer padding
	mut i_pad := []u8{len: block_size}
	mut o_pad := []u8{len: block_size}
	for i in 0 .. block_size {
		i_pad[i] = k[i] ^ u8(0x36)
		o_pad[i] = k[i] ^ u8(0x5c)
	}

	// inner hash: SHA1(i_pad || data)
	mut inner_data := i_pad.clone()
	inner_data << data
	inner_hash := sha1.sum(inner_data)

	// outer hash: SHA1(o_pad || inner_hash)
	mut outer_data := o_pad.clone()
	outer_data << inner_hash
	return sha1.sum(outer_data)
}


// 签名请求并返回完整的请求头
pub fn (o AliyunOSS) sign_request(method string, bucket string, key string, mut headers map[string]string, query_params map[string]string) map[string]string {
	// 添加日期头
	now := time.utc()
	date := o.format_http_date(now)
	headers['Date'] = date

	// 创建签名信息
	info := o.create_signing_info(method, bucket, key, headers, query_params)

	// 构建待签名字符串
	string_to_sign := o.build_string_to_sign(info)

	// 计算签名
	signature := o.calculate_signature(string_to_sign)

	// 构建 Authorization 头
	headers['Authorization'] = 'OSS ${o.config.access_key_id}:${signature}'

	return headers
}

// 格式化 HTTP 日期
fn (o AliyunOSS) format_http_date(t time.Time) string {
	// HTTP 日期格式: "Mon, 02 Jan 2006 15:04:05 GMT"
	days := ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

	day_of_week := days[int(t.day_of_week())]
	month := months[t.month - 1]

	return '${day_of_week}, ${t.day:02d} ${month} ${t.year} ${t.hour:02d}:${t.minute:02d}:${t.second:02d} GMT'
}

// ============================================================================
// HTTP 请求辅助方法
// ============================================================================

// 获取主机名
fn (o AliyunOSS) get_host(bucket string) string {
	endpoint := o.get_current_endpoint()
	if bucket != '' {
		return '${bucket}.${endpoint}'
	}
	return endpoint
}

// 获取完整 URL
fn (o AliyunOSS) get_url(bucket string, key string, query_params map[string]string) string {
	host := o.get_host(bucket)

	mut path := ''
	if key != '' {
		// URL 编码 key，但保留 /
		path = '/' + o.encode_key(key)
	} else {
		path = '/'
	}

	mut url := 'https://${host}${path}'

	if query_params.len > 0 {
		query_string := o.build_query_string(query_params)
		url += '?${query_string}'
	}

	return url
}

// URL 编码 key（保留 /）
fn (o AliyunOSS) encode_key(key string) string {
	parts := key.split('/')
	mut encoded_parts := []string{}
	for part in parts {
		encoded_parts << urllib.query_escape(part)
	}
	return encoded_parts.join('/')
}

// 构建查询字符串
fn (o AliyunOSS) build_query_string(params map[string]string) string {
	if params.len == 0 {
		return ''
	}

	mut keys := params.keys()
	keys.sort()

	mut parts := []string{}
	for key in keys {
		value := params[key]
		if value != '' {
			parts << '${urllib.query_escape(key)}=${urllib.query_escape(value)}'
		} else {
			parts << urllib.query_escape(key)
		}
	}

	return parts.join('&')
}


// 执行 HTTP 请求
fn (o AliyunOSS) do_request(method http.Method, bucket string, key string, query_params map[string]string, extra_headers map[string]string, payload []u8) !http.Response {
	url := o.get_url(bucket, key, query_params)

	// 准备请求头
	mut headers := extra_headers.clone()
	headers['Host'] = o.get_host(bucket)

	// 如果有 payload，计算 Content-MD5
	if payload.len > 0 {
		md5_hash := md5.sum(payload)
		headers['Content-MD5'] = base64.encode(md5_hash)
		headers['Content-Length'] = payload.len.str()
	}

	// 签名请求
	signed_headers := o.sign_request(method.str(), bucket, key, mut headers, query_params)

	// 构建 http.Header
	mut http_header := http.Header{}
	for k, v in signed_headers {
		http_header.add_custom(k, v) or {}
	}

	// 执行请求
	mut config := http.FetchConfig{
		url: url
		method: method
		header: http_header
		data: payload.bytestr()
	}

	response := http.fetch(config) or {
		return error(new_timeout_error('aliyun_oss', method.str()).msg())
	}

	return response
}

// 解析 OSS 错误响应
fn (o AliyunOSS) parse_error_response(response http.Response, operation string) StorageError {
	status := response.status_code

	// 根据状态码判断错误类型
	kind := match status {
		403 { StorageErrorKind.access_denied }
		404 { StorageErrorKind.object_not_found }
		409 { StorageErrorKind.bucket_not_found }
		429 { StorageErrorKind.rate_limited }
		500, 502, 503, 504 { StorageErrorKind.service_unavailable }
		else { StorageErrorKind.unknown }
	}

	// 尝试从响应体解析错误消息
	message := if response.body.len > 0 {
		o.extract_error_message(response.body)
	} else {
		'HTTP ${status}'
	}

	return new_storage_error_with_status(kind, message, 'aliyun_oss', operation, status)
}

// 从 XML 错误响应中提取错误消息
fn (o AliyunOSS) extract_error_message(body string) string {
	// 简单的 XML 解析，提取 <Message> 标签内容
	if message_start := body.index('<Message>') {
		if message_end := body.index('</Message>') {
			return body[message_start + 9..message_end]
		}
	}
	// 尝试提取 <Code> 标签
	if code_start := body.index('<Code>') {
		if code_end := body.index('</Code>') {
			return body[code_start + 6..code_end]
		}
	}
	return body
}

// 计算数据的 ETag (MD5)
fn (o AliyunOSS) calculate_etag(data []u8) string {
	hash := md5.sum(data)
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return '"${result}"'
}


// ============================================================================
// StorageProvider 接口实现 - 基本操作
// ============================================================================

// 上传文件
pub fn (mut o AliyunOSS) upload(bucket string, key string, data []u8, content_type string) !StorageResult {
	mut headers := map[string]string{}
	if content_type != '' {
		headers['Content-Type'] = content_type
	} else {
		headers['Content-Type'] = 'application/octet-stream'
	}

	response := o.do_request(.put, bucket, key, map[string]string{}, headers, data)!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'upload').msg())
	}

	// 从响应头获取 ETag
	etag := response.header.get_custom('ETag') or { o.calculate_etag(data) }

	return new_storage_result(key, etag, i64(data.len))
}

// 流式上传文件
pub fn (mut o AliyunOSS) upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult {
	// 读取所有数据
	mut data := []u8{}
	mut buf := []u8{len: 8192}
	for {
		n := reader.read(mut buf) or { break }
		if n == 0 {
			break
		}
		data << buf[..n]
	}

	return o.upload(bucket, key, data, content_type)
}

// 下载文件
pub fn (o AliyunOSS) download(bucket string, key string) ![]u8 {
	response := o.do_request(.get, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 404 {
		return error(new_not_found_error('aliyun_oss', bucket, key).msg())
	}

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'download').msg())
	}

	return response.body.bytes()
}

// 流式下载文件
pub fn (o AliyunOSS) download_stream(bucket string, key string, mut writer io.Writer) !i64 {
	data := o.download(bucket, key)!
	written := writer.write(data) or {
		return error(new_storage_error(.unknown, 'Failed to write to stream: ${err}', 'aliyun_oss', 'download_stream').msg())
	}
	return i64(written)
}

// 删除文件
pub fn (o AliyunOSS) delete(bucket string, key string) ! {
	response := o.do_request(.delete, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	// OSS 返回 204 或 200 表示成功删除
	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_not_found_error('aliyun_oss', bucket, key).msg())
		}
		return error(o.parse_error_response(response, 'delete').msg())
	}
}

// 检查文件是否存在
pub fn (o AliyunOSS) exists(bucket string, key string) !bool {
	response := o.do_request(.head, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}

	return error(o.parse_error_response(response, 'exists').msg())
}


// ============================================================================
// StorageProvider 接口实现 - 元数据操作
// ============================================================================

// 获取文件元数据
pub fn (o AliyunOSS) head(bucket string, key string) !ObjectInfo {
	response := o.do_request(.head, bucket, key, map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 404 {
		return error(new_not_found_error('aliyun_oss', bucket, key).msg())
	}

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'head').msg())
	}

	// 解析响应头
	content_length := response.header.get_custom('Content-Length') or { '0' }
	etag := response.header.get_custom('ETag') or { '' }
	content_type := response.header.get_custom('Content-Type') or { 'application/octet-stream' }
	last_modified_str := response.header.get_custom('Last-Modified') or { '' }

	// 解析 Last-Modified 时间
	last_modified := parse_oss_http_date(last_modified_str)

	return new_object_info(key, content_length.i64(), etag, content_type, last_modified)
}

// 复制文件
pub fn (mut o AliyunOSS) copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult {
	mut headers := map[string]string{}
	// OSS 复制源格式
	copy_source := '/${src_bucket}/${src_key}'
	headers['x-oss-copy-source'] = copy_source

	response := o.do_request(.put, dst_bucket, dst_key, map[string]string{}, headers, []u8{})!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'copy').msg())
	}

	// 从响应解析 ETag
	etag := o.extract_copy_result_etag(response.body)

	// 获取复制后文件的大小
	head_info := o.head(dst_bucket, dst_key) or {
		return new_storage_result(dst_key, etag, 0)
	}

	return new_storage_result(dst_key, etag, head_info.size)
}

// 从复制结果 XML 中提取 ETag
fn (o AliyunOSS) extract_copy_result_etag(body string) string {
	if etag_start := body.index('<ETag>') {
		if etag_end := body.index('</ETag>') {
			return body[etag_start + 6..etag_end]
		}
	}
	return ''
}

// ============================================================================
// StorageProvider 接口实现 - 列表操作
// ============================================================================

// 列出文件
pub fn (o AliyunOSS) list(bucket string, options ListOptions) !ListResult {
	mut query_params := map[string]string{}
	query_params['list-type'] = '2' // 使用 ListObjectsV2

	if options.prefix != '' {
		query_params['prefix'] = options.prefix
	}
	if options.delimiter != '' {
		query_params['delimiter'] = options.delimiter
	}
	if options.max_keys > 0 {
		query_params['max-keys'] = options.max_keys.str()
	}
	if options.start_after != '' {
		query_params['start-after'] = options.start_after
	}

	response := o.do_request(.get, bucket, '', query_params, map[string]string{}, []u8{})!

	if response.status_code == 404 {
		return error(new_bucket_not_found_error('aliyun_oss', bucket).msg())
	}

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'list').msg())
	}

	// 解析 XML 响应
	return o.parse_list_objects_response(response.body)
}


// 解析 ListObjectsV2 响应
fn (o AliyunOSS) parse_list_objects_response(body string) !ListResult {
	mut objects := []ObjectInfo{}
	mut common_prefixes := []string{}
	mut is_truncated := false
	mut next_marker := ''

	// 解析 IsTruncated
	if truncated_start := body.index('<IsTruncated>') {
		if truncated_end := body.index('</IsTruncated>') {
			truncated_str := body[truncated_start + 13..truncated_end]
			is_truncated = truncated_str == 'true'
		}
	}

	// 解析 NextContinuationToken
	if token_start := body.index('<NextContinuationToken>') {
		if token_end := body.index('</NextContinuationToken>') {
			next_marker = body[token_start + 23..token_end]
		}
	}

	// 解析 Contents
	mut search_pos := 0
	for {
		content_start := body.index_after('<Contents>', search_pos) or { break }
		content_end := body.index_after('</Contents>', content_start) or { break }
		content_xml := body[content_start..content_end + 11]

		obj := o.parse_object_from_xml(content_xml)
		objects << obj

		search_pos = content_end + 11
	}

	// 解析 CommonPrefixes
	search_pos = 0
	for {
		prefix_start := body.index_after('<CommonPrefixes>', search_pos) or { break }
		prefix_end := body.index_after('</CommonPrefixes>', prefix_start) or { break }
		prefix_xml := body[prefix_start..prefix_end + 17]

		if p_start := prefix_xml.index('<Prefix>') {
			if p_end := prefix_xml.index('</Prefix>') {
				common_prefixes << prefix_xml[p_start + 8..p_end]
			}
		}

		search_pos = prefix_end + 17
	}

	return new_list_result(objects, common_prefixes, is_truncated, next_marker)
}

// 从 XML 解析单个对象信息
fn (o AliyunOSS) parse_object_from_xml(xml string) ObjectInfo {
	mut key := ''
	mut size := i64(0)
	mut etag := ''
	mut last_modified := i64(0)

	if key_start := xml.index('<Key>') {
		if key_end := xml.index('</Key>') {
			key = xml[key_start + 5..key_end]
		}
	}

	if size_start := xml.index('<Size>') {
		if size_end := xml.index('</Size>') {
			size = xml[size_start + 6..size_end].i64()
		}
	}

	if etag_start := xml.index('<ETag>') {
		if etag_end := xml.index('</ETag>') {
			etag = xml[etag_start + 6..etag_end]
		}
	}

	if lm_start := xml.index('<LastModified>') {
		if lm_end := xml.index('</LastModified>') {
			lm_str := xml[lm_start + 14..lm_end]
			last_modified = parse_oss_iso8601_date(lm_str)
		}
	}

	content_type := infer_content_type(key)

	return new_object_info(key, size, etag, content_type, last_modified)
}


// ============================================================================
// StorageProvider 接口实现 - Bucket 操作
// ============================================================================

// 创建 bucket
pub fn (o AliyunOSS) create_bucket(bucket string) ! {
	mut headers := map[string]string{}
	headers['Content-Type'] = 'application/xml'

	// 构建创建 bucket 的 XML
	// 注意：OSS 需要指定存储类型和数据冗余类型
	payload := '<?xml version="1.0" encoding="UTF-8"?><CreateBucketConfiguration><StorageClass>Standard</StorageClass></CreateBucketConfiguration>'

	response := o.do_request(.put, bucket, '', map[string]string{}, headers, payload.bytes())!

	// 200 或 409 (BucketAlreadyExists) 都算成功
	if response.status_code != 200 && response.status_code != 409 {
		return error(o.parse_error_response(response, 'create_bucket').msg())
	}
}

// 删除 bucket
pub fn (o AliyunOSS) delete_bucket(bucket string) ! {
	response := o.do_request(.delete, bucket, '', map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_bucket_not_found_error('aliyun_oss', bucket).msg())
		}
		return error(o.parse_error_response(response, 'delete_bucket').msg())
	}
}

// 检查 bucket 是否存在
pub fn (o AliyunOSS) bucket_exists(bucket string) !bool {
	response := o.do_request(.head, bucket, '', map[string]string{}, map[string]string{}, []u8{})!

	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}

	return error(o.parse_error_response(response, 'bucket_exists').msg())
}

// 获取提供者名称
pub fn (o AliyunOSS) provider_name() string {
	return 'aliyun_oss'
}

// ============================================================================
// StorageProvider 接口实现 - 分片上传
// ============================================================================

// 初始化分片上传
pub fn (mut o AliyunOSS) init_multipart(bucket string, key string, content_type string) !string {
	mut query_params := map[string]string{}
	query_params['uploads'] = ''

	mut headers := map[string]string{}
	if content_type != '' {
		headers['Content-Type'] = content_type
	}

	response := o.do_request(.post, bucket, key, query_params, headers, []u8{})!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'init_multipart').msg())
	}

	// 从 XML 响应中提取 UploadId
	upload_id := o.extract_upload_id(response.body)
	if upload_id == '' {
		return error(new_storage_error(.unknown, 'Failed to parse UploadId from response', 'aliyun_oss', 'init_multipart').msg())
	}

	// 记录上传状态
	o.multipart_uploads[upload_id] = OSSMultipartUploadState{
		bucket: bucket
		key: key
		upload_id: upload_id
		content_type: content_type
		parts: map[int]PartInfo{}
		created_at: time.now().unix()
	}

	return upload_id
}

// 从 InitiateMultipartUploadResult XML 中提取 UploadId
fn (o AliyunOSS) extract_upload_id(body string) string {
	if id_start := body.index('<UploadId>') {
		if id_end := body.index('</UploadId>') {
			return body[id_start + 10..id_end]
		}
	}
	return ''
}


// 上传分片
pub fn (mut o AliyunOSS) upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string {
	mut query_params := map[string]string{}
	query_params['partNumber'] = part_number.str()
	query_params['uploadId'] = upload_id

	mut headers := map[string]string{}
	headers['Content-Length'] = data.len.str()

	response := o.do_request(.put, bucket, key, query_params, headers, data)!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'upload_part').msg())
	}

	// 从响应头获取 ETag
	etag := response.header.get_custom('ETag') or { o.calculate_etag(data) }

	// 更新上传状态
	if upload_id in o.multipart_uploads {
		mut upload_state := o.multipart_uploads[upload_id]
		upload_state.parts[part_number] = new_part_info(part_number, etag, i64(data.len))
		o.multipart_uploads[upload_id] = upload_state
	}

	return etag
}

// 完成分片上传
pub fn (mut o AliyunOSS) complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id

	// 构建 CompleteMultipartUpload XML
	mut xml_parts := '<?xml version="1.0" encoding="UTF-8"?><CompleteMultipartUpload>'
	for part in parts {
		xml_parts += '<Part>'
		xml_parts += '<PartNumber>${part.part_number}</PartNumber>'
		xml_parts += '<ETag>${part.etag}</ETag>'
		xml_parts += '</Part>'
	}
	xml_parts += '</CompleteMultipartUpload>'

	mut headers := map[string]string{}
	headers['Content-Type'] = 'application/xml'

	payload := xml_parts.bytes()
	response := o.do_request(.post, bucket, key, query_params, headers, payload)!

	if response.status_code != 200 {
		return error(o.parse_error_response(response, 'complete_multipart').msg())
	}

	// 从响应解析 ETag
	etag := o.extract_complete_multipart_etag(response.body)

	// 计算总大小
	mut total_size := i64(0)
	for part in parts {
		total_size += part.size
	}

	// 清理上传状态
	o.multipart_uploads.delete(upload_id)

	return new_storage_result(key, etag, total_size)
}

// 从 CompleteMultipartUploadResult XML 中提取 ETag
fn (o AliyunOSS) extract_complete_multipart_etag(body string) string {
	if etag_start := body.index('<ETag>') {
		if etag_end := body.index('</ETag>') {
			return body[etag_start + 6..etag_end]
		}
	}
	return ''
}

// 取消分片上传
pub fn (mut o AliyunOSS) abort_multipart(bucket string, key string, upload_id string) ! {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id

	response := o.do_request(.delete, bucket, key, query_params, map[string]string{}, []u8{})!

	if response.status_code != 204 && response.status_code != 200 {
		return error(o.parse_error_response(response, 'abort_multipart').msg())
	}

	// 清理上传状态
	o.multipart_uploads.delete(upload_id)
}


// ============================================================================
// StorageProvider 接口实现 - 预签名 URL
// ============================================================================

// 生成预签名 URL
pub fn (o AliyunOSS) presign_url(bucket string, key string, options PresignOptions) !string {
	// 计算过期时间戳
	now := time.utc()
	expires := now.unix() + i64(options.expires_in)

	// 构建待签名字符串
	// 格式: METHOD\n\nContent-Type\nExpires\nCanonicalizedOSSHeaders\nCanonicalizedResource
	mut content_type := ''
	if options.content_type != '' {
		content_type = options.content_type
	}

	canonicalized_resource := o.build_canonicalized_resource(bucket, key, map[string]string{})

	string_to_sign := '${options.method}\n\n${content_type}\n${expires}\n${canonicalized_resource}'

	// 计算签名
	signature := o.calculate_signature(string_to_sign)

	// 构建 URL
	host := o.get_host(bucket)
	encoded_key := o.encode_key(key)

	mut url := 'https://${host}/${encoded_key}'
	url += '?OSSAccessKeyId=${urllib.query_escape(o.config.access_key_id)}'
	url += '&Expires=${expires}'
	url += '&Signature=${urllib.query_escape(signature)}'

	return url
}

// ============================================================================
// 辅助函数
// ============================================================================

// 解析 OSS HTTP 日期格式
fn parse_oss_http_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// HTTP 日期格式: "Mon, 02 Jan 2006 15:04:05 GMT"
	// 简化处理，返回当前时间
	return time.now().unix()
}

// 解析 OSS ISO8601 日期格式
fn parse_oss_iso8601_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// ISO8601 格式: "2006-01-02T15:04:05.000Z"
	// 简化处理，返回当前时间
	return time.now().unix()
}
