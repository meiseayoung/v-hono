module hono

import regex

// 预编译路由条目
pub struct PrecompiledRoute {
pub:
	method      string
	pattern     string
	regex       regex.RE
	param_names []string
	handler     IHandler
	complexity  int  // 路由复杂度分数
}

// 编译后的正则表达式缓存
pub struct FastCompiledRegex {
pub mut:
	regex       regex.RE
	param_names []string
	compiled    bool
}

// 快速路由器（增强版本）
pub struct FastRouter {
pub mut:
	static_routes      map[string]IHandler
	precompiled_routes []PrecompiledRoute
	lru_cache         ContextLRUCache      // 使用 LRU 缓存替代简单 map
	regex_cache       map[string]FastCompiledRegex  // 正则表达式缓存
	cache_enabled     bool = true
	sort_enabled      bool = true          // 是否启用路由排序
}

// 创建快速路由器
pub fn FastRouter.new() FastRouter {
	return FastRouter{
		static_routes: map[string]IHandler{}
		precompiled_routes: []PrecompiledRoute{}
		lru_cache: ContextLRUCache.new(1000)  // 默认1000条缓存
		regex_cache: map[string]FastCompiledRegex{}
	}
}

// 创建带自定义缓存大小的快速路由器
pub fn FastRouter.new_with_cache_size(cache_size int) FastRouter {
	return FastRouter{
		static_routes: map[string]IHandler{}
		precompiled_routes: []PrecompiledRoute{}
		lru_cache: ContextLRUCache.new(cache_size)
		regex_cache: map[string]FastCompiledRegex{}
	}
}

// 添加路由（预编译）
pub fn (mut router FastRouter) add_route(method string, handler IHandler, base_path string) ! {
	full_path := handler.path
	
	// 静态路由直接存储
	if !full_path.contains(':') && !full_path.contains('*') {
		router.static_routes['${method}:${full_path}'] = handler
		return
	}
	
	// 动态路由预编译
	compiled_route := router.precompile_route(method, handler) or {
		return error('Failed to precompile route ${full_path}: ${err}')
	}
	
	router.precompiled_routes << compiled_route
	
	// 如果启用排序，按复杂度排序
	if router.sort_enabled {
		router.sort_dynamic_routes()
	}
}

// 按路由复杂度排序动态路由（简单路由优先）
fn (mut router FastRouter) sort_dynamic_routes() {
	router.precompiled_routes.sort_with_compare(fn (a &PrecompiledRoute, b &PrecompiledRoute) int {
		if a.complexity < b.complexity {
			return -1
		} else if a.complexity > b.complexity {
			return 1
		}
		return 0
	})
}

// 计算路由复杂度分数（FastRouter 版本）
fn calculate_fast_route_complexity(path string) int {
	mut score := 0
	
	// 参数数量（每个参数+10分）
	score += path.count(':') * 10
	
	// 通配符（每个通配符+20分）
	score += path.count('*') * 20
	
	// 路径段数量（每个段+1分）
	score += path.split('/').len
	
	// 特殊字符（每个+5分）
	special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '$', '|']
	for ch in special_chars {
		score += path.count(ch) * 5
	}
	
	return score
}

// 预编译路由
fn (router FastRouter) precompile_route(method string, handler IHandler) !PrecompiledRoute {
	route_path := handler.path
	
	// 计算路由复杂度
	complexity := calculate_fast_route_complexity(route_path)
	
	// 提取参数名
	mut param_names := []string{}
	mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or {
		return error('Failed to create param regex')
	}
	
	all_params := param_reg.find_all_str(route_path)
	for param in all_params {
		param_names << param[1..]  // 去掉冒号
	}
	
	// 构建正则表达式
	mut regex_pattern := route_path
	
	// 转义特殊字符
	special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '$', '|']
	for ch in special_chars {
		regex_pattern = regex_pattern.replace(ch, '\\${ch}')
	}
	
	// 替换参数为命名捕获组
	regex_pattern = param_reg.replace_by_fn(regex_pattern, fn (re regex.RE, in_txt string, start int, end int) string {
		param_name := in_txt[start+1..end]
		return '(?P<${param_name}>[^/]+)'
	})
	
	// 添加锚点
	regex_pattern = '^${regex_pattern}$'
	
	// 编译正则表达式
	compiled_regex := regex.regex_opt(regex_pattern) or {
		return error('Failed to compile regex: ${regex_pattern}')
	}
	
	return PrecompiledRoute{
		method: method
		pattern: route_path
		regex: compiled_regex
		param_names: param_names
		handler: handler
		complexity: complexity
	}
}

// 快速路由匹配
pub fn (mut router FastRouter) match_route(method string, path string) ?ContextRouteMatch {
	// 1. 检查 LRU 缓存
	if router.cache_enabled {
		cache_key := '${method}:${path}'
		if cached := router.lru_cache.get(cache_key) {
			return cached
		}
	}
	
	// 2. 静态路由匹配
	static_key := '${method}:${path}'
	if static_handler := router.static_routes[static_key] {
		result := ContextRouteMatch{
			handler: static_handler
			params: map[string]string{}
			path: path
			base_path: ''
		}
		
		if router.cache_enabled {
			router.lru_cache.put(static_key, result)
		}
		
		return result
	}
	
	// 3. 预编译动态路由匹配（已按复杂度排序）
	for route in router.precompiled_routes {
		if route.method != method {
			continue
		}
		
		if route.regex.matches_string(path) {
			// 提取参数
			mut params := map[string]string{}
			for param_name in route.param_names {
				group := route.regex.get_group_by_name(path, param_name)
				params[param_name] = group
			}
			
			result := ContextRouteMatch{
				handler: route.handler
				params: params
				path: route.pattern
				base_path: ''
			}
			
			// 缓存结果
			if router.cache_enabled {
				cache_key := '${method}:${path}'
				router.lru_cache.put(cache_key, result)
			}
			
			return result
		}
	}
	
	return none
}

// 获取路由统计
pub fn (router FastRouter) get_stats() (int, int, int) {
	cache_size, _ := router.lru_cache.get_stats()
	return router.static_routes.len, router.precompiled_routes.len, cache_size
}

// 获取详细统计信息
pub fn (mut router FastRouter) get_detailed_stats() map[string]i64 {
	cache_stats := router.lru_cache.get_detailed_stats()
	
	mut regex_compiled := 0
	for _, cached_regex in router.regex_cache {
		if cached_regex.compiled {
			regex_compiled++
		}
	}
	
	mut stats := map[string]i64{}
	stats['static_routes'] = i64(router.static_routes.len)
	stats['dynamic_routes'] = i64(router.precompiled_routes.len)
	stats['regex_cache_total'] = i64(router.regex_cache.len)
	stats['regex_cache_compiled'] = i64(regex_compiled)
	stats['cache_enabled'] = if router.cache_enabled { 1 } else { 0 }
	stats['sort_enabled'] = if router.sort_enabled { 1 } else { 0 }
	
	// 合并 LRU 缓存统计
	for key, value in cache_stats {
		stats['lru_${key}'] = value
	}
	
	return stats
}

// 获取缓存统计信息
pub fn (router FastRouter) get_cache_stats() (int, int) {
	return router.lru_cache.get_stats()
}

// 获取正则表达式缓存统计信息
pub fn (router FastRouter) get_regex_cache_stats() (int, int) {
	mut compiled_count := 0
	for _, cached_regex in router.regex_cache {
		if cached_regex.compiled {
			compiled_count++
		}
	}
	return router.regex_cache.len, compiled_count
}

// 清理缓存
pub fn (mut router FastRouter) clear_cache() {
	router.lru_cache.clear()
}

// 清理正则表达式缓存
pub fn (mut router FastRouter) clear_regex_cache() {
	router.regex_cache.clear()
}

// 强制清理过期缓存
pub fn (mut router FastRouter) force_cleanup_expired() {
	router.lru_cache.force_cleanup_expired()
}

// 启用/禁用缓存
pub fn (mut router FastRouter) set_cache_enabled(enabled bool) {
	router.cache_enabled = enabled
	if !enabled {
		router.clear_cache()
	}
}

// 启用/禁用路由排序
pub fn (mut router FastRouter) set_sort_enabled(enabled bool) {
	router.sort_enabled = enabled
	if enabled {
		router.sort_dynamic_routes()
	}
}

// 设置缓存 TTL
pub fn (mut router FastRouter) set_cache_ttl(ttl_seconds i64) {
	router.lru_cache.set_ttl(ttl_seconds)
}

// 设置缓存清理间隔
pub fn (mut router FastRouter) set_cache_cleanup_interval(interval_seconds i64) {
	router.lru_cache.set_cleanup_interval(interval_seconds)
}

// 检查路由器健康状态
pub fn (mut router FastRouter) is_healthy() bool {
	return router.lru_cache.is_healthy()
}

// 预热缓存
pub fn (mut router FastRouter) warmup_cache(common_paths []string, method string) {
	if !router.cache_enabled {
		return
	}
	
	for path in common_paths {
		router.match_route(method, path)
	}
}

// 预热正则表达式缓存
pub fn (mut router FastRouter) warmup_regex_cache() {
	println('[INFO] Warming up FastRouter regex cache...')
	warmed_count := router.precompiled_routes.len
	
	// 预编译的路由已经有编译好的正则表达式
	// 这里可以进行一些预热操作
	
	println('[INFO] FastRouter regex cache warmup completed: ${warmed_count} patterns ready')
}

// 智能预热（基于路由复杂度）
pub fn (mut router FastRouter) smart_warmup(sample_paths []string) {
	if !router.cache_enabled {
		return
	}
	
	println('[INFO] Starting smart warmup for FastRouter...')
	
	// 按复杂度分组预热
	mut simple_routes := []string{}
	mut complex_routes := []string{}
	
	for route in router.precompiled_routes {
		if route.complexity <= 20 {
			simple_routes << route.pattern
		} else {
			complex_routes << route.pattern
		}
	}
	
	// 先预热简单路由
	for path in sample_paths {
		router.match_route('GET', path)
	}
	
	println('[INFO] Smart warmup completed: ${simple_routes.len} simple, ${complex_routes.len} complex routes')
}

// 获取所有路由
pub fn (router FastRouter) get_all_routes() ([]string, []string) {
	mut static_paths := []string{}
	mut dynamic_paths := []string{}
	
	for key in router.static_routes.keys() {
		static_paths << key
	}
	
	for route in router.precompiled_routes {
		dynamic_paths << '${route.method}:${route.pattern} (complexity: ${route.complexity})'
	}
	
	return static_paths, dynamic_paths
}

// 获取路由按复杂度分组
pub fn (router FastRouter) get_routes_by_complexity() ([]PrecompiledRoute, []PrecompiledRoute) {
	mut simple_routes := []PrecompiledRoute{}
	mut complex_routes := []PrecompiledRoute{}
	
	for route in router.precompiled_routes {
		if route.complexity <= 30 {
			simple_routes << route
		} else {
			complex_routes << route
		}
	}
	
	return simple_routes, complex_routes
}

// 性能分析
pub fn (mut router FastRouter) analyze_performance() {
	static_count, dynamic_count, cache_count := router.get_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	
	println('[ENHANCED FAST ROUTER] Performance Analysis:')
	println('  Static Routes: ${static_count}')
	println('  Precompiled Dynamic Routes: ${dynamic_count}')
	println('  LRU Cache Size: ${cache_count}')
	println('  Regex Cache: ${regex_compiled}/${regex_total} compiled')
	println('  Cache Enabled: ${router.cache_enabled}')
	println('  Sort Enabled: ${router.sort_enabled}')
	
	// 显示路由复杂度分布
	simple_routes, complex_routes := router.get_routes_by_complexity()
	println('  Route Complexity Distribution:')
	println('    Simple Routes (≤30): ${simple_routes.len}')
	println('    Complex Routes (>30): ${complex_routes.len}')
	
	// 显示缓存健康状态
	if router.is_healthy() {
		println('  Cache Health: ✅ Healthy')
	} else {
		println('  Cache Health: ⚠️  Issues detected')
	}
	
	// 显示详细统计
	detailed_stats := router.get_detailed_stats()
	println('  Detailed Stats:')
	for key, value in detailed_stats {
		println('    ${key}: ${value}')
	}
}