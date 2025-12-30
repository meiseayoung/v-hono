module hono

// Trie 路由节点类型
enum TrieNodeType {
	static
	param
	wildcard
}

// Context Trie 路由节点
@[heap]
pub struct ContextTrieNode {
pub mut:
	segment     string
	node_type   TrieNodeType
	param_name  string
	handler     ?ContextHandler
	children    map[string]&ContextTrieNode
	param_child &ContextTrieNode = unsafe { nil }
	wildcard_child &ContextTrieNode = unsafe { nil }
}

// ContextTrieNode 构造函数
pub fn ContextTrieNode.new(segment string, node_type TrieNodeType, param_name string) &ContextTrieNode {
	return &ContextTrieNode{
		segment: segment
		node_type: node_type
		param_name: param_name
		children: map[string]&ContextTrieNode{}
	}
}

// Context Trie 路由器
pub struct ContextTrieRouter {
mut:
	method_trees map[string]&ContextTrieNode
	cache        ContextLRUCache
}

// ContextTrieRouter 构造函数
pub fn ContextTrieRouter.new() ContextTrieRouter {
	return ContextTrieRouter{
		method_trees: map[string]&ContextTrieNode{}
		cache: ContextLRUCache.new(1000)
	}
}

// 添加路由到 Trie 树
pub fn (mut tr ContextTrieRouter) add_route(method string, path string, handler ContextHandler) {
	if method !in tr.method_trees {
		tr.method_trees[method] = ContextTrieNode.new('', TrieNodeType.static, '')
	}
	
	segments := path.split('/').filter(it != '')
	mut current := tr.method_trees[method] or { return }
	
	for i, seg in segments {
		if seg.starts_with(':') {
			// 参数节点
			if current.param_child == unsafe { nil } {
				current.param_child = ContextTrieNode.new(seg, TrieNodeType.param, seg[1..])
			}
			current = current.param_child
		} else if seg == '*' {
			// 通配符节点
			if current.wildcard_child == unsafe { nil } {
				current.wildcard_child = ContextTrieNode.new(seg, TrieNodeType.wildcard, seg[1..])
			}
			current = current.wildcard_child
		} else {
			// 静态节点
			if seg !in current.children {
				current.children[seg] = ContextTrieNode.new(seg, TrieNodeType.static, '')
			}
			current = current.children[seg] or { return }
		}
		
		// 在最后一个节点设置处理器
		if i == segments.len - 1 {
			current.handler = handler
		}
	}
}

// 在 Trie 树中匹配路由
pub fn (mut tr ContextTrieRouter) match_route(method string, path string) ?ContextRouteMatch {
	// 先检查缓存
	if cached := tr.cache.get(path) {
		return cached
	}
	
	if method !in tr.method_trees {
		return none
	}
	
	segments := path.split('/').filter(it != '')
	mut current := tr.method_trees[method] or { return none }
	mut params := map[string]string{}
	
	for seg in segments {
		// 先尝试静态匹配
		if seg in current.children {
			current = current.children[seg] or { return none }
		} else if current.param_child != unsafe { nil } {
			// 参数匹配
			params[current.param_child.param_name] = seg
			current = current.param_child
		} else if current.wildcard_child != unsafe { nil } {
			// 通配符匹配
			current = current.wildcard_child
			break
		} else {
			return none
		}
	}
	
	if handler := current.handler {
		result := ContextRouteMatch{
			handler: handler
			params: params
		}
		tr.cache.put(path, result)
		return result
	}
	
	return none
}

// 获取所有路由
pub fn (tr ContextTrieRouter) get_all_routes() []string {
	mut routes := []string{}
	
	for _, root in tr.method_trees {
		tr.collect_routes(root, '', mut routes)
	}
	
	return routes
}

// 递归收集路由
fn (tr ContextTrieRouter) collect_routes(node &ContextTrieNode, current_path string, mut routes []string) {
	if node.handler != none {
		routes << current_path
	}
	
	// 收集静态子节点
	for segment, child in node.children {
		tr.collect_routes(child, '${current_path}/${segment}', mut routes)
	}
	
	// 收集参数子节点
	if node.param_child != unsafe { nil } {
		tr.collect_routes(node.param_child, '${current_path}/:${node.param_child.param_name}', mut routes)
	}
	
	// 收集通配符子节点
	if node.wildcard_child != unsafe { nil } {
		tr.collect_routes(node.wildcard_child, '${current_path}/*', mut routes)
	}
} 