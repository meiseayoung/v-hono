import hono
import time

// 测试LRU缓存内存泄漏修复
fn main() {
	println('=== LRU缓存内存安全测试 ===\n')
	
	// 测试1：基本功能测试
	test_basic_functionality()
	
	// 测试2：TTL过期测试
	test_ttl_expiration()
	
	// 测试3：内存清理测试
	test_memory_cleanup()
	
	// 测试4：大容量测试
	test_large_capacity()
	
	// 测试5：健康检查测试
	test_health_check()
	
	println('所有测试完成！✅')
}

fn test_basic_functionality() {
	println('--- 测试1: 基本功能测试 ---')
	
	mut cache := hono.ContextLRUCache.new(3)
	
	// 创建测试数据
	test_route_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{
			path: '/test'
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	// 添加缓存项
	cache.put('key1', test_route_match)
	cache.put('key2', test_route_match)
	cache.put('key3', test_route_match)
	
	println('添加3个缓存项后:')
	size, capacity := cache.get_stats()
	println('  大小: $size/$capacity')
	
	// 获取缓存项
	if route_match := cache.get('key1') {
		println('  成功获取key1')
	} else {
		println('  ❌ 获取key1失败')
	}
	
	// 添加第4个项，应该移除最久未使用的
	cache.put('key4', test_route_match)
	size2, _ := cache.get_stats()
	println('添加第4个项后大小: $size2')
	
	// key2应该被移除了（最久未使用）
	if route_match := cache.get('key2') {
		println('  ❌ key2仍然存在（应该被移除）')
	} else {
		println('  ✅ key2正确被移除')
	}
	
	println('基本功能测试完成\n')
}

fn test_ttl_expiration() {
	println('--- 测试2: TTL过期测试 ---')
	
	// 创建TTL为2秒的缓存
	mut cache := hono.ContextLRUCache.new_with_ttl(10, 2)
	
	test_route_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{
			path: '/test'
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	// 添加缓存项
	cache.put('expire_test', test_route_match)
	println('添加缓存项 expire_test')
	
	// 立即获取应该成功
	if _ := cache.get('expire_test') {
		println('  ✅ 立即获取成功')
	} else {
		println('  ❌ 立即获取失败')
	}
	
	// 等待3秒后获取应该失败（过期）
	println('等待3秒让缓存过期...')
	time.sleep(3 * time.second)
	
	if _ := cache.get('expire_test') {
		println('  ❌ 过期后仍能获取（应该已过期）')
	} else {
		println('  ✅ 过期后正确无法获取')
	}
	
	// 检查缓存大小
	size, _ := cache.get_stats()
	println('过期清理后缓存大小: $size')
	
	println('TTL过期测试完成\n')
}

fn test_memory_cleanup() {
	println('--- 测试3: 内存清理测试 ---')
	
	mut cache := hono.ContextLRUCache.new(100)
	
	test_route_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{
			path: '/test'
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	// 添加大量缓存项
	for i in 0 .. 50 {
		cache.put('key_$i', test_route_match)
	}
	
	size1, _ := cache.get_stats()
	println('添加50个缓存项后大小: $size1')
	
	// 获取详细统计
	stats := cache.get_detailed_stats()
	println('详细统计:')
	println('  大小: ${stats['size']}')
	println('  容量: ${stats['capacity']}')
	println('  过期数量: ${stats['expired_count']}')
	println('  内存估算: ${stats['memory_usage_estimate']} bytes')
	
	// 健康检查
	is_healthy := cache.is_healthy()
	println('缓存健康状态: $is_healthy')
	
	// 清理所有缓存
	cache.clear()
	size2, _ := cache.get_stats()
	println('清理后缓存大小: $size2')
	
	// 再次健康检查
	is_healthy2 := cache.is_healthy()
	println('清理后健康状态: $is_healthy2')
	
	println('内存清理测试完成\n')
}

fn test_large_capacity() {
	println('--- 测试4: 大容量测试 ---')
	
	mut cache := hono.ContextLRUCache.new(1000)
	
	test_route_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{
			path: '/test'
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	// 添加大量缓存项
	start_time := time.now()
	for i in 0 .. 1000 {
		cache.put('large_key_$i', test_route_match)
	}
	add_duration := time.now() - start_time
	
	size, _ := cache.get_stats()
	println('添加1000个缓存项耗时: $add_duration')
	println('最终缓存大小: $size')
	
	// 随机访问测试
	start_time2 := time.now()
	for i in 0 .. 1000 {
		_ := cache.get('large_key_${i % 1000}')
	}
	get_duration := time.now() - start_time2
	println('1000次随机获取耗时: $get_duration')
	
	// 清理测试
	start_time3 := time.now()
	cache.clear()
	clear_duration := time.now() - start_time3
	println('清理耗时: $clear_duration')
	
	println('大容量测试完成\n')
}

fn test_health_check() {
	println('--- 测试5: 健康检查测试 ---')
	
	mut cache := hono.ContextLRUCache.new(5)
	
	// 空缓存健康检查
	println('空缓存健康状态: ${cache.is_healthy()}')
	
	test_route_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{
			path: '/test'
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	// 添加一些项
	for i in 0 .. 3 {
		cache.put('health_key_$i', test_route_match)
	}
	
	println('添加3项后健康状态: ${cache.is_healthy()}')
	
	// 强制清理过期项
	cache.force_cleanup_expired()
	println('强制清理后健康状态: ${cache.is_healthy()}')
	
	// 测试TTL设置
	cache.set_ttl(30)
	cache.set_cleanup_interval(10)
	
	final_stats := cache.get_detailed_stats()
	println('最终统计:')
	println('  TTL: ${final_stats['ttl_seconds']}秒')
	println('  清理间隔: ${final_stats['cleanup_interval']}秒')
	
	println('健康检查测试完成\n')
}
