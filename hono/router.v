module hono

import regex

// 路由节点类型
enum RouteType {
	static
	dynamic
	wildcard
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
mut:
	static_routes  map[string]IHandler
	dynamic_routes []IHandler
	cache          ContextLRUCache
}

// ContextHybridRouter 构造函数
pub fn ContextHybridRouter.new() ContextHybridRouter {
	return ContextHybridRouter{
		static_routes: map[string]IHandler{}
		dynamic_routes: []IHandler{}
		cache: ContextLRUCache.new(1000)
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

// Context 版本的正则匹配函数
fn (mut router ContextHybridRouter) match_path_with_regex(real_path string, reg_path string) (bool, regex.RE, []string) {
	// 处理多个星号 **
	if reg_path.contains('**') {
		// 将 ** 替换为 .*
		replaced_path := reg_path.replace('**', '.*')
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		return reg.matches_string(real_path), reg, []string{}
	}
	
	// 处理单个星号 *
	if reg_path.contains('*') {
		// 将 * 替换为 [^/]*
		replaced_path := reg_path.replace('*', '[^/]*')
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		return reg.matches_string(real_path), reg, []string{}
	}
	
	// 处理参数 :param
	if reg_path.contains(':') {
		mut replaced_path := reg_path
		mut param_names := []string{}
		
		// 转义特殊字符
		replaced_path = replaced_path.replace('?', r'\?')
		replaced_path = replaced_path.replace('+', r'\+')
		replaced_path = replaced_path.replace('.', r'\.')
		replaced_path = replaced_path.replace('(', r'\(')
		replaced_path = replaced_path.replace(')', r'\)')
		replaced_path = replaced_path.replace('[', r'\[')
		replaced_path = replaced_path.replace(']', r'\]')
		replaced_path = replaced_path.replace('{', r'\{')
		replaced_path = replaced_path.replace('}', r'\}')
		replaced_path = replaced_path.replace('^', r'\^')
		replaced_path = replaced_path.replace('$', r'\$')
		replaced_path = replaced_path.replace('|', r'\|')
		
		// 提取参数名并替换为命名捕获组
		mut pamam_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { return false, regex.RE{}, []string{} }
		replaced_path = pamam_reg.replace_by_fn(replaced_path, fn [mut param_names] (re regex.RE, in_txt string, start int, end int) string {
			param_name := in_txt[start+1..end]
			param_names << param_name
			return '(?P<' + param_name + '>[^/]+)'
		})
		
		// 添加结束锚点
		replaced_path = '^' + replaced_path + '$'
		
		// 编译正则表达式
		mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
		
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
	}
}

// Context 版本的静态路径匹配
fn (router ContextHybridRouter) match_static_route(method string, path string) ?IHandler {
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
		match_result, replaced_path_reg, _ := router.match_path_with_regex(path, handler.path)
		if match_result {
			mut param_map := map[string]string{}
			
			// 从原始路由路径中提取参数名
			mut pamam_reg := regex.regex_opt(r':\w+') or { panic(err) }
			all_params := pamam_reg.find_all_str(handler.path)
			for param in all_params {
				param_name := param[1..]
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

 