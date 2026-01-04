module hono

import net.http
import time
import sync

// RateLimitEntry 结构体 - 限流条目
pub struct RateLimitEntry {
pub mut:
	count    int   // 当前请求计数
	reset_at i64   // 重置时间（Unix 毫秒时间戳）
}

// RateLimitStore 接口 - 限流存储后端
pub interface RateLimitStore {
mut:
	// increment - 增加计数并返回当前计数和重置时间
	// 参数: key - 客户端标识, window_ms - 时间窗口（毫秒）
	// 返回: (当前计数, 重置时间戳)
	increment(key string, window_ms i64) (int, i64)
	// reset - 重置指定 key 的计数
	reset(key string)
}

// MemoryStore 结构体 - 内存存储实现
pub struct MemoryStore {
mut:
	data map[string]RateLimitEntry
	mtx  sync.Mutex  // 线程安全锁
}

// MemoryStore.new - 创建新的内存存储
pub fn MemoryStore.new() &MemoryStore {
	return &MemoryStore{
		data: map[string]RateLimitEntry{}
	}
}

// increment - 增加计数并返回当前计数和重置时间
pub fn (mut s MemoryStore) increment(key string, window_ms i64) (int, i64) {
	s.mtx.@lock()
	defer { s.mtx.unlock() }
	
	now := time.now().unix_milli()
	
	// 检查是否存在条目
	if key in s.data {
		mut entry := s.data[key]
		
		// 检查是否需要重置（窗口已过期）
		if now >= entry.reset_at {
			// 窗口已过期，重置计数
			entry.count = 1
			entry.reset_at = now + window_ms
		} else {
			// 窗口内，增加计数
			entry.count++
		}
		
		s.data[key] = entry
		return entry.count, entry.reset_at
	}
	
	// 新条目
	new_entry := RateLimitEntry{
		count: 1
		reset_at: now + window_ms
	}
	s.data[key] = new_entry
	
	return new_entry.count, new_entry.reset_at
}

// reset - 重置指定 key 的计数
pub fn (mut s MemoryStore) reset(key string) {
	s.mtx.@lock()
	defer { s.mtx.unlock() }
	
	s.data.delete(key)
}

// get_entry - 获取指定 key 的条目（用于测试）
pub fn (s MemoryStore) get_entry(key string) ?RateLimitEntry {
	if key in s.data {
		return s.data[key]
	}
	return none
}

// cleanup_expired - 清理过期条目（可选的维护方法）
pub fn (mut s MemoryStore) cleanup_expired() {
	s.mtx.@lock()
	defer { s.mtx.unlock() }
	
	now := time.now().unix_milli()
	mut keys_to_delete := []string{}
	
	for key, entry in s.data {
		if now >= entry.reset_at {
			keys_to_delete << key
		}
	}
	
	for key in keys_to_delete {
		s.data.delete(key)
	}
}


// RateLimitOptions 结构体 - 限流配置选项
pub struct RateLimitOptions {
pub:
	window_ms     i64 = 60000                           // 时间窗口（毫秒），默认 1 分钟
	limit         int = 100                             // 窗口内最大请求数，默认 100
	key_generator ?fn (Context) string                  // 客户端标识生成器
	skip          ?fn (Context) bool                    // 跳过限流条件
	handler       ?fn (mut Context, RateLimitInfo) http.Response  // 自定义限流响应
	store         &MemoryStore                          // 存储后端（必需）
	headers       bool = true                           // 是否添加限流头，默认 true
}

// RateLimitInfo 结构体 - 限流信息（传递给自定义 handler）
pub struct RateLimitInfo {
pub:
	limit     int   // 最大请求数
	remaining int   // 剩余请求数
	reset_at  i64   // 重置时间戳（毫秒）
}

// rate_limit - 限流中间件工厂函数
// 返回一个 ContextMiddleware，用于限制请求频率
// 注意：必须提供 store 参数
pub fn rate_limit(options RateLimitOptions) ContextMiddleware {
	mut store := options.store
	
	return fn [options, mut store] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 检查是否跳过限流
		if skip_fn := options.skip {
			if skip_fn(c) {
				return next(mut c)
			}
		}
		
		// 生成客户端标识 key
		key := generate_rate_limit_key(c, options.key_generator)
		
		// 增加计数
		count, reset_at := store.increment(key, options.window_ms)
		
		// 计算剩余请求数
		remaining := if count > options.limit { 0 } else { options.limit - count }
		
		// 设置限流响应头
		if options.headers {
			set_rate_limit_headers(mut c, options.limit, remaining, reset_at)
		}
		
		// 检查是否超过限制
		if count > options.limit {
			// 创建限流信息
			info := RateLimitInfo{
				limit: options.limit
				remaining: 0
				reset_at: reset_at
			}
			
			// 使用自定义 handler 或默认响应
			if custom_handler := options.handler {
				return custom_handler(mut c, info)
			}
			
			return rate_limit_exceeded_response(mut c, reset_at)
		}
		
		// 继续处理请求
		return next(mut c)
	}
}

// generate_rate_limit_key - 生成客户端标识 key
fn generate_rate_limit_key(c Context, key_generator ?fn (Context) string) string {
	// 使用自定义 key 生成器
	if gen_fn := key_generator {
		return gen_fn(c)
	}
	
	// 默认使用客户端 IP
	return c.get_client_ip()
}

// set_rate_limit_headers - 设置限流响应头
fn set_rate_limit_headers(mut c Context, limit int, remaining int, reset_at i64) {
	c.headers['X-RateLimit-Limit'] = limit.str()
	c.headers['X-RateLimit-Remaining'] = remaining.str()
	// 将毫秒时间戳转换为秒（HTTP 标准）
	c.headers['X-RateLimit-Reset'] = (reset_at / 1000).str()
}

// rate_limit_exceeded_response - 返回 429 限流响应
fn rate_limit_exceeded_response(mut c Context, reset_at i64) http.Response {
	c.status(429)
	
	// 计算 Retry-After（秒）
	now := time.now().unix_milli()
	retry_after := if reset_at > now { (reset_at - now) / 1000 } else { i64(0) }
	if retry_after > 0 {
		c.headers['Retry-After'] = retry_after.str()
	}
	
	return c.json('{"error":"Too Many Requests","message":"Rate limit exceeded. Please try again later."}')
}

// get_rate_limit_info - 从 Context 获取限流信息
// 这是一个便捷方法，用于在 handler 中获取当前请求的限流状态
pub fn get_rate_limit_info(c Context) ?RateLimitInfo {
	limit_str := c.headers['X-RateLimit-Limit'] or { return none }
	remaining_str := c.headers['X-RateLimit-Remaining'] or { return none }
	reset_str := c.headers['X-RateLimit-Reset'] or { return none }
	
	return RateLimitInfo{
		limit: limit_str.int()
		remaining: remaining_str.int()
		reset_at: reset_str.i64() * 1000  // 转换回毫秒
	}
}
