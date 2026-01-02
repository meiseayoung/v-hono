// 测试缓存命中率
module main

import hono
import net.http
import time

fn main() {
	println('=== 缓存命中率测试 ===')
	
	mut app := hono.Hono.new()
	
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id'] or { 'unknown' }
		return c.json('{"user_id": "${user_id}"}')
	})
	
	// 获取 FastRouter 引用
	mut router := app.fast_router
	
	// 预热：先匹配一次让缓存生效
	println('\n1. 预热阶段')
	_ := router.match_route('GET', '/users/123')
	
	// 获取初始统计
	cache_size, cache_capacity := router.get_cache_stats()
	println('   缓存大小: ${cache_size}/${cache_capacity}')
	
	// 测试相同路径的匹配
	println('\n2. 测试相同路径 /users/123 匹配 1000 次')
	sw := time.new_stopwatch()
	
	for _ in 0 .. 1000 {
		_ := router.match_route('GET', '/users/123')
	}
	
	elapsed := sw.elapsed()
	println('   耗时: ${elapsed.microseconds()}μs')
	println('   平均: ${elapsed.microseconds() / 1000}μs/次')
	
	// 获取缓存统计
	cache_size2, _ := router.get_cache_stats()
	println('   缓存大小: ${cache_size2}')
	
	// 测试不同路径
	println('\n3. 测试不同路径 /users/1 到 /users/1000')
	sw2 := time.new_stopwatch()
	
	for i in 1 .. 1001 {
		_ := router.match_route('GET', '/users/${i}')
	}
	
	elapsed2 := sw2.elapsed()
	println('   耗时: ${elapsed2.microseconds()}μs')
	println('   平均: ${elapsed2.microseconds() / 1000}μs/次')
	
	// 获取最终缓存统计
	cache_size3, _ := router.get_cache_stats()
	println('   缓存大小: ${cache_size3}')
	
	// 再次测试相同路径（应该命中缓存）
	println('\n4. 再次测试 /users/500（应该命中缓存）')
	sw3 := time.new_stopwatch()
	
	for _ in 0 .. 1000 {
		_ := router.match_route('GET', '/users/500')
	}
	
	elapsed3 := sw3.elapsed()
	println('   耗时: ${elapsed3.microseconds()}μs')
	println('   平均: ${elapsed3.microseconds() / 1000}μs/次')
	
	// 详细统计
	println('\n5. 详细统计')
	stats := router.get_detailed_stats()
	for key, value in stats {
		println('   ${key}: ${value}')
	}
	
	println('\n=== 测试完成 ===')
}
