module hono

import net.http

// Multipart 表单数据项
pub struct MultipartItem {
pub:
	name     string
	filename string
	content  string
	content_type string
}

// Multipart 解析器
pub struct MultipartParser {
pub:
	boundary string
	data     string
}

// 创建 Multipart 解析器
pub fn new_multipart_parser(content_type string, data string) !MultipartParser {
	// 从 Content-Type 中提取 boundary
	boundary := extract_boundary(content_type) or {
		return error('Failed to extract boundary')
	}
	
	return MultipartParser{
		boundary: boundary
		data: data
	}
}

// 解析 multipart 数据
pub fn (parser MultipartParser) parse() ![]MultipartItem {
	mut items := []MultipartItem{}
	// 更健壮的分割方式，兼容不同换行
	parts := parser.data.split('--${parser.boundary}')
	for _, part in parts {
		if part.trim_space() == '' || part.trim_space() == '--' || part.trim_space().starts_with('--') {
			continue
		}
		item := parser.parse_part(part) or { 
			continue 
		}
		items << item
	}
	return items
}

// 解析单个部分
fn (parser MultipartParser) parse_part(part string) !MultipartItem {
	// 分离头部和内容
	header_content := part.split('\r\n\r\n')
	if header_content.len < 2 {
		return error('Invalid part format')
	}
	
	header := header_content[0]
	content := header_content[1..].join('\r\n\r\n')
	
	// 解析头部
	name := extract_header_value(header, 'name') or {
		return error('Missing name')
	}
	filename := extract_header_value(header, 'filename') or { '' }
	content_type := extract_header_value(header, 'Content-Type') or { 'text/plain' }
	
	return MultipartItem{
		name: name
		filename: filename
		content: content
		content_type: content_type
	}
}

// 从 Content-Type 中提取 boundary
fn extract_boundary(content_type string) !string {
	if !content_type.starts_with('multipart/form-data') {
		return error('Not multipart/form-data')
	}
	
	boundary_start := content_type.index('boundary=') or {
		return error('No boundary found')
	}
	mut boundary := content_type[boundary_start + 9..]
	
	// 移除引号
	if boundary.starts_with('"') && boundary.ends_with('"') {
		boundary = boundary[1..boundary.len - 1]
	}
	
	return boundary
}

// 从头部中提取值
fn extract_header_value(header string, key string) !string {
    // 先找 Content-Disposition 行
    for line in header.split('\r\n') {
        if line.starts_with('Content-Disposition:') {
            // 查找 key="value"
            key_eq := '${key}="'
            idx := line.index(key_eq) or { continue }
            start := idx + key_eq.len
            end := line.index_after('"', start) or { line.len }
            return line[start..end]
        }
    }
    return error('Key not found: $key')
}

// 解析 multipart 表单数据（便捷函数）
pub fn parse_multipart_form(req http.Request) !map[string]MultipartItem {
	content_type := req.header.get_custom('Content-Type') or {
		return error('No Content-Type header')
	}
	
	parser := new_multipart_parser(content_type, req.data) or {
		return error('Failed to create parser: $err')
	}
	
	items := parser.parse() or {
		return error('Failed to parse multipart data: $err')
	}
	
	// 转换为 map
	mut result := map[string]MultipartItem{}
	for item in items {
		result[item.name] = item
	}
	
	return result
}

// 获取文件数据
pub fn (items map[string]MultipartItem) get_file(key string) !string {
	item := items[key] or {
		return error('File not found: $key')
	}
	return item.content
}

// 获取表单字段值
pub fn (items map[string]MultipartItem) get(key string) !string {
	item := items[key] or {
		return error('Field not found: $key')
	}
	return item.content
}

// 检查是否为文件
pub fn (items map[string]MultipartItem) is_file(key string) bool {
	item := items[key] or { return false }
	return item.filename != ''
}

// 获取文件名
pub fn (items map[string]MultipartItem) get_filename(key string) !string {
	item := items[key] or {
		return error('Item not found: $key')
	}
	return item.filename
}

// 获取内容类型
pub fn (items map[string]MultipartItem) get_content_type(key string) !string {
	item := items[key] or {
		return error('Item not found: $key')
	}
	return item.content_type
} 