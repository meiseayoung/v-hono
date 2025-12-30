module hono

import time

// Context LRU 缓存节点
@[heap]
struct ContextLRUCacheNode {
pub mut:
	key        string
	value      ContextRouteMatch
	prev       &ContextLRUCacheNode = unsafe { nil }
	next       &ContextLRUCacheNode = unsafe { nil }
	created_at i64  // 添加创建时间戳
	last_access i64 // 添加最后访问时间
}

// Context LRU 缓存
pub struct ContextLRUCache {
mut:
	capacity        int
	size           int
	cache          map[string]&ContextLRUCacheNode
	head           &ContextLRUCacheNode = unsafe { nil }
	tail           &ContextLRUCacheNode = unsafe { nil }
	ttl_seconds    i64 = 3600  // TTL: 1小时，0表示不过期
	last_cleanup   i64         // 上次清理过期条目的时间
	cleanup_interval i64 = 300 // 清理间隔: 5分钟
}

// ContextLRUCache 构造函数
pub fn ContextLRUCache.new(capacity int) ContextLRUCache {
	return ContextLRUCache{
		capacity: capacity
		size: 0
		cache: map[string]&ContextLRUCacheNode{}
		ttl_seconds: 3600
		last_cleanup: time.now().unix()
		cleanup_interval: 300
	}
}

// 创建带自定义TTL的缓存
pub fn ContextLRUCache.new_with_ttl(capacity int, ttl_seconds i64) ContextLRUCache {
	return ContextLRUCache{
		capacity: capacity
		size: 0
		cache: map[string]&ContextLRUCacheNode{}
		ttl_seconds: ttl_seconds
		last_cleanup: time.now().unix()
		cleanup_interval: 300
	}
}

// 获取缓存值
pub fn (mut cache ContextLRUCache) get(key string) ?ContextRouteMatch {
	// 定期清理过期条目
	cache.cleanup_expired_if_needed()
	
	if mut node := cache.cache[key] {
		// 检查是否过期
		if cache.is_expired(node) {
			cache.remove_node(mut node)
			return none
		}
		
		// 更新访问时间
		node.last_access = time.now().unix()
		cache.move_to_front(mut node)
		return node.value
	}
	return none
}

// 设置缓存值
pub fn (mut cache ContextLRUCache) put(key string, value ContextRouteMatch) {
	// 定期清理过期条目
	cache.cleanup_expired_if_needed()
	
	if mut node := cache.cache[key] {
		// 更新现有节点
		node.value = value
		node.last_access = time.now().unix()
		cache.move_to_front(mut node)
		return
	}
	
	// 如果超出容量，先移除最久未使用的节点
	if cache.size >= cache.capacity {
		cache.remove_tail()
	}
	
	// 创建新节点
	now := time.now().unix()
	mut new_node := &ContextLRUCacheNode{
		key: key
		value: value
		created_at: now
		last_access: now
	}
	
	cache.cache[key] = new_node
	cache.add_to_front(mut new_node)
	cache.size++
}

// 移动到链表头部
fn (mut cache ContextLRUCache) move_to_front(mut node ContextLRUCacheNode) {
	// 如果已经是头节点，直接返回
	if unsafe { voidptr(node) == voidptr(cache.head) } {
		return
	}
	
	// 安全地从当前位置移除
	if node.prev != unsafe { nil } {
		mut prev := node.prev
		prev.next = node.next
	}
	if node.next != unsafe { nil } {
		mut next := node.next
		next.prev = node.prev
	}
	
	// 如果是尾节点，更新尾指针
	if unsafe { voidptr(node) == voidptr(cache.tail) } {
		cache.tail = node.prev
	}
	
	// 添加到头部
	cache.add_to_front(mut node)
}

// 添加到链表头部
fn (mut cache ContextLRUCache) add_to_front(mut node ContextLRUCacheNode) {
	node.next = cache.head
	node.prev = unsafe { nil }
	
	if cache.head != unsafe { nil } {
		mut head := cache.head
		head.prev = node
	}
	
	cache.head = node
	
	if cache.tail == unsafe { nil } {
		cache.tail = node
	}
}

// 移除链表尾部（内存安全版本）
fn (mut cache ContextLRUCache) remove_tail() {
	if cache.tail == unsafe { nil } {
		return
	}
	
	// 使用通用的节点移除方法
	mut tail_node := cache.tail
	cache.remove_node(mut tail_node)
}

// 安全移除指定节点
fn (mut cache ContextLRUCache) remove_node(mut node ContextLRUCacheNode) {
	if node.key == '' {
		return // 避免移除已被清理的节点
	}
	
	// 先从哈希表中移除，避免悬空指针
	cache.cache.delete(node.key)
	
	// 安全更新链表指针
	if node.prev != unsafe { nil } {
		mut prev := node.prev
		prev.next = node.next
	} else {
		// 这是头节点
		cache.head = node.next
	}
	
	if node.next != unsafe { nil } {
		mut next := node.next
		next.prev = node.prev
	} else {
		// 这是尾节点
		cache.tail = node.prev
	}
	
	// 彻底清理节点引用，防止内存泄漏
	node.prev = unsafe { nil }
	node.next = unsafe { nil }
	node.key = '' // 清空key作为已清理的标记
	
	// 更新大小计数
	if cache.size > 0 {
		cache.size--
	}
}

// 获取缓存统计信息
pub fn (cache ContextLRUCache) get_stats() (int, int) {
	return cache.size, cache.capacity
}

// 获取详细的缓存统计信息
pub fn (mut cache ContextLRUCache) get_detailed_stats() map[string]i64 {
	// 先清理过期条目再统计
	cache.cleanup_expired_if_needed()
	
	mut expired_count := i64(0)
	
	// 统计过期条目数量
	if cache.ttl_seconds > 0 {
		for _, node in cache.cache {
			if cache.is_expired(node) {
				expired_count++
			}
		}
	}
	
	return {
		'size': i64(cache.size)
		'capacity': i64(cache.capacity)
		'expired_count': expired_count
		'ttl_seconds': cache.ttl_seconds
		'last_cleanup': cache.last_cleanup
		'cleanup_interval': cache.cleanup_interval
		'memory_usage_estimate': i64(cache.size * 200) // 粗略估算，每个节点约200字节
	}
}

// 设置TTL
pub fn (mut cache ContextLRUCache) set_ttl(ttl_seconds i64) {
	cache.ttl_seconds = ttl_seconds
}

// 设置清理间隔
pub fn (mut cache ContextLRUCache) set_cleanup_interval(interval_seconds i64) {
	cache.cleanup_interval = interval_seconds
}

// 检查缓存是否健康
pub fn (mut cache ContextLRUCache) is_healthy() bool {
	// 检查基本状态
	if cache.size == 0 {
		return cache.head == unsafe { nil } && cache.tail == unsafe { nil } && cache.cache.len == 0
	}
	
	// 检查头尾指针
	if cache.head == unsafe { nil } || cache.tail == unsafe { nil } {
		return false
	}
	
	// 检查哈希表和链表大小一致
	if cache.cache.len != cache.size {
		return false
	}
	
	// 检查链表完整性
	mut count := 0
	mut current := cache.head
	for current != unsafe { nil } {
		count++
		if count > cache.size {
			return false // 检测到循环引用
		}
		current = current.next
	}
	
	return count == cache.size
}

// 检查节点是否过期
fn (cache ContextLRUCache) is_expired(node &ContextLRUCacheNode) bool {
	if cache.ttl_seconds <= 0 {
		return false // TTL为0表示不过期
	}
	now := time.now().unix()
	return (now - node.last_access) > cache.ttl_seconds
}

// 如果需要，清理过期条目
fn (mut cache ContextLRUCache) cleanup_expired_if_needed() {
	now := time.now().unix()
	if (now - cache.last_cleanup) > cache.cleanup_interval {
		cache.cleanup_expired_entries()
		cache.last_cleanup = now
	}
}

// 清理所有过期条目
fn (mut cache ContextLRUCache) cleanup_expired_entries() {
	if cache.ttl_seconds <= 0 {
		return // TTL为0表示不过期
	}
	
	mut expired_keys := []string{}
	
	// 收集过期的key
	for key, node in cache.cache {
		if cache.is_expired(node) {
			expired_keys << key
		}
	}
	
	// 移除过期节点
	for key in expired_keys {
		if mut node := cache.cache[key] {
			cache.remove_node(mut node)
		}
	}
}

// 强制清理所有过期条目（公开方法）
pub fn (mut cache ContextLRUCache) force_cleanup_expired() {
	cache.cleanup_expired_entries()
}

// 安全清理所有缓存（内存安全版本）
pub fn (mut cache ContextLRUCache) clear() {
	// 逐个安全清理节点引用
	mut current := cache.head
	for current != unsafe { nil } {
		mut next := current.next
		
		// 彻底清理当前节点的所有引用
		current.prev = unsafe { nil }
		current.next = unsafe { nil }
		current.key = ''
		// 清空 value 中的数据（如果需要的话）
		
		current = next
	}
	
	// 清空哈希表和指针
	cache.cache.clear()
	cache.head = unsafe { nil }
	cache.tail = unsafe { nil }
	cache.size = 0
	cache.last_cleanup = time.now().unix()
}
