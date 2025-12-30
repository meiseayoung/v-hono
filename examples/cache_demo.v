import hono
import time

fn main() {
	println('=== 简化LRU缓存测试 ===')
	
	// 创建简单的路由匹配对象
	test_handler := hono.ContextHandler{
		path: '/test'
		handler: unsafe { nil } // 简化，不设置真实handler
	}
	
	test_route_match := hono.ContextRouteMatch{
		handler: test_handler
		params: map[string]string{}
		path: '/test'
		base_path: ''
	}
	
	// 测试基本功能
	println('测试1: 创建缓存并添加项目')
	mut cache := hono.ContextLRUCache.new(3)
	cache.put('key1', test_route_match)
	cache.put('key2', test_route_match)
	
	size, capacity := cache.get_stats()
	println('添加2项后: $size/$capacity')
	
	// 测试详细统计
	println('\n测试2: 获取详细统计信息')
	stats := cache.get_detailed_stats()
	println('大小: ${stats['size']}')
	println('容量: ${stats['capacity']}')
	println('TTL: ${stats['ttl_seconds']}秒')
	
	// 测试健康检查
	println('\n测试3: 健康检查')
	is_healthy := cache.is_healthy()
	println('缓存健康状态: $is_healthy')
	
	// 测试TTL设置
	println('\n测试4: TTL设置')
	cache.set_ttl(10)
	cache.set_cleanup_interval(5)
	
	// 测试强制清理
	println('\n测试5: 强制清理过期项')
	cache.force_cleanup_expired()
	
	size2, _ := cache.get_stats()
	println('强制清理后大小: $size2')
	
	// 测试完全清理
	println('\n测试6: 完全清理')
	cache.clear()
	
	size3, _ := cache.get_stats()
	is_healthy2 := cache.is_healthy()
	println('完全清理后大小: $size3')
	println('清理后健康状态: $is_healthy2')
	
	// 测试TTL缓存
	println('\n测试7: TTL功能')
	mut ttl_cache := hono.ContextLRUCache.new_with_ttl(5, 2) // 2秒TTL
	ttl_cache.put('expire_key', test_route_match)
	println('添加会过期的项目')
	
	// 立即检查
	if _ := ttl_cache.get('expire_key') {
		println('立即获取: ✅ 成功')
	} else {
		println('立即获取: ❌ 失败')
	}
	
	// 等待过期
	println('等待3秒让项目过期...')
	time.sleep(3 * time.second)
	
	if _ := ttl_cache.get('expire_key') {
		println('过期后获取: ❌ 仍然存在')
	} else {
		println('过期后获取: ✅ 正确过期')
	}
	
	println('\n所有测试完成! 🎉')
}
