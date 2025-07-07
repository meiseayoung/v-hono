module hono

// Context LRU 缓存节点
@[heap]
struct ContextLRUCacheNode {
pub mut:
	key   string
	value ContextRouteMatch
	prev  &ContextLRUCacheNode = unsafe { nil }
	next  &ContextLRUCacheNode = unsafe { nil }
}

// Context LRU 缓存
pub struct ContextLRUCache {
mut:
	capacity int
	size     int
	cache    map[string]&ContextLRUCacheNode
	head     &ContextLRUCacheNode = unsafe { nil }
	tail     &ContextLRUCacheNode = unsafe { nil }
}

// ContextLRUCache 构造函数
pub fn ContextLRUCache.new(capacity int) ContextLRUCache {
	return ContextLRUCache{
		capacity: capacity
		size: 0
		cache: map[string]&ContextLRUCacheNode{}
	}
}

// 获取缓存值
pub fn (mut cache ContextLRUCache) get(key string) ?ContextRouteMatch {
	if mut node := cache.cache[key] {
		cache.move_to_front(mut node)
		return node.value
	}
	return none
}

// 设置缓存值
pub fn (mut cache ContextLRUCache) put(key string, value ContextRouteMatch) {
	if mut node := cache.cache[key] {
		node.value = value
		cache.move_to_front(mut node)
		return
	}
	
	if cache.size >= cache.capacity {
		cache.remove_tail()
	}
	
	mut new_node := &ContextLRUCacheNode{
		key: key
		value: value
	}
	
	cache.cache[key] = new_node
	cache.add_to_front(mut new_node)
	cache.size++
}

// 移动到链表头部
fn (mut cache ContextLRUCache) move_to_front(mut node ContextLRUCacheNode) {
	if node == cache.head {
		return
	}
	
	// 从当前位置移除
	if node.prev != unsafe { nil } {
		mut prev := node.prev
		prev.next = node.next
	}
	if node.next != unsafe { nil } {
		mut next := node.next
		next.prev = node.prev
	}
	
	// 如果是尾节点
	if node == cache.tail {
		cache.tail = node.prev
	}
	
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

// 移除链表尾部
fn (mut cache ContextLRUCache) remove_tail() {
	if cache.tail == unsafe { nil } {
		return
	}
	
	key := cache.tail.key
	cache.cache.delete(key)
	
	if cache.head == cache.tail {
		cache.head = unsafe { nil }
		cache.tail = unsafe { nil }
	} else {
		cache.tail = cache.tail.prev
		if cache.tail != unsafe { nil } {
			mut tail := cache.tail
			tail.next = unsafe { nil }
		}
	}
	
	cache.size--
}

// 获取缓存统计信息
pub fn (cache ContextLRUCache) get_stats() (int, int) {
	return cache.size, cache.capacity
}

// 清理缓存
pub fn (mut cache ContextLRUCache) clear() {
	cache.cache.clear()
	cache.head = unsafe { nil }
	cache.tail = unsafe { nil }
	cache.size = 0
} 