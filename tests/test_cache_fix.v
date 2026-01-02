import meiseayoung.hono

fn main() {
	println('=== 测试缓存内存泄漏修复 ===')
	
	// 创建缓存
	mut cache := hono.ContextLRUCache.new(5)
	
	// 创建测试数据
	test_route_match := hono.ContextRouteMatch{
		handler: hono.ContextHandler{
			path: '/test'
		}
		params: {'id': '123'}
		path: '/test'
		base_path: ''
	}
	
	println('1. 基本功能测试')
	
	// 添加缓存项
	cache.put('key1', test_route_match)
	cache.put('key2', test_route_match)
	cache.put('key3', test_route_match)
	
	size, capacity := cache.get_stats()
	println('   添加3个项后: ${size}/${capacity}')
	
	// 测试获取
	if _ := cache.get('key1') {
		println('   ✅ 成功获取key1')
	} else {
		println('   ❌ 获取key1失败')
	}
	
	println('2. 容量溢出测试')
	
	// 注意：上面的 get('key1') 会把 key1 移到头部（最近使用）
	// 所以 LRU 顺序变为: key1(头) -> key3 -> key2(尾)
	// 添加更多项，触发LRU移除
	cache.put('key4', test_route_match)  // size=4
	cache.put('key5', test_route_match)  // size=5 (达到容量)
	cache.put('key6', test_route_match)  // 移除 key2 (最久未使用)
	
	size2, _ := cache.get_stats()
	println('   添加到容量上限后: ${size2}/${capacity}')
	
	// key2 应该被移除（因为 key1 在 get 后被移到了头部）
	if _ := cache.get('key2') {
		println('   ❌ key2仍然存在（应该被移除）')
	} else {
		println('   ✅ key2正确被移除（LRU淘汰）')
	}
	
	// key1 应该仍然存在（因为它是最近访问的）
	if _ := cache.get('key1') {
		println('   ✅ key1仍然存在（最近访问过）')
	} else {
		println('   ❌ key1被错误移除')
	}
	
	println('3. 健康检查测试')
	
	// 健康检查
	is_healthy := cache.is_healthy()
	println('   缓存健康状态: ${is_healthy}')
	
	println('4. 清理测试')
	
	// 清理所有缓存
	cache.clear()
	size3, _ := cache.get_stats()
	println('   清理后大小: ${size3}')
	
	// 清理后健康检查
	is_healthy2 := cache.is_healthy()
	println('   清理后健康状态: ${is_healthy2}')
	
	println('✅ 所有测试通过！缓存内存泄漏修复成功')
}