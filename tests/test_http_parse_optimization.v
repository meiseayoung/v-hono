module main

import time

// 测试 HTTP 解析优化

// 原始版本 - 使用 split 和 index
fn parse_path_and_query_original(full_path string) (string, map[string]string) {
	mut query_map := map[string]string{}
	
	if idx := full_path.index('?') {
		path := full_path[..idx]
		query_str := full_path[idx + 1..]
		
		for part in query_str.split('&') {
			if eq_idx := part.index('=') {
				query_map[part[..eq_idx]] = part[eq_idx + 1..]
			}
		}
		return path, query_map
	}
	
	return full_path, query_map
}

// 优化版本 - 零分配单次遍历
fn parse_path_and_query_optimized(full_path string) (string, map[string]string) {
	mut query_map := map[string]string{}
	len := full_path.len
	
	if len == 0 {
		return full_path, query_map
	}
	
	// 1. 查找 '?' 位置（单次遍历）
	mut query_start := -1
	for i in 0 .. len {
		if full_path[i] == `?` {
			query_start = i
			break
		}
	}
	
	// 没有查询参数，直接返回
	if query_start == -1 {
		return full_path, query_map
	}
	
	path := full_path[..query_start]
	
	// 2. 解析查询参数（单次遍历，避免 split）
	mut key_start := query_start + 1
	mut key_end := -1
	mut value_start := -1
	
	for i := query_start + 1; i <= len; i++ {
		ch := if i < len { full_path[i] } else { `&` } // 末尾视为分隔符
		
		if ch == `=` && key_end == -1 {
			key_end = i
			value_start = i + 1
		} else if ch == `&` {
			// 完成一个键值对
			if key_end > key_start && value_start > 0 {
				key := full_path[key_start..key_end]
				value := if value_start < i { full_path[value_start..i] } else { '' }
				query_map[key] = value
			} else if key_end == -1 && i > key_start {
				// 只有 key 没有 value（如 ?foo&bar=1）
				key := full_path[key_start..i]
				query_map[key] = ''
			}
			// 重置状态
			key_start = i + 1
			key_end = -1
			value_start = -1
		}
	}
	
	return path, query_map
}

// Keep-Alive 检查 - 原始版本
fn check_keepalive_original(name string, value string) bool {
	return name.to_lower() == 'connection' && value.to_lower().contains('keep-alive')
}

// 大小写不敏感比较
@[inline]
fn eq_ignore_case(a string, b string) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		ca := a[i]
		cb := b[i]
		la := if ca >= `A` && ca <= `Z` { ca + 32 } else { ca }
		lb := if cb >= `A` && cb <= `Z` { cb + 32 } else { cb }
		if la != lb {
			return false
		}
	}
	return true
}

// 大小写不敏感 contains
@[inline]
fn contains_ignore_case(haystack string, needle string) bool {
	if needle.len > haystack.len {
		return false
	}
	max_start := haystack.len - needle.len
	for i := 0; i <= max_start; i++ {
		mut found := true
		for j in 0 .. needle.len {
			ch := haystack[i + j]
			cn := needle[j]
			lh := if ch >= `A` && ch <= `Z` { ch + 32 } else { ch }
			ln := if cn >= `A` && cn <= `Z` { cn + 32 } else { cn }
			if lh != ln {
				found = false
				break
			}
		}
		if found {
			return true
		}
	}
	return false
}

// Keep-Alive 检查 - 优化版本
fn check_keepalive_optimized(name string, value string) bool {
	return name.len == 10 && eq_ignore_case(name, 'connection') && contains_ignore_case(value, 'keep-alive')
}

// 测试正确性
fn test_correctness() {
	println('=== 测试正确性 ===')
	
	test_cases := [
		'/api/users',
		'/api/users?id=123',
		'/api/users?id=123&name=test',
		'/api/users?id=123&name=test&active=true',
		'/search?q=hello+world&page=1&limit=10',
		'/path?empty=&key=value',
		'/path?novalue&key=value',
		'/',
		'/?single=param',
	]
	
	mut all_passed := true
	
	for tc in test_cases {
		path_orig, query_orig := parse_path_and_query_original(tc)
		path_opt, query_opt := parse_path_and_query_optimized(tc)
		
		if path_orig != path_opt {
			println('❌ 路径不匹配: ${tc}')
			println('   原始: ${path_orig}')
			println('   优化: ${path_opt}')
			all_passed = false
		} else if query_orig.len != query_opt.len {
			println('❌ 查询参数数量不匹配: ${tc}')
			println('   原始: ${query_orig}')
			println('   优化: ${query_opt}')
			all_passed = false
		} else {
			mut params_match := true
			for k, v in query_orig {
				if k !in query_opt || query_opt[k] != v {
					params_match = false
					break
				}
			}
			if !params_match {
				println('❌ 查询参数值不匹配: ${tc}')
				println('   原始: ${query_orig}')
				println('   优化: ${query_opt}')
				all_passed = false
			} else {
				println('✓ ${tc}')
			}
		}
	}
	
	if all_passed {
		println('\n✅ 所有正确性测试通过!')
	} else {
		println('\n❌ 部分测试失败')
	}
}

// 性能基准测试
fn benchmark_performance() {
	println('\n=== 性能基准测试 ===')
	
	// 测试用例
	test_paths := [
		'/api/users',                                    // 无查询参数
		'/api/users?id=123',                             // 单个参数
		'/api/users?id=123&name=test&active=true',       // 多个参数
		'/search?q=hello+world&page=1&limit=10&sort=desc&filter=active', // 复杂查询
	]
	
	iterations := 100000
	
	for test_path in test_paths {
		// 原始版本
		sw_orig := time.new_stopwatch()
		for _ in 0 .. iterations {
			_, _ := parse_path_and_query_original(test_path)
		}
		time_orig := sw_orig.elapsed().microseconds()
		
		// 优化版本
		sw_opt := time.new_stopwatch()
		for _ in 0 .. iterations {
			_, _ := parse_path_and_query_optimized(test_path)
		}
		time_opt := sw_opt.elapsed().microseconds()
		
		speedup := f64(time_orig) / f64(time_opt)
		
		println('\n路径: ${test_path}')
		println('  原始版本: ${time_orig} μs (${iterations} 次)')
		println('  优化版本: ${time_opt} μs (${iterations} 次)')
		println('  提升: ${speedup:.2f}x')
	}
}

// 测试 Keep-Alive 检查优化
fn test_keepalive_optimization() {
	println('\n=== Keep-Alive 检查优化测试 ===')
	
	test_cases := [
		['Connection', 'keep-alive'],
		['connection', 'Keep-Alive'],
		['CONNECTION', 'KEEP-ALIVE'],
		['Content-Type', 'application/json'],
		['Connection', 'close'],
	]
	
	iterations := 100000
	
	// 原始版本
	sw_orig := time.new_stopwatch()
	for _ in 0 .. iterations {
		for tc in test_cases {
			_ := check_keepalive_original(tc[0], tc[1])
		}
	}
	time_orig := sw_orig.elapsed().microseconds()
	
	// 优化版本
	sw_opt := time.new_stopwatch()
	for _ in 0 .. iterations {
		for tc in test_cases {
			_ := check_keepalive_optimized(tc[0], tc[1])
		}
	}
	time_opt := sw_opt.elapsed().microseconds()
	
	speedup := f64(time_orig) / f64(time_opt)
	
	println('原始版本: ${time_orig} μs (${iterations * test_cases.len} 次检查)')
	println('优化版本: ${time_opt} μs (${iterations * test_cases.len} 次检查)')
	println('提升: ${speedup:.2f}x')
}

fn main() {
	println('HTTP 解析优化测试')
	println('=' .repeat(50))
	
	test_correctness()
	benchmark_performance()
	test_keepalive_optimization()
	
	println('\n' + '=' .repeat(50))
	println('测试完成!')
}
