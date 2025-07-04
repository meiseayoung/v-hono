module hono

import regex
import net.http

// Trie 路由节点类型
enum TrieNodeType {
	static
	param
	wildcard
}

// Trie 路由节点
struct TrieNode {
mut:
	segment     string
	type        TrieNodeType
	param_name  string
	children    map[string]&TrieNode
	param_child &TrieNode
	wildcard_child &TrieNode
	handler     ?IRequestHandler
}

pub fn new_trie_node(segment string, node_type TrieNodeType, param_name string) &TrieNode {
	return &TrieNode{
		segment: segment
		type: node_type
		param_name: param_name
		children: map[string]&TrieNode{}
		param_child: unsafe { nil }
		wildcard_child: unsafe { nil }
	}
}

// Trie 路由树
pub struct TrieRouter {
mut:
	method_trees map[string]&TrieNode // method分流
	regex_routes []RegexRoute
	cache LRUCache
}

struct RegexRoute {
	method string
	pattern string
	handler IRequestHandler
	reg regex.RE
	param_names []string
}

pub fn new_trie_router() TrieRouter {
	return TrieRouter{
		method_trees: map[string]&TrieNode{}
		regex_routes: []RegexRoute{}
		cache: new_lru_cache(1000)
	}
}

// 注册路由
pub fn (mut tr TrieRouter) add_route(method string, path string, handler IRequestHandler) {
	if path.contains('(') && path.contains(')') {
		// 正则路由
		mut param_names := []string{}
		mut pamam_reg := regex.regex_opt(r':([a-zA-Z_][a-zA-Z0-9_]*)') or { return }
		mut replaced_path := pamam_reg.replace_by_fn(path, fn [mut param_names] (re regex.RE, in_txt string, start int, end int) string {
			param_name := in_txt[start+1..end]
			param_names << param_name
			return '(?P<' + param_name + '>[^/]+)'
		})
		reg := regex.regex_opt(replaced_path + r'$') or { return }
		tr.regex_routes << RegexRoute{
			method: method
			pattern: path
			handler: handler
			reg: reg
			param_names: param_names
		}
		return
	}
	// Trie 路由 method分流
	if method !in tr.method_trees {
		tr.method_trees[method] = new_trie_node('', TrieNodeType.static, '')
	}
	mut node := tr.method_trees[method] or { return }
	segments := path.trim('/').split('/')
	for seg in segments {
		if seg.starts_with(':') {
			if node.param_child == unsafe { nil } {
				node.param_child = new_trie_node(seg, TrieNodeType.param, seg[1..])
			}
			node = node.param_child
		} else if seg.starts_with('*') {
			if node.wildcard_child == unsafe { nil } {
				node.wildcard_child = new_trie_node(seg, TrieNodeType.wildcard, seg[1..])
			}
			node = node.wildcard_child
			break // 通配符为最后一段
		} else {
			if seg !in node.children {
				node.children[seg] = new_trie_node(seg, TrieNodeType.static, '')
			}
			node = node.children[seg] or { return }
		}
	}
	node.handler = handler
}

// 匹配路由
pub fn (mut tr TrieRouter) match_route(method string, path string) ?RouteMatch {
	cache_key := '${method}:${path}'
	if cached := tr.cache.get(cache_key) {
		return cached
	}
	// 1. Trie 路由树 method分流
	if method in tr.method_trees {
		mut params := map[string]string{}
		if handler := tr.match_trie(tr.method_trees[method] or { return none }, path, mut params) {
			route_match := RouteMatch{
				handler: handler
				params: params
				path: path
				base_path: ''
			}
			tr.cache.put(cache_key, route_match)
			return route_match
		}
	}
	// 2. 正则路由
	for reg_route in tr.regex_routes {
		if reg_route.method != method { continue }
		if reg_route.reg.matches_string(path) {
			mut param_map := map[string]string{}
			for param_name in reg_route.param_names {
				param_map[param_name] = reg_route.reg.get_group_by_name(path, param_name)
			}
			route_match := RouteMatch{
				handler: reg_route.handler
				params: param_map
				path: reg_route.pattern
				base_path: ''
			}
			tr.cache.put(cache_key, route_match)
			return route_match
		}
	}
	return none
}

// Trie 路由树查找（递归实现，消除mut node赋值问题）
fn (tr TrieRouter) match_trie_internal(node &TrieNode, segments []string, idx int, mut params map[string]string) ?IRequestHandler {
	if idx == segments.len {
		return node.handler or { return none }
	}
	seg := segments[idx]
	// 优先静态节点
	if seg in node.children {
		return tr.match_trie_internal(node.children[seg] or { return none }, segments, idx+1, mut params)
	}
	// 其次参数节点
	if node.param_child != unsafe { nil } {
		params[node.param_child.param_name] = seg
		return tr.match_trie_internal(node.param_child, segments, idx+1, mut params)
	}
	// 最后通配符节点
	if node.wildcard_child != unsafe { nil } {
		params[node.wildcard_child.param_name] = segments[idx..].join('/')
		return node.wildcard_child.handler or { return none }
	}
	return none
}

fn (tr TrieRouter) match_trie(root &TrieNode, path string, mut params map[string]string) ?IRequestHandler {
	segments := path.trim('/').split('/')
	return tr.match_trie_internal(root, segments, 0, mut params)
} 