module hono

import regex
import time

// 路由节点类型
enum RouteType {
	static
	dynamic
	wildcard
}

// 路由节点
struct RouteNode {
mut:
	path      string
	handler   IRequestHandler
	route_type RouteType
	children  map[string]&RouteNode
	param_name string
	base_path string
}

// 路由匹配结果
pub struct RouteMatch {
pub:
	handler IRequestHandler
	params  map[string]string
	path    string
	base_path string
}

// 混合路由器
pub struct HybridRouter {
mut:
	static_routes  map[string]IRequestHandler
	dynamic_routes []IRequestHandler
	cache          LRUCache
}

pub fn new_hybrid_router() HybridRouter {
	return HybridRouter{
		static_routes: map[string]IRequestHandler{}
		dynamic_routes: []IRequestHandler{}
		cache: new_lru_cache(1000) // 缓存1000个路由匹配结果
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

// 优化的正则匹配函数
fn (mut router HybridRouter) match_path_with_regex(real_path string, reg_path string) (bool, regex.RE, []string) {
	start := time.now()
	
	// 处理多个星号 **
	mut one_more_star_reg := regex.regex_opt(r'\*{2,}') or { return false, regex.RE{}, []string{} }
	repl_on_e_more_star_fn := fn (re regex.RE, in_txt string, start int, end int) string {
		return r'[^#\?]*' // 匹配任意字符（包括斜杠）
	}
	
	// 转义特殊字符
	mut replaced_reg_path := reg_path.replace('?', r'\?')
	replaced_reg_path = replaced_reg_path.replace('+', r'\+')
	replaced_reg_path = replaced_reg_path.replace('.', r'\.')
	replaced_reg_path = replaced_reg_path.replace('(', r'\(')
	replaced_reg_path = replaced_reg_path.replace(')', r'\)')
	replaced_reg_path = replaced_reg_path.replace('[', r'\[')
	replaced_reg_path = replaced_reg_path.replace(']', r'\]')
	replaced_reg_path = replaced_reg_path.replace('{', r'\{')
	replaced_reg_path = replaced_reg_path.replace('}', r'\}')
	replaced_reg_path = replaced_reg_path.replace('^', r'\^')
	replaced_reg_path = replaced_reg_path.replace('$', r'\$')
	replaced_reg_path = replaced_reg_path.replace('|', r'\|')
	
	// 处理多个星号
	mut replaced_path := one_more_star_reg.replace_by_fn(replaced_reg_path, repl_on_e_more_star_fn)
	replaced_path = replaced_path.replace('*', r'[^/#\?]+') // 单个星号匹配单个路径段
	
	// 提取参数名并替换为命名捕获组
	mut param_names := []string{}
	mut pamam_reg := regex.regex_opt(r':[a-zA-Z_][a-zA-Z0-9_]*') or { return false, regex.RE{}, []string{} }
	replaced_path = pamam_reg.replace_by_fn(replaced_path, fn [mut param_names] (re regex.RE, in_txt string, start int, end int) string {
		param_name := in_txt[start+1..end]
		param_names << param_name
		return '(?P<' + param_name + '>[^/]+)'
	})
	
	// 添加结束锚点
	replaced_path = replaced_path + '$'
	
	println('原始路径: ${reg_path}')
	println('编译后正则: ${replaced_path}')
	println('参数名: ${param_names}')
	
	// 编译正则表达式
	mut reg := regex.regex_opt(replaced_path) or { return false, regex.RE{}, []string{} }
	
	end := time.now()
	println('Regex time: ${end - start}')
	
	return reg.matches_string(real_path), reg, param_names
}

// 添加路由
pub fn (mut router HybridRouter) add_route(method string, handler IRequestHandler, base_path string) {
	full_path := handler.path
	println('添加路由: ${method} ${full_path}')
	println('是否为静态路径: ${is_static_path(full_path)}')
	if is_static_path(full_path) {
		router.static_routes['${method}:${full_path}'] = handler
		println('添加到静态路由')
	} else {
		router.dynamic_routes << handler
		println('添加到动态路由')
	}
}

// 快速静态路径匹配
fn (router HybridRouter) match_static_route(method string, path string) ?IRequestHandler {
	key := '${method}:${path}'
	if key in router.static_routes {
		return router.static_routes[key]
	}
	return none
}

// 优化的动态路径匹配
fn (mut router HybridRouter) match_dynamic_route(method string, path string) ?RouteMatch {
	// 先检查缓存
	cache_key := '${method}:${path}'
	if cached := router.cache.get(cache_key) {
		return cached
	}
	for handler in router.dynamic_routes {
		match_result, replaced_path_reg, param_names := router.match_path_with_regex(path, handler.path)
		if match_result {
			mut param_map := map[string]string{}
			start, end := replaced_path_reg.match_string(path)
			println('匹配路径: ${path}')
			println('匹配结果: start=${start}, end=${end}')
			println('参数名列表: ${param_names}')
			if start >= 0 && end > start {
				// 从原始路由路径中提取参数名
				mut pamam_reg := regex.regex_opt(r':\w+') or { panic(err) }
				all_params := pamam_reg.find_all_str(handler.path)
				for param in all_params {
					param_name := param[1..]
					group := replaced_path_reg.get_group_by_name(path, param_name)
					println('提取参数 ${param_name} = ${group}')
					param_map[param_name] = group
				}
			}
			println('最终参数映射: ${param_map}')
			route_match := RouteMatch{
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

// 主匹配函数
pub fn (mut router HybridRouter) match_route(method string, path string) ?RouteMatch {
	// 1. 先尝试静态路径匹配（最快）
	if static_handler := router.match_static_route(method, path) {
		return RouteMatch{
			handler: static_handler
			params: map[string]string{}
			path: path
			base_path: ''
		}
	}
	
	// 2. 再尝试动态路径匹配
	return router.match_dynamic_route(method, path)
}

// 获取所有路由（用于调试）
pub fn (router HybridRouter) get_all_routes() ([]string, []string) {
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

// 清理缓存
pub fn (mut router HybridRouter) clear_cache() {
	router.cache.clear()
}

// 获取缓存统计信息
pub fn (router HybridRouter) get_cache_stats() (int, int) {
	return router.cache.size(), router.cache.capacity
}

 