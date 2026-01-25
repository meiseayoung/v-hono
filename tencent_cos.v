module hono

import io
import net.http
import net.urllib
import time
import crypto.sha1
import crypto.md5
import encoding.hex

// TencentCOS 腾讯云 COS 存储提供者
pub struct TencentCOS {
	config TencentCOSConfig
mut:
	// 用于跟踪分片上传的内存存储
	multipart_uploads map[string]COSMultipartUploadState
}

// COS 分片上传状态
struct COSMultipartUploadState {
mut:
	bucket       string
	key          string
	upload_id    string
	content_type string
	parts        map[int]PartInfo
	created_at   i64
}

// 创建腾讯云 COS 存储提供者
pub fn new_tencent_cos(config TencentCOSConfig) !TencentCOS {
	// 验证配置
	validation := validate_tencent_cos_config(config)
	if !validation.valid {
		return error(validation.error_message)
	}

	return TencentCOS{
		config: config
		multipart_uploads: map[string]COSMultipartUploadState{}
	}
}

// ============================================================================
// 腾讯云 COS 签名算法实现 (COS Signature)
// 参考: https://cloud.tencent.com/document/product/436/7778
// ============================================================================

// 签名请求所需的信息
struct COSSigningInfo {
	method              string
	uri                 string
	query_string        string
	headers             map[string]string
	signed_headers      string
	timestamp           i64
	key_time            string
	header_list         string
	url_param_list      string
}

// 创建签名信息
fn (c TencentCOS) create_signing_info(method string, uri string, query_params map[string]string, headers map[string]string) COSSigningInfo {
	now := time.utc()
	timestamp := now.unix()
	
	// 计算签名有效期 (当前时间 - 60秒 到 当前时间 + 3600秒)
	start_time := timestamp - 60
	end_time := timestamp + 3600
	key_time := '${start_time};${end_time}'
	
	// 构建查询字符串
	query_string := c.build_canonical_query_string(query_params)
	
	// 获取签名头列表
	signed_headers := c.get_signed_headers(headers)
	header_list := c.get_header_list(headers)
	url_param_list := c.get_url_param_list(query_params)
	
	return COSSigningInfo{
		method: method.to_lower()
		uri: uri
		query_string: query_string
		headers: headers
		signed_headers: signed_headers
		timestamp: timestamp
		key_time: key_time
		header_list: header_list
		url_param_list: url_param_list
	}
}

// 构建规范查询字符串
fn (c TencentCOS) build_canonical_query_string(params map[string]string) string {
	if params.len == 0 {
		return ''
	}

	// 获取排序后的键（小写）
	mut keys := []string{}
	mut lower_params := map[string]string{}
	for key, value in params {
		lower_key := key.to_lower()
		keys << lower_key
		lower_params[lower_key] = value
	}
	keys.sort()

	mut parts := []string{}
	for key in keys {
		encoded_key := urllib.query_escape(key)
		encoded_value := urllib.query_escape(lower_params[key])
		parts << '${encoded_key}=${encoded_value}'
	}

	return parts.join('&')
}

// 获取签名头列表（小写排序，分号分隔）
fn (c TencentCOS) get_signed_headers(headers map[string]string) string {
	mut header_names := []string{}
	for key, _ in headers {
		lower_key := key.to_lower()
		// 只包含需要签名的头
		if c.should_sign_header(lower_key) {
			header_names << lower_key
		}
	}
	header_names.sort()
	return header_names.join(';')
}

// 获取头列表（用于签名）
fn (c TencentCOS) get_header_list(headers map[string]string) string {
	mut header_names := []string{}
	for key, _ in headers {
		lower_key := key.to_lower()
		if c.should_sign_header(lower_key) {
			header_names << lower_key
		}
	}
	header_names.sort()
	return header_names.join(';')
}

// 获取 URL 参数列表（用于签名）
fn (c TencentCOS) get_url_param_list(params map[string]string) string {
	if params.len == 0 {
		return ''
	}
	
	mut keys := []string{}
	for key, _ in params {
		keys << key.to_lower()
	}
	keys.sort()
	return keys.join(';')
}

// 判断是否需要签名该头
fn (c TencentCOS) should_sign_header(header_name string) bool {
	// COS 签名需要包含的头
	required_headers := ['host', 'content-type', 'content-length', 'content-md5']
	if header_name in required_headers {
		return true
	}
	// x-cos- 开头的头都需要签名
	if header_name.starts_with('x-cos-') {
		return true
	}
	return false
}

// 构建规范请求
fn (c TencentCOS) build_canonical_request(info COSSigningInfo) string {
	// 构建规范头
	mut canonical_headers := ''
	mut header_names := []string{}
	for key, _ in info.headers {
		lower_key := key.to_lower()
		if c.should_sign_header(lower_key) {
			header_names << lower_key
		}
	}
	header_names.sort()

	for name in header_names {
		// 查找原始键（不区分大小写）
		for key, value in info.headers {
			if key.to_lower() == name {
				canonical_headers += '${name}=${urllib.query_escape(value.trim_space())}\n'
				break
			}
		}
	}
	
	// 移除最后的换行符
	if canonical_headers.len > 0 {
		canonical_headers = canonical_headers.trim_right('\n')
	}

	// HttpMethod\nUriPathname\nHttpParameters\nHttpHeaders\n
	return '${info.method}\n${info.uri}\n${info.query_string}\n${canonical_headers}\n'
}

// 构建待签名字符串
fn (c TencentCOS) build_string_to_sign(info COSSigningInfo, canonical_request string) string {
	// sha1 = lowercase(HexEncode(Hash(HttpString)))
	request_hash := sha1.sum(canonical_request.bytes())
	hashed_request := hex.encode(request_hash).to_lower()
	
	// StringToSign = q-sign-algorithm\nq-sign-time\nSha1Digest\n
	return 'sha1\n${info.key_time}\n${hashed_request}\n'
}

// 计算签名密钥
fn (c TencentCOS) get_signing_key(key_time string) []u8 {
	// SignKey = HMAC-SHA1(SecretKey, KeyTime)
	return cos_hmac_sha1(c.config.secret_key.bytes(), key_time.bytes())
}

// 计算签名
fn (c TencentCOS) calculate_signature(info COSSigningInfo, string_to_sign string) string {
	signing_key := c.get_signing_key(info.key_time)
	signature := cos_hmac_sha1(signing_key, string_to_sign.bytes())
	return hex.encode(signature).to_lower()
}

// COS HMAC-SHA1 实现
fn cos_hmac_sha1(key []u8, data []u8) []u8 {
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

// 构建 Authorization 头
fn (c TencentCOS) build_authorization_header(info COSSigningInfo, signature string) string {
	// q-sign-algorithm=sha1&q-ak=SecretId&q-sign-time=KeyTime&q-key-time=KeyTime&q-header-list=HeaderList&q-url-param-list=UrlParamList&q-signature=Signature
	mut auth := 'q-sign-algorithm=sha1'
	auth += '&q-ak=${c.config.secret_id}'
	auth += '&q-sign-time=${info.key_time}'
	auth += '&q-key-time=${info.key_time}'
	auth += '&q-header-list=${info.header_list}'
	auth += '&q-url-param-list=${info.url_param_list}'
	auth += '&q-signature=${signature}'
	
	return auth
}

// 签名请求并返回完整的请求头
pub fn (c TencentCOS) sign_request(method string, uri string, query_params map[string]string, mut headers map[string]string) map[string]string {
	// 创建签名信息
	info := c.create_signing_info(method, uri, query_params, headers)
	
	// 构建规范请求
	canonical_request := c.build_canonical_request(info)
	
	// 构建待签名字符串
	string_to_sign := c.build_string_to_sign(info, canonical_request)
	
	// 计算签名
	signature := c.calculate_signature(info, string_to_sign)
	
	// 构建 Authorization 头
	headers['Authorization'] = c.build_authorization_header(info, signature)
	
	return headers
}

// ============================================================================
// HTTP 请求辅助方法
// ============================================================================

// 获取主机名
fn (c TencentCOS) get_host(bucket string) string {
	// COS 域名格式: <BucketName-APPID>.cos.<Region>.myqcloud.com
	if bucket != '' {
		return '${bucket}.cos.${c.config.region}.myqcloud.com'
	}
	return 'cos.${c.config.region}.myqcloud.com'
}

// 获取完整 URL
fn (c TencentCOS) get_url(bucket string, key string, query_params map[string]string) string {
	host := c.get_host(bucket)
	
	mut path := ''
	if key != '' {
		// URL 编码 key，但保留 /
		path = '/' + c.encode_key(key)
	} else {
		path = '/'
	}
	
	mut url := 'https://${host}${path}'
	
	if query_params.len > 0 {
		query_string := c.build_query_string(query_params)
		url += '?${query_string}'
	}
	
	return url
}

// URL 编码 key（保留 /）
fn (c TencentCOS) encode_key(key string) string {
	parts := key.split('/')
	mut encoded_parts := []string{}
	for part in parts {
		encoded_parts << urllib.query_escape(part)
	}
	return encoded_parts.join('/')
}

// 构建查询字符串（不进行小写转换）
fn (c TencentCOS) build_query_string(params map[string]string) string {
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

// 获取 URI 路径
fn (c TencentCOS) get_uri_path(key string) string {
	if key != '' {
		return '/' + c.encode_key(key)
	}
	return '/'
}

// 执行 HTTP 请求
fn (c TencentCOS) do_request(method http.Method, bucket string, key string, query_params map[string]string, extra_headers map[string]string, payload []u8) !http.Response {
	url := c.get_url(bucket, key, query_params)
	uri := c.get_uri_path(key)
	
	// 准备请求头
	mut headers := extra_headers.clone()
	headers['Host'] = c.get_host(bucket)
	
	// 如果有 payload，计算 Content-Length
	if payload.len > 0 {
		headers['Content-Length'] = payload.len.str()
	}
	
	// 签名请求
	signed_headers := c.sign_request(method.str(), uri, query_params, mut headers)
	
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
		return error(new_timeout_error('tencent_cos', method.str()).msg())
	}
	
	return response
}

// 解析 COS 错误响应
fn (c TencentCOS) parse_error_response(response http.Response, operation string) StorageError {
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
		c.extract_error_message(response.body)
	} else {
		'HTTP ${status}'
	}
	
	return new_storage_error_with_status(kind, message, 'tencent_cos', operation, status)
}

// 从 XML 错误响应中提取错误消息
fn (c TencentCOS) extract_error_message(body string) string {
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
fn (c TencentCOS) calculate_etag(data []u8) string {
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
pub fn (mut c TencentCOS) upload(bucket string, key string, data []u8, content_type string) !StorageResult {
	mut headers := map[string]string{}
	if content_type != '' {
		headers['Content-Type'] = content_type
	} else {
		headers['Content-Type'] = 'application/octet-stream'
	}
	
	response := c.do_request(.put, bucket, key, map[string]string{}, headers, data)!
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'upload').msg())
	}
	
	// 从响应头获取 ETag
	etag := response.header.get_custom('ETag') or { c.calculate_etag(data) }
	
	return new_storage_result(key, etag, i64(data.len))
}

// 流式上传文件
pub fn (mut c TencentCOS) upload_stream(bucket string, key string, mut reader io.Reader, size i64, content_type string) !StorageResult {
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
	
	return c.upload(bucket, key, data, content_type)
}

// 下载文件
pub fn (c TencentCOS) download(bucket string, key string) ![]u8 {
	response := c.do_request(.get, bucket, key, map[string]string{}, map[string]string{}, []u8{})!
	
	if response.status_code == 404 {
		return error(new_not_found_error('tencent_cos', bucket, key).msg())
	}
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'download').msg())
	}
	
	return response.body.bytes()
}

// 流式下载文件
pub fn (c TencentCOS) download_stream(bucket string, key string, mut writer io.Writer) !i64 {
	data := c.download(bucket, key)!
	written := writer.write(data) or {
		return error(new_storage_error(.unknown, 'Failed to write to stream: ${err}', 'tencent_cos', 'download_stream').msg())
	}
	return i64(written)
}

// 删除文件
pub fn (c TencentCOS) delete(bucket string, key string) ! {
	response := c.do_request(.delete, bucket, key, map[string]string{}, map[string]string{}, []u8{})!
	
	// COS 返回 204 或 200 表示成功删除
	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_not_found_error('tencent_cos', bucket, key).msg())
		}
		return error(c.parse_error_response(response, 'delete').msg())
	}
}

// 检查文件是否存在
pub fn (c TencentCOS) exists(bucket string, key string) !bool {
	response := c.do_request(.head, bucket, key, map[string]string{}, map[string]string{}, []u8{})!
	
	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}
	
	return error(c.parse_error_response(response, 'exists').msg())
}

// ============================================================================
// StorageProvider 接口实现 - 元数据操作
// ============================================================================

// 获取文件元数据
pub fn (c TencentCOS) head(bucket string, key string) !ObjectInfo {
	response := c.do_request(.head, bucket, key, map[string]string{}, map[string]string{}, []u8{})!
	
	if response.status_code == 404 {
		return error(new_not_found_error('tencent_cos', bucket, key).msg())
	}
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'head').msg())
	}
	
	// 解析响应头
	content_length := response.header.get_custom('Content-Length') or { '0' }
	etag := response.header.get_custom('ETag') or { '' }
	content_type := response.header.get_custom('Content-Type') or { 'application/octet-stream' }
	last_modified_str := response.header.get_custom('Last-Modified') or { '' }
	
	// 解析 Last-Modified 时间
	last_modified := parse_cos_http_date(last_modified_str)
	
	return new_object_info(key, content_length.i64(), etag, content_type, last_modified)
}

// 复制文件
pub fn (mut c TencentCOS) copy(src_bucket string, src_key string, dst_bucket string, dst_key string) !StorageResult {
	mut headers := map[string]string{}
	// COS 复制源格式: /<BucketName-APPID>.cos.<Region>.myqcloud.com/<ObjectKey>
	copy_source := '${src_bucket}.cos.${c.config.region}.myqcloud.com/${src_key}'
	headers['x-cos-copy-source'] = copy_source
	
	response := c.do_request(.put, dst_bucket, dst_key, map[string]string{}, headers, []u8{})!
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'copy').msg())
	}
	
	// 从响应解析 ETag
	etag := c.extract_copy_result_etag(response.body)
	
	// 获取复制后文件的大小
	head_info := c.head(dst_bucket, dst_key) or {
		return new_storage_result(dst_key, etag, 0)
	}
	
	return new_storage_result(dst_key, etag, head_info.size)
}

// 从复制结果 XML 中提取 ETag
fn (c TencentCOS) extract_copy_result_etag(body string) string {
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
pub fn (c TencentCOS) list(bucket string, options ListOptions) !ListResult {
	mut query_params := map[string]string{}
	
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
		query_params['marker'] = options.start_after
	}
	
	response := c.do_request(.get, bucket, '', query_params, map[string]string{}, []u8{})!
	
	if response.status_code == 404 {
		return error(new_bucket_not_found_error('tencent_cos', bucket).msg())
	}
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'list').msg())
	}
	
	// 解析 XML 响应
	return c.parse_list_objects_response(response.body)
}

// 解析 ListObjects 响应
fn (c TencentCOS) parse_list_objects_response(body string) !ListResult {
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
	
	// 解析 NextMarker
	if marker_start := body.index('<NextMarker>') {
		if marker_end := body.index('</NextMarker>') {
			next_marker = body[marker_start + 12..marker_end]
		}
	}
	
	// 解析 Contents
	mut search_pos := 0
	for {
		content_start := body.index_after('<Contents>', search_pos) or { break }
		content_end := body.index_after('</Contents>', content_start) or { break }
		content_xml := body[content_start..content_end + 11]
		
		obj := c.parse_object_from_xml(content_xml)
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
fn (c TencentCOS) parse_object_from_xml(xml string) ObjectInfo {
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
			last_modified = parse_cos_iso8601_date(lm_str)
		}
	}
	
	content_type := infer_content_type(key)
	
	return new_object_info(key, size, etag, content_type, last_modified)
}

// ============================================================================
// StorageProvider 接口实现 - Bucket 操作
// ============================================================================

// 创建 bucket
pub fn (c TencentCOS) create_bucket(bucket string) ! {
	mut headers := map[string]string{}
	headers['Content-Type'] = 'application/xml'
	
	response := c.do_request(.put, bucket, '', map[string]string{}, headers, []u8{})!
	
	// 200 或 409 (BucketAlreadyExists) 都算成功
	if response.status_code != 200 && response.status_code != 409 {
		return error(c.parse_error_response(response, 'create_bucket').msg())
	}
}

// 删除 bucket
pub fn (c TencentCOS) delete_bucket(bucket string) ! {
	response := c.do_request(.delete, bucket, '', map[string]string{}, map[string]string{}, []u8{})!
	
	if response.status_code != 204 && response.status_code != 200 {
		if response.status_code == 404 {
			return error(new_bucket_not_found_error('tencent_cos', bucket).msg())
		}
		return error(c.parse_error_response(response, 'delete_bucket').msg())
	}
}

// 检查 bucket 是否存在
pub fn (c TencentCOS) bucket_exists(bucket string) !bool {
	response := c.do_request(.head, bucket, '', map[string]string{}, map[string]string{}, []u8{})!
	
	if response.status_code == 200 {
		return true
	}
	if response.status_code == 404 {
		return false
	}
	
	return error(c.parse_error_response(response, 'bucket_exists').msg())
}

// 获取提供者名称
pub fn (c TencentCOS) provider_name() string {
	return 'tencent_cos'
}


// ============================================================================
// StorageProvider 接口实现 - 分片上传
// ============================================================================

// 初始化分片上传
pub fn (mut c TencentCOS) init_multipart(bucket string, key string, content_type string) !string {
	mut query_params := map[string]string{}
	query_params['uploads'] = ''
	
	mut headers := map[string]string{}
	if content_type != '' {
		headers['Content-Type'] = content_type
	}
	
	response := c.do_request(.post, bucket, key, query_params, headers, []u8{})!
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'init_multipart').msg())
	}
	
	// 从 XML 响应中提取 UploadId
	upload_id := c.extract_upload_id(response.body)
	if upload_id == '' {
		return error(new_storage_error(.unknown, 'Failed to parse UploadId from response', 'tencent_cos', 'init_multipart').msg())
	}
	
	// 记录上传状态
	c.multipart_uploads[upload_id] = COSMultipartUploadState{
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
fn (c TencentCOS) extract_upload_id(body string) string {
	if id_start := body.index('<UploadId>') {
		if id_end := body.index('</UploadId>') {
			return body[id_start + 10..id_end]
		}
	}
	return ''
}

// 上传分片
pub fn (mut c TencentCOS) upload_part(bucket string, key string, upload_id string, part_number int, data []u8) !string {
	mut query_params := map[string]string{}
	query_params['partNumber'] = part_number.str()
	query_params['uploadId'] = upload_id
	
	mut headers := map[string]string{}
	headers['Content-Length'] = data.len.str()
	
	response := c.do_request(.put, bucket, key, query_params, headers, data)!
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'upload_part').msg())
	}
	
	// 从响应头获取 ETag
	etag := response.header.get_custom('ETag') or { c.calculate_etag(data) }
	
	// 更新上传状态
	if upload_id in c.multipart_uploads {
		mut upload_state := c.multipart_uploads[upload_id]
		upload_state.parts[part_number] = new_part_info(part_number, etag, i64(data.len))
		c.multipart_uploads[upload_id] = upload_state
	}
	
	return etag
}

// 完成分片上传
pub fn (mut c TencentCOS) complete_multipart(bucket string, key string, upload_id string, parts []PartInfo) !StorageResult {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id
	
	// 构建 CompleteMultipartUpload XML
	mut xml_parts := '<CompleteMultipartUpload>'
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
	response := c.do_request(.post, bucket, key, query_params, headers, payload)!
	
	if response.status_code != 200 {
		return error(c.parse_error_response(response, 'complete_multipart').msg())
	}
	
	// 从响应解析 ETag
	etag := c.extract_complete_multipart_etag(response.body)
	
	// 计算总大小
	mut total_size := i64(0)
	for part in parts {
		total_size += part.size
	}
	
	// 清理上传状态
	c.multipart_uploads.delete(upload_id)
	
	return new_storage_result(key, etag, total_size)
}

// 从 CompleteMultipartUploadResult XML 中提取 ETag
fn (c TencentCOS) extract_complete_multipart_etag(body string) string {
	if etag_start := body.index('<ETag>') {
		if etag_end := body.index('</ETag>') {
			return body[etag_start + 6..etag_end]
		}
	}
	return ''
}

// 取消分片上传
pub fn (mut c TencentCOS) abort_multipart(bucket string, key string, upload_id string) ! {
	mut query_params := map[string]string{}
	query_params['uploadId'] = upload_id
	
	response := c.do_request(.delete, bucket, key, query_params, map[string]string{}, []u8{})!
	
	if response.status_code != 204 && response.status_code != 200 {
		return error(c.parse_error_response(response, 'abort_multipart').msg())
	}
	
	// 清理上传状态
	c.multipart_uploads.delete(upload_id)
}

// ============================================================================
// StorageProvider 接口实现 - 预签名 URL
// ============================================================================

// 生成预签名 URL
pub fn (c TencentCOS) presign_url(bucket string, key string, options PresignOptions) !string {
	now := time.utc()
	timestamp := now.unix()
	
	// 计算签名有效期
	start_time := timestamp - 60
	end_time := timestamp + i64(options.expires_in)
	key_time := '${start_time};${end_time}'
	
	// 构建 URI
	uri := c.get_uri_path(key)
	
	// 构建待签名字符串
	// HttpString = [HttpMethod]\n[HttpURI]\n[HttpParameters]\n[HttpHeaders]\n
	http_string := '${options.method.to_lower()}\n${uri}\n\n\n'
	
	// 计算 SHA1 哈希
	request_hash := sha1.sum(http_string.bytes())
	hashed_request := hex.encode(request_hash).to_lower()
	
	// StringToSign = q-sign-algorithm\nq-sign-time\nSha1Digest\n
	string_to_sign := 'sha1\n${key_time}\n${hashed_request}\n'
	
	// 计算签名密钥
	signing_key := cos_hmac_sha1(c.config.secret_key.bytes(), key_time.bytes())
	
	// 计算签名
	signature := cos_hmac_sha1(signing_key, string_to_sign.bytes())
	signature_hex := hex.encode(signature).to_lower()
	
	// 构建 URL
	host := c.get_host(bucket)
	encoded_key := c.encode_key(key)
	
	mut url := 'https://${host}/${encoded_key}'
	url += '?q-sign-algorithm=sha1'
	url += '&q-ak=${urllib.query_escape(c.config.secret_id)}'
	url += '&q-sign-time=${key_time}'
	url += '&q-key-time=${key_time}'
	url += '&q-header-list='
	url += '&q-url-param-list='
	url += '&q-signature=${signature_hex}'
	
	return url
}

// ============================================================================
// 辅助函数
// ============================================================================

// 解析 COS HTTP 日期格式
fn parse_cos_http_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// HTTP 日期格式: "Mon, 02 Jan 2006 15:04:05 GMT"
	// 简化处理，返回当前时间
	return time.now().unix()
}

// 解析 COS ISO8601 日期格式
fn parse_cos_iso8601_date(date_str string) i64 {
	if date_str == '' {
		return 0
	}
	// ISO8601 格式: "2006-01-02T15:04:05.000Z"
	// 简化处理，返回当前时间
	return time.now().unix()
}
