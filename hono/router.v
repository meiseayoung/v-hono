module hono

import regex

// 路由节点类型
enum RouteType {
	static
	dynamic
	wildcard
}

// 编译后的正则表达式缓存
pub struct CompiledRegex {
pub mut:
	regex       regex.RE
	param_names []string
	compiled    bool
}

// Context 路由节点
struct ContextRouteNode {
mut:
	path      string
	handler   IHandler
	route_type RouteType
	children  map[string]&ContextRouteNode
	param_name string
	base_path string
}

// Context 路由匹配结果
pub struct ContextRouteMatch {
pub:
	handler IHandler
	params  map[string]string
	path    string
	base_path string
}

// Context 混合路由器
pub struct ContextHybridRouter {
pub mut:
	static_routes  map[string]IHandler
	dynamic_routes []IHandler
	cache          ContextLRUCache
	regex_cache    map[string]CompiledRegex  // 新增：正则表达式缓存
}

// ContextHybridRouter 构造函数
pub fn ContextHybridRouter.new() ContextHybridRouter {
	return ContextHybridRouter{
		static_routes: map[string]IHandler{}
		dynamic_routes: []IHandler{}
		cache: ContextLRUCache.new(1000)
		regex_cache: map[string]CompiledRegex{}
	}
}

// 判断路径是否为静态路径
fn is_static_path(path string) bool {
	return !path.contains(':') && !path.contains('*') && !path.contains('?') && !path.contains('+')
}

// 判断路径是否为动态路径
fn is_dynamic_path(path string) bool {
	return path.contains(':') || path.contains('*') || path.contains('?') || path.contains('+')
}

// Context 版本的正则匹配函数（优化版，使用缓存）
pub fn (mut router ContextHybridRouter) match_path_with_regex(real_path string, reg_path string) (bool, regex.RE, []string) {
	// 先检查缓存
	if cached := router.regex_cache[reg_path] {
		if cached.compiled {
			return cached.regex.matches_string(real_path), cached.regex, cached.param_names
		}
	}
	
	// 如果缓存中没有，编译并缓存
	mut compiled_regex := CompiledRegex{}
	mut replaced_path := reg_path
	mut param_names := []string{}
	
	// 处理多个星号 **
	if reg_path.contains('**') {
		// 将 ** 替换为 .*
		replaced_path = reg_path.replace('**', '.*')
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		compiled_regex = CompiledRegex{
			regex: reg
			param_names: []string{}
			compiled: true
		}
		router.regex_cache[reg_path] = compiled_regex
		return reg.matches_string(real_path), reg, []string{}
	}
	
	// 处理单个星号 *
	if reg_path.contains('*') {
		// 将 * 替换为 [^/]*
		replaced_path = reg_path.replace('*', '[^/]*')
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		compiled_regex = CompiledRegex{
			regex: reg
			param_names: []string{}
			compiled: true
		}
		router.regex_cache[reg_path] = compiled_regex
		return reg.matches_string(real_path), reg, []string{}
	}
	
	// 处理参数 :param
	if reg_path.contains(':') {
		// 预先提取参数名（避免在匹配时重复提取）
		mut param_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { return false, regex.RE{}, []string{} }
		all_params := param_reg.find_all_str(reg_path)
		for param in all_params {
			param_names << param[1..]  // 去掉冒号
		}
		
		// 批量转义特殊字符（减少多次replace调用）
		special_chars := ['?', '+', '.', '(', ')', '[', ']', '{', '}', '^', '$', '|']
		for ch in special_chars {
			replaced_path = replaced_path.replace(ch, '\\${ch}')
		}
		
		// 替换参数为命名捕获组
		replaced_path = param_reg.replace_by_fn(replaced_path, fn (re regex.RE, in_txt string, start int, end int) string {
			param_name := in_txt[start+1..end]
			return '(?P<${param_name}>[^/]+)'
		})
		
		// 添加锚点
		replaced_path = '^${replaced_path}$'
		
		// 编译正则表达式
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		
		// 缓存编译结果
		compiled_regex = CompiledRegex{
			regex: reg
			param_names: param_names
			compiled: true
		}
		router.regex_cache[reg_path] = compiled_regex
		
		return reg.matches_string(real_path), reg, param_names
	}
	
	return false, regex.RE{}, []string{}
}

// 添加 Context 路由
pub fn (mut router ContextHybridRouter) add_route(method string, handler IHandler, base_path string) {
	full_path := handler.path
	if is_static_path(full_path) {
		router.static_routes['${method}:${full_path}'] = handler
	} else {
		router.dynamic_routes << handler
		// 按路由复杂度排序，简单路由优先匹配
		router.sort_dynamic_routes()
	}
}

// 按路由复杂度排序动态路由（简单路由优先）
fn (mut router ContextHybridRouter) sort_dynamic_routes() {
	router.dynamic_routes.sort_with_compare(fn (a &IHandler, b &IHandler) int {
		// 计算路由复杂度分数（分数越低越简单，优先匹配）
		score_a := calculate_route_complexity(a.path)
		score_b := calculate_route_complexity(b.path)
		
		if score_a < score_b {
			return -1
		} else if score_a > score_b {
			return 1
		}
		return 0
	})
}

// 计算路由复杂度分数
fn calculate_route_complexity(path string) int {
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

// Context 版本的静态路径匹配
pub fn (router ContextHybridRouter) match_static_route(method string, path string) ?IHandler {
	key := '${method}:${path}'
	if key in router.static_routes {
		return router.static_routes[key]
	}
	return none
}

// Context 版本的动态路径匹配
fn (mut router ContextHybridRouter) match_dynamic_route(method string, path string) ?ContextRouteMatch {
	// 先检查缓存
	cache_key := '${method}:${path}'
	if cached := router.cache.get(cache_key) {
		return cached
	}
	
	for handler in router.dynamic_routes {
		match_result, replaced_path_reg, param_names := router.match_path_with_regex(path, handler.path)
		if match_result {
			mut param_map := map[string]string{}
			
			// 直接使用已编译的正则表达式和缓存的参数名
			for param_name in param_names {
				group := replaced_path_reg.get_group_by_name(path, param_name)
				param_map[param_name] = group
			}
			
			route_match := ContextRouteMatch{
				handler: handler
				params: param_map
				path: handler.path
				base_path: ''
			}
			router.cache.put(cache_key, route_match)
			return route_match
		}
	}
	return none
}

// Context 版本的主匹配函数
pub fn (mut router ContextHybridRouter) match_route(method string, path string) ?ContextRouteMatch {
	// 1. 先尝试静态路径匹配（最快）
	if static_handler := router.match_static_route(method, path) {
		return ContextRouteMatch{
			handler: static_handler
			params: map[string]string{}
			path: path
			base_path: ''
		}
	}
	
	// 2. 再尝试动态路径匹配
	return router.match_dynamic_route(method, path)
}

// Context 版本的获取所有路由
pub fn (router ContextHybridRouter) get_all_routes() ([]string, []string) {
	mut static_paths := []string{}
	mut dynamic_paths := []string{}
	
	for key in router.static_routes.keys() {
		static_paths << key
	}
	
	for handler in router.dynamic_routes {
		dynamic_paths << handler.path
	}
	
	return static_paths, dynamic_paths
}

// 获取缓存统计信息
pub fn (router ContextHybridRouter) get_cache_stats() (int, int) {
	return router.cache.get_stats()
}

// 清理缓存
pub fn (mut router ContextHybridRouter) clear_cache() {
	router.cache.clear()
}

// 获取正则表达式缓存统计信息
pub fn (router ContextHybridRouter) get_regex_cache_stats() (int, int) {
	mut compiled_count := 0
	for _, cached_regex in router.regex_cache {
		if cached_regex.compiled {
			compiled_count++
		}
	}
	return router.regex_cache.len, compiled_count
}

// 清理正则表达式缓存
pub fn (mut router ContextHybridRouter) clear_regex_cache() {
	router.regex_cache.clear()
}

// 预热正则表达式缓存
pub fn (mut router ContextHybridRouter) warmup_regex_cache() {
	println('[INFO] Warming up regex cache...')
	mut warmed_count := 0
	
	for handler in router.dynamic_routes {
		if handler.path.contains(':') || handler.path.contains('*') {
			// 预编译动态路由的正则表达式
			router.match_path_with_regex('/dummy/path', handler.path)
			warmed_count++
		}
	}
	
	total_cached, compiled_cached := router.get_regex_cache_stats()
	println('[INFO] Regex cache warmup completed: ${warmed_count} patterns warmed, ${compiled_cached}/${total_cached} compiled')
}

// 路由性能分析
pub fn (router ContextHybridRouter) analyze_router_performance() {
	cache_size, cache_hits := router.get_cache_stats()
	regex_total, regex_compiled := router.get_regex_cache_stats()
	
	println('[PERFORMANCE] Router Analysis:')
	println('  Static Routes: ${router.static_routes.len}')
	println('  Dynamic Routes: ${router.dynamic_routes.len}')
	println('  Route Cache: ${cache_hits}/${cache_size} hits')
	println('  Regex Cache: ${regex_compiled}/${regex_total} compiled')
}

 