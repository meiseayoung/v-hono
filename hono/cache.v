module hono

// 简化的LRU缓存实现
pub struct LRUCache {
mut:
	capacity int
	cache    map[string]RouteMatch
	keys     []string // 维护访问顺序
}



pub fn new_lru_cache(capacity int) LRUCache {
	return LRUCache{
		capacity: capacity
		cache: map[string]RouteMatch{}
		keys: []string{}
	}
}

pub fn (mut cache LRUCache) get(key string) ?RouteMatch {
	if key in cache.cache {
		// 移动到列表末尾（最近使用）
		idx := cache.keys.index(key)
		if idx != -1 {
			cache.keys.delete(idx)
		}
		cache.keys << key
		return cache.cache[key]
	}
	return none
}

pub fn (mut cache LRUCache) put(key string, value RouteMatch) {
	if key in cache.cache {
		// 更新现有项
		cache.cache[key] = value
		// 移动到列表末尾
		idx := cache.keys.index(key)
		if idx != -1 {
			cache.keys.delete(idx)
		}
		cache.keys << key
	} else {
		// 添加新项
		cache.cache[key] = value
		cache.keys << key
		
		// 如果超出容量，删除最久未使用的项
		if cache.cache.len > cache.capacity {
			oldest_key := cache.keys[0]
			cache.cache.delete(oldest_key)
			cache.keys.delete(0)
		}
	}
}

pub fn (mut cache LRUCache) clear() {
	cache.cache.clear()
	cache.keys.clear()
}

pub fn (cache LRUCache) size() int {
	return cache.cache.len
} 