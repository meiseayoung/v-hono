module hono

import crypto.sha256
import crypto.sha512
import encoding.base64
import net.http
import time
import x.json2

// JwtAlgorithm 枚举 - 支持的 JWT 签名算法
pub enum JwtAlgorithm {
	hs256
	hs384
	hs512
}

// JwtVerifyOptions 结构体 - JWT 验证选项
pub struct JwtVerifyOptions {
pub:
	iss string        // 发行者验证
	exp bool = true   // 验证过期时间
	nbf bool = true   // 验证生效时间
	iat bool = true   // 验证签发时间
}

// JwtOptions 结构体 - JWT 中间件配置选项
pub struct JwtOptions {
pub:
	secret         string                              // 密钥（必需）
	alg            JwtAlgorithm = .hs256              // 算法
	cookie         string                              // 从 cookie 读取 token
	header_name    string       = 'Authorization'     // 请求头名称
	verify_options JwtVerifyOptions = JwtVerifyOptions{}
}

// JwtPayload 结构体 - JWT 载荷
pub struct JwtPayload {
pub mut:
	sub    string              // Subject
	iss    string              // Issuer
	aud    string              // Audience
	exp    i64                 // Expiration Time (Unix timestamp)
	nbf    i64                 // Not Before (Unix timestamp)
	iat    i64                 // Issued At (Unix timestamp)
	jti    string              // JWT ID
	claims map[string]string   // 自定义声明
}

// JwtHeader 结构体 - JWT 头部
struct JwtHeader {
	alg string
	typ string
}

// JwtToken 结构体 - 完整的 JWT Token
struct JwtToken {
	header    JwtHeader
	payload   JwtPayload
	signature string
}

// base64url_encode - Base64URL 编码（不带填充）
fn base64url_encode(data []u8) string {
	encoded := base64.encode(data)
	// 转换为 URL 安全格式并移除填充
	return encoded.replace('+', '-').replace('/', '_').trim_right('=')
}

// base64url_decode - Base64URL 解码
fn base64url_decode(data string) ![]u8 {
	// 转换回标准 Base64 格式
	mut standard := data.replace('-', '+').replace('_', '/')
	// 添加填充
	padding := (4 - standard.len % 4) % 4
	for _ in 0 .. padding {
		standard += '='
	}
	return base64.decode(standard)
}

// hmac_sha256 - HMAC-SHA256 签名
fn hmac_sha256(message []u8, secret []u8) []u8 {
	block_size := 64 // SHA256 块大小

	// 处理密钥
	mut key := secret.clone()
	if key.len > block_size {
		// 如果密钥太长，先哈希
		hash_result := sha256.sum(key)
		key = []u8{len: 32}
		for i := 0; i < 32; i++ {
			key[i] = hash_result[i]
		}
	}
	// 填充到块大小
	for key.len < block_size {
		key << u8(0)
	}

	// 计算 K' ⊕ ipad
	mut i_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		i_key_pad[i] = key[i] ^ u8(0x36)
	}

	// 计算 K' ⊕ opad
	mut o_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		o_key_pad[i] = key[i] ^ u8(0x5c)
	}

	// 计算内部哈希: H((K' ⊕ ipad) || m)
	mut inner_data := i_key_pad.clone()
	inner_data << message
	inner_hash_result := sha256.sum(inner_data)
	mut inner_hash := []u8{len: 32}
	for i := 0; i < 32; i++ {
		inner_hash[i] = inner_hash_result[i]
	}

	// 计算外部哈希: H((K' ⊕ opad) || inner_hash)
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha256.sum(outer_data)
	mut result := []u8{len: 32}
	for i := 0; i < 32; i++ {
		result[i] = outer_hash_result[i]
	}

	return result
}


// hmac_sha384 - HMAC-SHA384 签名
fn hmac_sha384(message []u8, secret []u8) []u8 {
	block_size := 128 // SHA384 块大小

	// 处理密钥
	mut key := secret.clone()
	if key.len > block_size {
		// 如果密钥太长，先哈希
		hash_result := sha512.sum384(key)
		key = []u8{len: 48}
		for i := 0; i < 48; i++ {
			key[i] = hash_result[i]
		}
	}
	// 填充到块大小
	for key.len < block_size {
		key << u8(0)
	}

	// 计算 K' ⊕ ipad
	mut i_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		i_key_pad[i] = key[i] ^ u8(0x36)
	}

	// 计算 K' ⊕ opad
	mut o_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		o_key_pad[i] = key[i] ^ u8(0x5c)
	}

	// 计算内部哈希
	mut inner_data := i_key_pad.clone()
	inner_data << message
	inner_hash_result := sha512.sum384(inner_data)
	mut inner_hash := []u8{len: 48}
	for i := 0; i < 48; i++ {
		inner_hash[i] = inner_hash_result[i]
	}

	// 计算外部哈希
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha512.sum384(outer_data)
	mut result := []u8{len: 48}
	for i := 0; i < 48; i++ {
		result[i] = outer_hash_result[i]
	}

	return result
}

// hmac_sha512 - HMAC-SHA512 签名
fn hmac_sha512(message []u8, secret []u8) []u8 {
	block_size := 128 // SHA512 块大小

	// 处理密钥
	mut key := secret.clone()
	if key.len > block_size {
		// 如果密钥太长，先哈希
		hash_result := sha512.sum512(key)
		key = []u8{len: 64}
		for i := 0; i < 64; i++ {
			key[i] = hash_result[i]
		}
	}
	// 填充到块大小
	for key.len < block_size {
		key << u8(0)
	}

	// 计算 K' ⊕ ipad
	mut i_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		i_key_pad[i] = key[i] ^ u8(0x36)
	}

	// 计算 K' ⊕ opad
	mut o_key_pad := []u8{len: block_size}
	for i := 0; i < block_size; i++ {
		o_key_pad[i] = key[i] ^ u8(0x5c)
	}

	// 计算内部哈希
	mut inner_data := i_key_pad.clone()
	inner_data << message
	inner_hash_result := sha512.sum512(inner_data)
	mut inner_hash := []u8{len: 64}
	for i := 0; i < 64; i++ {
		inner_hash[i] = inner_hash_result[i]
	}

	// 计算外部哈希
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha512.sum512(outer_data)
	mut result := []u8{len: 64}
	for i := 0; i < 64; i++ {
		result[i] = outer_hash_result[i]
	}

	return result
}

// sign_message - 根据算法签名消息
fn sign_message(message []u8, secret []u8, alg JwtAlgorithm) []u8 {
	return match alg {
		.hs256 { hmac_sha256(message, secret) }
		.hs384 { hmac_sha384(message, secret) }
		.hs512 { hmac_sha512(message, secret) }
	}
}

// alg_to_string - 将算法枚举转换为字符串
fn alg_to_string(alg JwtAlgorithm) string {
	return match alg {
		.hs256 { 'HS256' }
		.hs384 { 'HS384' }
		.hs512 { 'HS512' }
	}
}

// string_to_alg - 将字符串转换为算法枚举
fn string_to_alg(s string) !JwtAlgorithm {
	return match s {
		'HS256' { JwtAlgorithm.hs256 }
		'HS384' { JwtAlgorithm.hs384 }
		'HS512' { JwtAlgorithm.hs512 }
		else { error('Unsupported algorithm: ${s}') }
	}
}


// sign_jwt - 创建并签名 JWT token
// 返回格式: header.payload.signature
pub fn sign_jwt(payload JwtPayload, secret string, alg JwtAlgorithm) !string {
	if secret.len == 0 {
		return error('Secret is required')
	}

	// 构建 header
	header := JwtHeader{
		alg: alg_to_string(alg)
		typ: 'JWT'
	}

	// 编码 header
	header_json := '{"alg":"${header.alg}","typ":"${header.typ}"}'
	header_encoded := base64url_encode(header_json.bytes())

	// 编码 payload
	payload_json := encode_payload(payload)
	payload_encoded := base64url_encode(payload_json.bytes())

	// 创建签名输入
	signing_input := '${header_encoded}.${payload_encoded}'

	// 签名
	signature := sign_message(signing_input.bytes(), secret.bytes(), alg)
	signature_encoded := base64url_encode(signature)

	return '${signing_input}.${signature_encoded}'
}

// encode_payload - 将 JwtPayload 编码为 JSON 字符串
fn encode_payload(payload JwtPayload) string {
	mut parts := []string{}

	if payload.sub.len > 0 {
		parts << '"sub":"${escape_json_string(payload.sub)}"'
	}
	if payload.iss.len > 0 {
		parts << '"iss":"${escape_json_string(payload.iss)}"'
	}
	if payload.aud.len > 0 {
		parts << '"aud":"${escape_json_string(payload.aud)}"'
	}
	if payload.exp != 0 {
		parts << '"exp":${payload.exp}'
	}
	if payload.nbf != 0 {
		parts << '"nbf":${payload.nbf}'
	}
	if payload.iat != 0 {
		parts << '"iat":${payload.iat}'
	}
	if payload.jti.len > 0 {
		parts << '"jti":"${escape_json_string(payload.jti)}"'
	}

	// 添加自定义声明
	for key, value in payload.claims {
		parts << '"${escape_json_string(key)}":"${escape_json_string(value)}"'
	}

	return '{${parts.join(",")}}'
}

// escape_json_string - 转义 JSON 字符串中的特殊字符
fn escape_json_string(s string) string {
	mut result := []u8{}
	for c in s.bytes() {
		match c {
			`"` { result << `\\`; result << `"` }
			`\\` { result << `\\`; result << `\\` }
			`\n` { result << `\\`; result << `n` }
			`\r` { result << `\\`; result << `r` }
			`\t` { result << `\\`; result << `t` }
			else { result << c }
		}
	}
	return result.bytestr()
}

// decode_jwt - 解码 JWT token（不验证签名）
// 返回解码后的 payload
pub fn decode_jwt(token string) !JwtPayload {
	parts := token.split('.')
	if parts.len != 3 {
		return error('Invalid token format')
	}

	// 解码 payload
	payload_bytes := base64url_decode(parts[1])!
	payload_json := payload_bytes.bytestr()

	return parse_payload(payload_json)
}

// parse_payload - 解析 JSON payload 为 JwtPayload 结构体
fn parse_payload(json_str string) !JwtPayload {
	raw := json2.decode[json2.Any](json_str) or {
		return error('Invalid JSON payload: ${err}')
	}

	obj := raw.as_map()

	mut payload := JwtPayload{
		claims: map[string]string{}
	}

	// 解析标准声明
	if 'sub' in obj {
		payload.sub = obj['sub'] or { json2.Any('') }.str()
	}
	if 'iss' in obj {
		payload.iss = obj['iss'] or { json2.Any('') }.str()
	}
	if 'aud' in obj {
		payload.aud = obj['aud'] or { json2.Any('') }.str()
	}
	if 'exp' in obj {
		payload.exp = (obj['exp'] or { json2.Any(0) }).i64()
	}
	if 'nbf' in obj {
		payload.nbf = (obj['nbf'] or { json2.Any(0) }).i64()
	}
	if 'iat' in obj {
		payload.iat = (obj['iat'] or { json2.Any(0) }).i64()
	}
	if 'jti' in obj {
		payload.jti = obj['jti'] or { json2.Any('') }.str()
	}

	// 解析自定义声明
	standard_claims := ['sub', 'iss', 'aud', 'exp', 'nbf', 'iat', 'jti']
	for key, value in obj {
		if key !in standard_claims {
			payload.claims[key] = value.str()
		}
	}

	return payload
}


// verify_jwt - 验证 JWT token 并返回 payload
// 验证签名、过期时间、生效时间等
pub fn verify_jwt(token string, secret string, alg JwtAlgorithm) !JwtPayload {
	if secret.len == 0 {
		return error('Secret is required')
	}

	parts := token.split('.')
	if parts.len != 3 {
		return error('Invalid token format')
	}

	// 解码 header 并验证算法
	header_bytes := base64url_decode(parts[0])!
	header_json := header_bytes.bytestr()
	header_raw := json2.decode[json2.Any](header_json) or {
		return error('Invalid header JSON: ${err}')
	}
	header_obj := header_raw.as_map()

	token_alg_str := (header_obj['alg'] or { json2.Any('') }).str()
	token_alg := string_to_alg(token_alg_str)!

	// 验证算法一致性
	if token_alg != alg {
		return error('Algorithm mismatch: expected ${alg_to_string(alg)}, got ${token_alg_str}')
	}

	// 验证签名
	signing_input := '${parts[0]}.${parts[1]}'
	expected_signature := sign_message(signing_input.bytes(), secret.bytes(), alg)
	expected_signature_encoded := base64url_encode(expected_signature)

	if !constant_time_compare_jwt(parts[2], expected_signature_encoded) {
		return error('Invalid signature')
	}

	// 解码 payload
	payload := decode_jwt(token)!

	return payload
}

// verify_jwt_with_options - 带选项的 JWT 验证
// 验证签名、过期时间、生效时间、发行者等
pub fn verify_jwt_with_options(token string, secret string, alg JwtAlgorithm, options JwtVerifyOptions) !JwtPayload {
	// 先进行基本验证
	payload := verify_jwt(token, secret, alg)!

	now := time.now().unix()

	// 验证过期时间
	if options.exp && payload.exp != 0 {
		if now > payload.exp {
			return error('Token expired')
		}
	}

	// 验证生效时间
	if options.nbf && payload.nbf != 0 {
		if now < payload.nbf {
			return error('Token not yet valid')
		}
	}

	// 验证发行者
	if options.iss.len > 0 {
		if payload.iss != options.iss {
			return error('Invalid issuer: expected ${options.iss}, got ${payload.iss}')
		}
	}

	return payload
}

// constant_time_compare_jwt - 常量时间比较，防止时序攻击
fn constant_time_compare_jwt(a string, b string) bool {
	if a.len != b.len {
		return false
	}

	mut result := u8(0)
	for i := 0; i < a.len; i++ {
		result |= a[i] ^ b[i]
	}

	return result == 0
}


// jwt - JWT 中间件工厂函数
// 返回一个 ContextMiddleware，用于验证 JWT token
pub fn jwt_middleware(options JwtOptions) ContextMiddleware {
	return fn [options] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 获取 token
		token := get_jwt_token(c, options) or {
			c.status(401)
			return c.json('{"error":"Unauthorized","message":"${err}"}')
		}

		// 验证 token
		payload := verify_jwt_with_options(token, options.secret, options.alg, options.verify_options) or {
			c.status(401)
			return c.json('{"error":"Unauthorized","message":"${err}"}')
		}

		// 将 payload 存储到 Context
		store_jwt_payload(mut c, payload)

		// 继续处理请求
		return next(mut c)
	}
}

// get_jwt_token - 从请求中获取 JWT token
fn get_jwt_token(c Context, options JwtOptions) !string {
	// 优先从 Cookie 读取
	if options.cookie.len > 0 {
		if cookie_token := get_cookie(c, options.cookie) {
			return cookie_token
		}
	}

	// 从 header 读取
	header_value := c.req.header.get_custom(options.header_name) or {
		return error('Missing authorization header')
	}

	if header_value.len == 0 {
		return error('Missing authorization header')
	}

	// 解析 Bearer token
	if header_value.starts_with('Bearer ') {
		token := header_value[7..].trim_space()
		if token.len == 0 {
			return error('Invalid token format')
		}
		return token
	}

	// 如果不是 Bearer 格式，直接返回整个值
	return header_value
}

// store_jwt_payload - 将 JWT payload 存储到 Context
fn store_jwt_payload(mut c Context, payload JwtPayload) {
	// 存储标准声明
	if payload.sub.len > 0 {
		c.set('jwt_sub', payload.sub)
	}
	if payload.iss.len > 0 {
		c.set('jwt_iss', payload.iss)
	}
	if payload.aud.len > 0 {
		c.set('jwt_aud', payload.aud)
	}
	if payload.exp != 0 {
		c.set('jwt_exp', payload.exp.str())
	}
	if payload.nbf != 0 {
		c.set('jwt_nbf', payload.nbf.str())
	}
	if payload.iat != 0 {
		c.set('jwt_iat', payload.iat.str())
	}
	if payload.jti.len > 0 {
		c.set('jwt_jti', payload.jti)
	}

	// 存储自定义声明
	for key, value in payload.claims {
		c.set('jwt_${key}', value)
	}

	// 存储完整的 payload JSON（便于获取）
	c.set('jwt_payload', encode_payload(payload))
}

// get_jwt_payload - 从 Context 获取 JWT payload
// 这是一个便捷方法，用于在 handler 中获取已验证的 JWT payload
pub fn get_jwt_payload(c Context) ?JwtPayload {
	payload_json := c.get('jwt_payload') or { return none }
	payload := parse_payload(payload_json) or { return none }
	return payload
}

// get_jwt_claim - 从 Context 获取单个 JWT 声明
pub fn get_jwt_claim(c Context, key string) ?string {
	return c.get('jwt_${key}')
}
