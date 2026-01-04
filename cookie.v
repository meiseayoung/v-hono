module hono

import time
import crypto.sha256
import encoding.base64

// SameSite 枚举 - Cookie 的 SameSite 属性
pub enum SameSite {
	strict
	lax
	none_
}

// CookieOptions 结构体 - Cookie 配置选项
pub struct CookieOptions {
pub:
	path      string    = '/'
	domain    string
	max_age   int                    // 秒
	expires   ?time.Time
	http_only bool
	secure    bool
	same_site SameSite  = .lax
}

// get_cookie - 从请求中获取指定名称的 Cookie 值
// 返回 Cookie 值，如果不存在则返回 none
pub fn get_cookie(c Context, name string) ?string {
	cookie_header := c.req.header.get_custom('Cookie') or { return none }
	
	if cookie_header.len == 0 {
		return none
	}
	
	// 解析 Cookie 头
	cookies := parse_cookie_header(cookie_header)
	
	if name in cookies {
		return cookies[name]
	}
	
	return none
}

// get_all_cookies - 获取请求中的所有 Cookie
// 返回一个 map，包含所有 Cookie 的名称和值
pub fn get_all_cookies(c Context) map[string]string {
	cookie_header := c.req.header.get_custom('Cookie') or { return map[string]string{} }
	
	if cookie_header.len == 0 {
		return map[string]string{}
	}
	
	return parse_cookie_header(cookie_header)
}


// set_cookie - 设置 Cookie
// 将 Cookie 添加到响应的 Set-Cookie 头中
pub fn set_cookie(mut c Context, name string, value string, options ...CookieOptions) {
	opts := if options.len > 0 { options[0] } else { CookieOptions{} }
	
	cookie_str := build_cookie_string(name, value, opts)
	
	// 添加到响应头
	// 如果已经有 Set-Cookie 头，需要追加
	if existing := c.headers['Set-Cookie'] {
		c.headers['Set-Cookie'] = '${existing}, ${cookie_str}'
	} else {
		c.headers['Set-Cookie'] = cookie_str
	}
}

// delete_cookie - 删除 Cookie
// 通过设置过期时间为过去的时间来删除 Cookie
pub fn delete_cookie(mut c Context, name string, options ...CookieOptions) {
	mut opts := if options.len > 0 { options[0] } else { CookieOptions{} }
	
	// 设置 max_age 为 0 或负数，并设置过期时间为过去
	expired_time := time.unix(0)
	
	// 创建新的选项，保留 path 和 domain，但设置过期
	delete_opts := CookieOptions{
		path: opts.path
		domain: opts.domain
		max_age: 0
		expires: expired_time
		http_only: opts.http_only
		secure: opts.secure
		same_site: opts.same_site
	}
	
	cookie_str := build_cookie_string(name, '', delete_opts)
	
	if existing := c.headers['Set-Cookie'] {
		c.headers['Set-Cookie'] = '${existing}, ${cookie_str}'
	} else {
		c.headers['Set-Cookie'] = cookie_str
	}
}

// parse_cookie_header - 解析 Cookie 请求头
// 将 "name1=value1; name2=value2" 格式解析为 map
fn parse_cookie_header(header string) map[string]string {
	mut cookies := map[string]string{}
	
	// 按分号分割
	pairs := header.split(';')
	
	for pair in pairs {
		trimmed := pair.trim_space()
		if trimmed.len == 0 {
			continue
		}
		
		// 找到第一个等号的位置
		eq_pos := trimmed.index('=') or { continue }
		
		if eq_pos == 0 {
			continue
		}
		
		name := trimmed[..eq_pos].trim_space()
		value := if eq_pos + 1 < trimmed.len {
			trimmed[eq_pos + 1..].trim_space()
		} else {
			''
		}
		
		// 移除值两端的引号（如果有）
		cleaned_value := if value.len >= 2 && value[0] == `"` && value[value.len - 1] == `"` {
			value[1..value.len - 1]
		} else {
			value
		}
		
		cookies[name] = cleaned_value
	}
	
	return cookies
}


// build_cookie_string - 构建 Set-Cookie 头的值
fn build_cookie_string(name string, value string, opts CookieOptions) string {
	mut parts := []string{}
	
	// 基本的 name=value
	parts << '${name}=${value}'
	
	// Path
	if opts.path.len > 0 {
		parts << 'Path=${opts.path}'
	}
	
	// Domain
	if opts.domain.len > 0 {
		parts << 'Domain=${opts.domain}'
	}
	
	// Max-Age
	if opts.max_age != 0 {
		parts << 'Max-Age=${opts.max_age}'
	}
	
	// Expires
	if expires := opts.expires {
		// 格式化为 HTTP 日期格式: Wed, 09 Jun 2021 10:18:14 GMT
		expires_str := format_cookie_date(expires)
		parts << 'Expires=${expires_str}'
	}
	
	// HttpOnly
	if opts.http_only {
		parts << 'HttpOnly'
	}
	
	// Secure
	if opts.secure {
		parts << 'Secure'
	}
	
	// SameSite
	match opts.same_site {
		.strict { parts << 'SameSite=Strict' }
		.lax { parts << 'SameSite=Lax' }
		.none_ { parts << 'SameSite=None' }
	}
	
	return parts.join('; ')
}

// format_cookie_date - 格式化时间为 Cookie 日期格式
// 格式: Wed, 09 Jun 2021 10:18:14 GMT
fn format_cookie_date(t time.Time) string {
	days := ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	
	day_name := days[t.day_of_week()]
	month_name := months[t.month - 1]
	
	return '${day_name}, ${t.day:02} ${month_name} ${t.year} ${t.hour:02}:${t.minute:02}:${t.second:02} GMT'
}

// set_signed_cookie - 设置签名 Cookie
// 使用 HMAC-SHA256 对 Cookie 值进行签名
pub fn set_signed_cookie(mut c Context, name string, value string, secret string, options ...CookieOptions) ! {
	if secret.len == 0 {
		return error('Secret is required for signed cookies')
	}
	
	// 生成签名
	signature := generate_hmac_signature(value, secret)
	
	// 将值和签名组合: value.signature
	signed_value := '${value}.${signature}'
	
	opts := if options.len > 0 { options[0] } else { CookieOptions{} }
	set_cookie(mut c, name, signed_value, opts)
}

// get_signed_cookie - 获取并验证签名 Cookie
// 验证签名，如果有效则返回原始值，否则返回错误
pub fn get_signed_cookie(c Context, name string, secret string) !string {
	if secret.len == 0 {
		return error('Secret is required for signed cookies')
	}
	
	// 获取 Cookie 值
	signed_value := get_cookie(c, name) or {
		return error('Cookie not found: ${name}')
	}
	
	// 分离值和签名
	dot_pos := signed_value.last_index('.') or {
		return error('Invalid signed cookie format')
	}
	
	if dot_pos == 0 || dot_pos >= signed_value.len - 1 {
		return error('Invalid signed cookie format')
	}
	
	value := signed_value[..dot_pos]
	signature := signed_value[dot_pos + 1..]
	
	// 验证签名
	expected_signature := generate_hmac_signature(value, secret)
	
	if !constant_time_compare(signature, expected_signature) {
		return error('Invalid signature')
	}
	
	return value
}


// generate_hmac_signature - 使用 HMAC-SHA256 生成签名
fn generate_hmac_signature(value string, secret string) string {
	// 手动实现 HMAC-SHA256
	// HMAC(K, m) = H((K' ⊕ opad) || H((K' ⊕ ipad) || m))
	// 其中 K' 是处理后的密钥，ipad = 0x36, opad = 0x5c
	
	block_size := 64 // SHA256 块大小
	
	// 处理密钥
	mut key := secret.bytes()
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
	inner_data << value.bytes()
	inner_hash_result := sha256.sum(inner_data)
	mut inner_hash := []u8{len: 32}
	for i := 0; i < 32; i++ {
		inner_hash[i] = inner_hash_result[i]
	}
	
	// 计算外部哈希: H((K' ⊕ opad) || inner_hash)
	mut outer_data := o_key_pad.clone()
	outer_data << inner_hash
	outer_hash_result := sha256.sum(outer_data)
	mut outer_hash := []u8{len: 32}
	for i := 0; i < 32; i++ {
		outer_hash[i] = outer_hash_result[i]
	}
	
	// Base64URL 编码（不带填充）
	return base64.url_encode(outer_hash).replace('=', '')
}

// constant_time_compare - 常量时间比较，防止时序攻击
fn constant_time_compare(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	
	mut result := u8(0)
	for i := 0; i < a.len; i++ {
		result |= a[i] ^ b[i]
	}
	
	return result == 0
}
