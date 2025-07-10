module hono

// 简单的 JSON 解析器
pub struct JsonParser {
pub:
	data string
}

// 创建 JSON 解析器
pub fn new_json_parser(data string) JsonParser {
	return JsonParser{data: data}
}

// 解析 JSON 对象
pub fn (parser JsonParser) parse_object() !map[string]string {
	mut result := map[string]string{}
	
	// 移除外层的大括号
	data := parser.data.trim_space()
	if !data.starts_with('{') || !data.ends_with('}') {
		return error('Invalid JSON object format')
	}
	
	content := data[1..data.len - 1]
	
	// 分割键值对
	pairs := split_json_pairs(content)
	
	for pair in pairs {
		key_value := split_key_value(pair) or { continue }
		result[key_value.key] = key_value.value
	}
	
	return result
}

// 键值对结构
struct KeyValue {
pub:
	key   string
	value string
}

// 分割 JSON 键值对
fn split_json_pairs(content string) []string {
	mut pairs := []string{}
	mut current := ''
	mut brace_count := 0
	mut in_string := false
	mut escape_next := false
	
	for i := 0; i < content.len; i++ {
		ch := content[i]
		
		if escape_next {
			current += ch.str()
			escape_next = false
			continue
		}
		
		if ch == `\\` {
			escape_next = true
			current += ch.str()
			continue
		}
		
		if ch == `"` && !escape_next {
			in_string = !in_string
			current += ch.str()
			continue
		}
		
		if !in_string {
			if ch == `{` {
				brace_count++
			} else if ch == `}` {
				brace_count--
			} else if ch == `,` && brace_count == 0 {
				pairs << current.trim_space()
				current = ''
				continue
			}
		}
		
		current += ch.str()
	}
	
	if current.trim_space() != '' {
		pairs << current.trim_space()
	}
	
	return pairs
}

// 分割键值对
fn split_key_value(pair string) !KeyValue {
	colon_index := pair.index(':') or {
		return error('No colon found')
	}
	mut key := pair[..colon_index].trim_space()
	mut value := pair[colon_index + 1..].trim_space()
	
	// 移除键的引号
	if key.starts_with('"') && key.ends_with('"') {
		key = key[1..key.len - 1]
	}
	
	// 移除值的引号
	if value.starts_with('"') && value.ends_with('"') {
		value = value[1..value.len - 1]
	}
	
	return KeyValue{key: key, value: value}
}

pub struct MergeRequest {
	pub:
	file_hash    string
	filename     string
	total_chunks int
}

// 解析合并请求
pub fn parse_merge_request(body string) !MergeRequest {
	if body.len == 0 {
		return error('Empty request body')
	}
	
	parser := new_json_parser(body)
	obj := parser.parse_object() or {
		return error('Failed to parse JSON')
	}
	
	file_hash := obj['file_hash'] or {
		return error('Missing file_hash')
	}
	filename := obj['filename'] or {
		return error('Missing filename')
	}
	total_chunks_str := obj['total_chunks'] or {
		return error('Missing total_chunks')
	}
	
	if !total_chunks_str.is_int() {
		return error('Invalid total_chunks')
	}
	total_chunks := total_chunks_str.int()
	
	return MergeRequest{
		file_hash: file_hash
		filename: filename
		total_chunks: total_chunks
	}
} 