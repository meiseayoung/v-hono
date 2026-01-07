// openapi.v - OpenAPI 3.0/3.1 规范数据结构
// 本模块提供 OpenAPI 文档的数据结构定义，支持 OpenAPI 3.0.x 和 3.1.x 规范
module hono

import x.json2

// ============================================================================
// OpenAPI 基础结构体 (Task 1.1)
// ============================================================================

// OpenAPIContact - 联系信息
pub struct OpenAPIContact {
pub mut:
	name  string
	url   string
	email string
}

// OpenAPILicense - 许可证信息
pub struct OpenAPILicense {
pub mut:
	name string  // 必需
	url  string
}

// OpenAPIInfo - API 基本信息
pub struct OpenAPIInfo {
pub mut:
	title            string  // 必需
	version          string  // 必需
	description      string
	terms_of_service string
	contact          OpenAPIContact
	license          OpenAPILicense
}

// OpenAPIServer - 服务器信息
pub struct OpenAPIServer {
pub mut:
	url         string  // 必需
	description string
}

// OpenAPIExternalDocs - 外部文档
pub struct OpenAPIExternalDocs {
pub mut:
	url         string  // 必需
	description string
}

// OpenAPITag - 标签定义
pub struct OpenAPITag {
pub mut:
	name          string  // 必需
	description   string
	external_docs OpenAPIExternalDocs
}


// ============================================================================
// OpenAPI 路径和操作结构体 (Task 1.2)
// ============================================================================

// OpenAPIMediaType - 媒体类型
pub struct OpenAPIMediaType {
pub mut:
	schema  OpenAPISchema
	example string
}

// OpenAPIHeader - 响应头
pub struct OpenAPIHeader {
pub mut:
	description string
	required    bool
	schema      OpenAPISchema
}

// OpenAPIResponse - 响应定义
pub struct OpenAPIResponse {
pub mut:
	description string  // 必需
	headers     map[string]OpenAPIHeader
	content     map[string]OpenAPIMediaType
}

// OpenAPIRequestBody - 请求体定义
pub struct OpenAPIRequestBody {
pub mut:
	description string
	content     map[string]OpenAPIMediaType  // 必需
	required    bool
}

// OpenAPIParameter - 参数定义
pub struct OpenAPIParameter {
pub mut:
	name        string  // 必需
	in_location string  // 必需: "path", "query", "header", "cookie"
	description string
	required    bool
	deprecated  bool
	schema      OpenAPISchema
	example     string
}

// OpenAPIOperation - 操作定义
pub struct OpenAPIOperation {
pub mut:
	summary      string
	description  string
	operation_id string
	tags         []string
	parameters   []OpenAPIParameter
	request_body OpenAPIRequestBody
	responses    map[string]OpenAPIResponse  // 必需
	deprecated   bool
	security     []map[string][]string
}

// OpenAPIPathItem - 路径项
pub struct OpenAPIPathItem {
pub mut:
	get         OpenAPIOperation
	post        OpenAPIOperation
	put         OpenAPIOperation
	delete      OpenAPIOperation
	patch       OpenAPIOperation
	head        OpenAPIOperation
	options     OpenAPIOperation
	summary     string
	description string
	parameters  []OpenAPIParameter
}


// ============================================================================
// OpenAPI Schema 和 Components 结构体 (Task 1.3)
// ============================================================================

// OpenAPISchema - JSON Schema 定义
pub struct OpenAPISchema {
pub mut:
	schema_type  string  // "string", "integer", "number", "boolean", "array", "object"
	format       string  // "int32", "int64", "float", "double", "date", "date-time", etc.
	title        string
	description  string
	default_val  string
	example      string
	enum_values  []string
	required     []string
	properties   map[string]OpenAPISchema
	items        &OpenAPISchema = unsafe { nil }  // for array type
	minimum      f64
	maximum      f64
	min_length   int
	max_length   int
	pattern      string
	nullable     bool
	read_only    bool
	write_only   bool
	ref          string  // $ref 引用
}

// OpenAPISecurityScheme - 安全方案
pub struct OpenAPISecurityScheme {
pub mut:
	scheme_type   string  // "apiKey", "http", "oauth2", "openIdConnect"
	description   string
	name          string  // for apiKey
	in_location   string  // for apiKey: "query", "header", "cookie"
	scheme        string  // for http: "bearer", "basic"
	bearer_format string  // for http bearer
}

// OpenAPIComponents - 可重用组件
pub struct OpenAPIComponents {
pub mut:
	schemas          map[string]OpenAPISchema
	responses        map[string]OpenAPIResponse
	parameters       map[string]OpenAPIParameter
	request_bodies   map[string]OpenAPIRequestBody
	headers          map[string]OpenAPIHeader
	security_schemes map[string]OpenAPISecurityScheme
}

// OpenAPIDocument - OpenAPI 文档主结构
pub struct OpenAPIDocument {
pub mut:
	openapi       string                       // 必需: "3.0.0" 或 "3.1.0"
	info          OpenAPIInfo                  // 必需
	servers       []OpenAPIServer
	paths         map[string]OpenAPIPathItem   // 必需
	components    OpenAPIComponents
	security      []map[string][]string
	tags          []OpenAPITag
	external_docs OpenAPIExternalDocs
}


// ============================================================================
// OpenAPI 文档序列化 (Task 2.1)
// ============================================================================

// Helper function to check if a string is empty
fn is_empty(s string) bool {
	return s.len == 0
}

// Helper function to check if a map is empty
fn is_map_empty[K, V](m map[K]V) bool {
	return m.len == 0
}

// Helper function to check if an array is empty
fn is_array_empty[T](arr []T) bool {
	return arr.len == 0
}

// to_json - 将 OpenAPIContact 序列化为 JSON
pub fn (c OpenAPIContact) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(c.name) {
		obj['name'] = json2.Any(c.name)
	}
	if !is_empty(c.url) {
		obj['url'] = json2.Any(c.url)
	}
	if !is_empty(c.email) {
		obj['email'] = json2.Any(c.email)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPILicense 序列化为 JSON
pub fn (l OpenAPILicense) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// name is required
	obj['name'] = json2.Any(l.name)
	if !is_empty(l.url) {
		obj['url'] = json2.Any(l.url)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIInfo 序列化为 JSON
pub fn (i OpenAPIInfo) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// title and version are required
	obj['title'] = json2.Any(i.title)
	obj['version'] = json2.Any(i.version)
	if !is_empty(i.description) {
		obj['description'] = json2.Any(i.description)
	}
	if !is_empty(i.terms_of_service) {
		obj['termsOfService'] = json2.Any(i.terms_of_service)
	}
	// Only include contact if it has any non-empty fields
	if !is_empty(i.contact.name) || !is_empty(i.contact.url) || !is_empty(i.contact.email) {
		obj['contact'] = i.contact.to_json()
	}
	// Only include license if name is set (required field)
	if !is_empty(i.license.name) {
		obj['license'] = i.license.to_json()
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIServer 序列化为 JSON
pub fn (s OpenAPIServer) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// url is required
	obj['url'] = json2.Any(s.url)
	if !is_empty(s.description) {
		obj['description'] = json2.Any(s.description)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIExternalDocs 序列化为 JSON
pub fn (e OpenAPIExternalDocs) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// url is required
	obj['url'] = json2.Any(e.url)
	if !is_empty(e.description) {
		obj['description'] = json2.Any(e.description)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPITag 序列化为 JSON
pub fn (t OpenAPITag) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// name is required
	obj['name'] = json2.Any(t.name)
	if !is_empty(t.description) {
		obj['description'] = json2.Any(t.description)
	}
	if !is_empty(t.external_docs.url) {
		obj['externalDocs'] = t.external_docs.to_json()
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPISchema 序列化为 JSON
pub fn (s OpenAPISchema) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	
	// Handle $ref - if ref is set, only output $ref
	if !is_empty(s.ref) {
		obj[r'$ref'] = json2.Any(s.ref)
		return json2.Any(obj)
	}
	
	// schema_type -> type
	if !is_empty(s.schema_type) {
		obj['type'] = json2.Any(s.schema_type)
	}
	if !is_empty(s.format) {
		obj['format'] = json2.Any(s.format)
	}
	if !is_empty(s.title) {
		obj['title'] = json2.Any(s.title)
	}
	if !is_empty(s.description) {
		obj['description'] = json2.Any(s.description)
	}
	if !is_empty(s.default_val) {
		obj['default'] = json2.Any(s.default_val)
	}
	if !is_empty(s.example) {
		obj['example'] = json2.Any(s.example)
	}
	// enum_values -> enum
	if !is_array_empty(s.enum_values) {
		mut enum_arr := []json2.Any{}
		for v in s.enum_values {
			enum_arr << json2.Any(v)
		}
		obj['enum'] = json2.Any(enum_arr)
	}
	if !is_array_empty(s.required) {
		mut req_arr := []json2.Any{}
		for r in s.required {
			req_arr << json2.Any(r)
		}
		obj['required'] = json2.Any(req_arr)
	}
	if !is_map_empty(s.properties) {
		mut props := map[string]json2.Any{}
		for key, val in s.properties {
			props[key] = val.to_json()
		}
		obj['properties'] = json2.Any(props)
	}
	// items for array type
	if s.items != unsafe { nil } {
		obj['items'] = s.items.to_json()
	}
	if s.minimum != 0 {
		obj['minimum'] = json2.Any(s.minimum)
	}
	if s.maximum != 0 {
		obj['maximum'] = json2.Any(s.maximum)
	}
	if s.min_length != 0 {
		obj['minLength'] = json2.Any(s.min_length)
	}
	if s.max_length != 0 {
		obj['maxLength'] = json2.Any(s.max_length)
	}
	if !is_empty(s.pattern) {
		obj['pattern'] = json2.Any(s.pattern)
	}
	if s.nullable {
		obj['nullable'] = json2.Any(s.nullable)
	}
	if s.read_only {
		obj['readOnly'] = json2.Any(s.read_only)
	}
	if s.write_only {
		obj['writeOnly'] = json2.Any(s.write_only)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIHeader 序列化为 JSON
pub fn (h OpenAPIHeader) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(h.description) {
		obj['description'] = json2.Any(h.description)
	}
	if h.required {
		obj['required'] = json2.Any(h.required)
	}
	// Only include schema if it has content
	if !is_empty(h.schema.schema_type) || !is_empty(h.schema.ref) {
		obj['schema'] = h.schema.to_json()
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIMediaType 序列化为 JSON
pub fn (m OpenAPIMediaType) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// Only include schema if it has content
	if !is_empty(m.schema.schema_type) || !is_empty(m.schema.ref) || !is_map_empty(m.schema.properties) {
		obj['schema'] = m.schema.to_json()
	}
	if !is_empty(m.example) {
		obj['example'] = json2.Any(m.example)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIResponse 序列化为 JSON
pub fn (r OpenAPIResponse) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// description is required
	obj['description'] = json2.Any(r.description)
	if !is_map_empty(r.headers) {
		mut headers := map[string]json2.Any{}
		for key, val in r.headers {
			headers[key] = val.to_json()
		}
		obj['headers'] = json2.Any(headers)
	}
	if !is_map_empty(r.content) {
		mut content := map[string]json2.Any{}
		for key, val in r.content {
			content[key] = val.to_json()
		}
		obj['content'] = json2.Any(content)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIRequestBody 序列化为 JSON
pub fn (rb OpenAPIRequestBody) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(rb.description) {
		obj['description'] = json2.Any(rb.description)
	}
	// content is required
	if !is_map_empty(rb.content) {
		mut content := map[string]json2.Any{}
		for key, val in rb.content {
			content[key] = val.to_json()
		}
		obj['content'] = json2.Any(content)
	}
	if rb.required {
		obj['required'] = json2.Any(rb.required)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIParameter 序列化为 JSON
pub fn (p OpenAPIParameter) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// name is required
	obj['name'] = json2.Any(p.name)
	// in_location -> in (required)
	obj['in'] = json2.Any(p.in_location)
	if !is_empty(p.description) {
		obj['description'] = json2.Any(p.description)
	}
	if p.required {
		obj['required'] = json2.Any(p.required)
	}
	if p.deprecated {
		obj['deprecated'] = json2.Any(p.deprecated)
	}
	// Only include schema if it has content
	if !is_empty(p.schema.schema_type) || !is_empty(p.schema.ref) {
		obj['schema'] = p.schema.to_json()
	}
	if !is_empty(p.example) {
		obj['example'] = json2.Any(p.example)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIOperation 序列化为 JSON
pub fn (op OpenAPIOperation) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(op.summary) {
		obj['summary'] = json2.Any(op.summary)
	}
	if !is_empty(op.description) {
		obj['description'] = json2.Any(op.description)
	}
	if !is_empty(op.operation_id) {
		obj['operationId'] = json2.Any(op.operation_id)
	}
	if !is_array_empty(op.tags) {
		mut tags_arr := []json2.Any{}
		for t in op.tags {
			tags_arr << json2.Any(t)
		}
		obj['tags'] = json2.Any(tags_arr)
	}
	if !is_array_empty(op.parameters) {
		mut params_arr := []json2.Any{}
		for p in op.parameters {
			params_arr << p.to_json()
		}
		obj['parameters'] = json2.Any(params_arr)
	}
	// Only include request_body if it has content
	if !is_map_empty(op.request_body.content) {
		obj['requestBody'] = op.request_body.to_json()
	}
	// responses is required
	if !is_map_empty(op.responses) {
		mut responses := map[string]json2.Any{}
		for key, val in op.responses {
			responses[key] = val.to_json()
		}
		obj['responses'] = json2.Any(responses)
	}
	if op.deprecated {
		obj['deprecated'] = json2.Any(op.deprecated)
	}
	if !is_array_empty(op.security) {
		mut sec_arr := []json2.Any{}
		for sec in op.security {
			mut sec_obj := map[string]json2.Any{}
			for key, val in sec {
				mut scopes := []json2.Any{}
				for scope in val {
					scopes << json2.Any(scope)
				}
				sec_obj[key] = json2.Any(scopes)
			}
			sec_arr << json2.Any(sec_obj)
		}
		obj['security'] = json2.Any(sec_arr)
	}
	return json2.Any(obj)
}

// Helper to check if an operation is empty (has no responses)
fn is_operation_empty(op OpenAPIOperation) bool {
	return is_map_empty(op.responses)
}

// to_json - 将 OpenAPIPathItem 序列化为 JSON
pub fn (pi OpenAPIPathItem) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_empty(pi.summary) {
		obj['summary'] = json2.Any(pi.summary)
	}
	if !is_empty(pi.description) {
		obj['description'] = json2.Any(pi.description)
	}
	if !is_array_empty(pi.parameters) {
		mut params_arr := []json2.Any{}
		for p in pi.parameters {
			params_arr << p.to_json()
		}
		obj['parameters'] = json2.Any(params_arr)
	}
	// HTTP methods - only include if they have responses
	if !is_operation_empty(pi.get) {
		obj['get'] = pi.get.to_json()
	}
	if !is_operation_empty(pi.post) {
		obj['post'] = pi.post.to_json()
	}
	if !is_operation_empty(pi.put) {
		obj['put'] = pi.put.to_json()
	}
	if !is_operation_empty(pi.delete) {
		obj['delete'] = pi.delete.to_json()
	}
	if !is_operation_empty(pi.patch) {
		obj['patch'] = pi.patch.to_json()
	}
	if !is_operation_empty(pi.head) {
		obj['head'] = pi.head.to_json()
	}
	if !is_operation_empty(pi.options) {
		obj['options'] = pi.options.to_json()
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPISecurityScheme 序列化为 JSON
pub fn (ss OpenAPISecurityScheme) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// scheme_type -> type
	if !is_empty(ss.scheme_type) {
		obj['type'] = json2.Any(ss.scheme_type)
	}
	if !is_empty(ss.description) {
		obj['description'] = json2.Any(ss.description)
	}
	if !is_empty(ss.name) {
		obj['name'] = json2.Any(ss.name)
	}
	// in_location -> in
	if !is_empty(ss.in_location) {
		obj['in'] = json2.Any(ss.in_location)
	}
	if !is_empty(ss.scheme) {
		obj['scheme'] = json2.Any(ss.scheme)
	}
	if !is_empty(ss.bearer_format) {
		obj['bearerFormat'] = json2.Any(ss.bearer_format)
	}
	return json2.Any(obj)
}

// Helper to check if components is empty
fn is_components_empty(c OpenAPIComponents) bool {
	return is_map_empty(c.schemas) && is_map_empty(c.responses) && 
		is_map_empty(c.parameters) && is_map_empty(c.request_bodies) && 
		is_map_empty(c.headers) && is_map_empty(c.security_schemes)
}

// to_json - 将 OpenAPIComponents 序列化为 JSON
pub fn (c OpenAPIComponents) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	if !is_map_empty(c.schemas) {
		mut schemas := map[string]json2.Any{}
		for key, val in c.schemas {
			schemas[key] = val.to_json()
		}
		obj['schemas'] = json2.Any(schemas)
	}
	if !is_map_empty(c.responses) {
		mut responses := map[string]json2.Any{}
		for key, val in c.responses {
			responses[key] = val.to_json()
		}
		obj['responses'] = json2.Any(responses)
	}
	if !is_map_empty(c.parameters) {
		mut parameters := map[string]json2.Any{}
		for key, val in c.parameters {
			parameters[key] = val.to_json()
		}
		obj['parameters'] = json2.Any(parameters)
	}
	if !is_map_empty(c.request_bodies) {
		mut request_bodies := map[string]json2.Any{}
		for key, val in c.request_bodies {
			request_bodies[key] = val.to_json()
		}
		obj['requestBodies'] = json2.Any(request_bodies)
	}
	if !is_map_empty(c.headers) {
		mut headers := map[string]json2.Any{}
		for key, val in c.headers {
			headers[key] = val.to_json()
		}
		obj['headers'] = json2.Any(headers)
	}
	if !is_map_empty(c.security_schemes) {
		mut security_schemes := map[string]json2.Any{}
		for key, val in c.security_schemes {
			security_schemes[key] = val.to_json()
		}
		obj['securitySchemes'] = json2.Any(security_schemes)
	}
	return json2.Any(obj)
}

// to_json - 将 OpenAPIDocument 序列化为 JSON Any 对象
pub fn (doc OpenAPIDocument) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	// openapi is required
	obj['openapi'] = json2.Any(doc.openapi)
	// info is required
	obj['info'] = doc.info.to_json()
	// servers (optional)
	if !is_array_empty(doc.servers) {
		mut servers_arr := []json2.Any{}
		for s in doc.servers {
			servers_arr << s.to_json()
		}
		obj['servers'] = json2.Any(servers_arr)
	}
	// paths is required
	mut paths := map[string]json2.Any{}
	for key, val in doc.paths {
		paths[key] = val.to_json()
	}
	obj['paths'] = json2.Any(paths)
	// components (optional)
	if !is_components_empty(doc.components) {
		obj['components'] = doc.components.to_json()
	}
	// security (optional)
	if !is_array_empty(doc.security) {
		mut sec_arr := []json2.Any{}
		for sec in doc.security {
			mut sec_obj := map[string]json2.Any{}
			for key, val in sec {
				mut scopes := []json2.Any{}
				for scope in val {
					scopes << json2.Any(scope)
				}
				sec_obj[key] = json2.Any(scopes)
			}
			sec_arr << json2.Any(sec_obj)
		}
		obj['security'] = json2.Any(sec_arr)
	}
	// tags (optional)
	if !is_array_empty(doc.tags) {
		mut tags_arr := []json2.Any{}
		for t in doc.tags {
			tags_arr << t.to_json()
		}
		obj['tags'] = json2.Any(tags_arr)
	}
	// external_docs (optional)
	if !is_empty(doc.external_docs.url) {
		obj['externalDocs'] = doc.external_docs.to_json()
	}
	return json2.Any(obj)
}

// to_json_str - 将 OpenAPIDocument 序列化为 JSON 字符串
pub fn (doc OpenAPIDocument) to_json_str() string {
	return doc.to_json().str()
}

// to_json_pretty - 将 OpenAPIDocument 序列化为格式化的 JSON 字符串
pub fn (doc OpenAPIDocument) to_json_pretty() string {
	return json2.encode(doc.to_json(), prettify: true)
}


// ============================================================================
// OpenAPI 文档反序列化 (Task 2.3)
// ============================================================================

// from_json - 从 JSON Any 对象反序列化 OpenAPIContact
pub fn OpenAPIContact.from_json(j json2.Any) OpenAPIContact {
	obj := j.as_map()
	return OpenAPIContact{
		name: if 'name' in obj { obj['name'].str() } else { '' }
		url: if 'url' in obj { obj['url'].str() } else { '' }
		email: if 'email' in obj { obj['email'].str() } else { '' }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPILicense
pub fn OpenAPILicense.from_json(j json2.Any) OpenAPILicense {
	obj := j.as_map()
	return OpenAPILicense{
		name: if 'name' in obj { obj['name'].str() } else { '' }
		url: if 'url' in obj { obj['url'].str() } else { '' }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIInfo
pub fn OpenAPIInfo.from_json(j json2.Any) OpenAPIInfo {
	obj := j.as_map()
	return OpenAPIInfo{
		title: if 'title' in obj { obj['title'].str() } else { '' }
		version: if 'version' in obj { obj['version'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
		terms_of_service: if 'termsOfService' in obj { obj['termsOfService'].str() } else { '' }
		contact: if 'contact' in obj { OpenAPIContact.from_json(obj['contact']) } else { OpenAPIContact{} }
		license: if 'license' in obj { OpenAPILicense.from_json(obj['license']) } else { OpenAPILicense{} }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIServer
pub fn OpenAPIServer.from_json(j json2.Any) OpenAPIServer {
	obj := j.as_map()
	return OpenAPIServer{
		url: if 'url' in obj { obj['url'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIExternalDocs
pub fn OpenAPIExternalDocs.from_json(j json2.Any) OpenAPIExternalDocs {
	obj := j.as_map()
	return OpenAPIExternalDocs{
		url: if 'url' in obj { obj['url'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPITag
pub fn OpenAPITag.from_json(j json2.Any) OpenAPITag {
	obj := j.as_map()
	return OpenAPITag{
		name: if 'name' in obj { obj['name'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
		external_docs: if 'externalDocs' in obj { OpenAPIExternalDocs.from_json(obj['externalDocs']) } else { OpenAPIExternalDocs{} }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPISchema
pub fn OpenAPISchema.from_json(j json2.Any) OpenAPISchema {
	return openapi_schema_from_json_impl(j)
}

// Helper function to parse OpenAPISchema from JSON
fn openapi_schema_from_json_impl(j json2.Any) OpenAPISchema {
	obj := j.as_map()
	
	// Parse properties map
	mut props := map[string]OpenAPISchema{}
	if 'properties' in obj {
		props_obj := obj['properties'].as_map()
		for key, val in props_obj {
			props[key] = openapi_schema_from_json_impl(val)
		}
	}
	
	// Parse enum values
	mut enum_vals := []string{}
	if 'enum' in obj {
		for e in obj['enum'].arr() {
			enum_vals << e.str()
		}
	}
	
	// Parse required array
	mut required := []string{}
	if 'required' in obj {
		for r in obj['required'].arr() {
			required << r.str()
		}
	}
	
	mut schema := OpenAPISchema{
		schema_type: if 'type' in obj { obj['type'].str() } else { '' }
		format: if 'format' in obj { obj['format'].str() } else { '' }
		title: if 'title' in obj { obj['title'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
		default_val: if 'default' in obj { obj['default'].str() } else { '' }
		example: if 'example' in obj { obj['example'].str() } else { '' }
		enum_values: enum_vals
		required: required
		properties: props
		minimum: if 'minimum' in obj { obj['minimum'].f64() } else { 0 }
		maximum: if 'maximum' in obj { obj['maximum'].f64() } else { 0 }
		min_length: if 'minLength' in obj { obj['minLength'].int() } else { 0 }
		max_length: if 'maxLength' in obj { obj['maxLength'].int() } else { 0 }
		pattern: if 'pattern' in obj { obj['pattern'].str() } else { '' }
		nullable: if 'nullable' in obj { obj['nullable'].bool() } else { false }
		read_only: if 'readOnly' in obj { obj['readOnly'].bool() } else { false }
		write_only: if 'writeOnly' in obj { obj['writeOnly'].bool() } else { false }
		ref: if r'$ref' in obj { obj[r'$ref'].str() } else { '' }
	}
	
	// Parse items (for array type) - handle pointer separately
	if 'items' in obj {
		items_schema := openapi_schema_from_json_impl(obj['items'])
		schema.items = &items_schema
	}
	
	return schema
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIHeader
pub fn OpenAPIHeader.from_json(j json2.Any) OpenAPIHeader {
	obj := j.as_map()
	return OpenAPIHeader{
		description: if 'description' in obj { obj['description'].str() } else { '' }
		required: if 'required' in obj { obj['required'].bool() } else { false }
		schema: if 'schema' in obj { OpenAPISchema.from_json(obj['schema']) } else { OpenAPISchema{} }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIMediaType
pub fn OpenAPIMediaType.from_json(j json2.Any) OpenAPIMediaType {
	obj := j.as_map()
	return OpenAPIMediaType{
		schema: if 'schema' in obj { OpenAPISchema.from_json(obj['schema']) } else { OpenAPISchema{} }
		example: if 'example' in obj { obj['example'].str() } else { '' }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIResponse
pub fn OpenAPIResponse.from_json(j json2.Any) OpenAPIResponse {
	obj := j.as_map()
	
	// Parse headers map
	mut headers := map[string]OpenAPIHeader{}
	if 'headers' in obj {
		headers_obj := obj['headers'].as_map()
		for key, val in headers_obj {
			headers[key] = OpenAPIHeader.from_json(val)
		}
	}
	
	// Parse content map
	mut content := map[string]OpenAPIMediaType{}
	if 'content' in obj {
		content_obj := obj['content'].as_map()
		for key, val in content_obj {
			content[key] = OpenAPIMediaType.from_json(val)
		}
	}
	
	return OpenAPIResponse{
		description: if 'description' in obj { obj['description'].str() } else { '' }
		headers: headers
		content: content
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIRequestBody
pub fn OpenAPIRequestBody.from_json(j json2.Any) OpenAPIRequestBody {
	obj := j.as_map()
	
	// Parse content map
	mut content := map[string]OpenAPIMediaType{}
	if 'content' in obj {
		content_obj := obj['content'].as_map()
		for key, val in content_obj {
			content[key] = OpenAPIMediaType.from_json(val)
		}
	}
	
	return OpenAPIRequestBody{
		description: if 'description' in obj { obj['description'].str() } else { '' }
		content: content
		required: if 'required' in obj { obj['required'].bool() } else { false }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIParameter
pub fn OpenAPIParameter.from_json(j json2.Any) OpenAPIParameter {
	obj := j.as_map()
	return OpenAPIParameter{
		name: if 'name' in obj { obj['name'].str() } else { '' }
		in_location: if 'in' in obj { obj['in'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
		required: if 'required' in obj { obj['required'].bool() } else { false }
		deprecated: if 'deprecated' in obj { obj['deprecated'].bool() } else { false }
		schema: if 'schema' in obj { OpenAPISchema.from_json(obj['schema']) } else { OpenAPISchema{} }
		example: if 'example' in obj { obj['example'].str() } else { '' }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIOperation
pub fn OpenAPIOperation.from_json(j json2.Any) OpenAPIOperation {
	obj := j.as_map()
	
	// Parse tags array
	mut tags := []string{}
	if 'tags' in obj {
		for t in obj['tags'].arr() {
			tags << t.str()
		}
	}
	
	// Parse parameters array
	mut parameters := []OpenAPIParameter{}
	if 'parameters' in obj {
		for p in obj['parameters'].arr() {
			parameters << OpenAPIParameter.from_json(p)
		}
	}
	
	// Parse responses map
	mut responses := map[string]OpenAPIResponse{}
	if 'responses' in obj {
		responses_obj := obj['responses'].as_map()
		for key, val in responses_obj {
			responses[key] = OpenAPIResponse.from_json(val)
		}
	}
	
	// Parse security array
	mut security := []map[string][]string{}
	if 'security' in obj {
		for sec in obj['security'].arr() {
			mut sec_map := map[string][]string{}
			sec_obj := sec.as_map()
			for key, val in sec_obj {
				mut scopes := []string{}
				for scope in val.arr() {
					scopes << scope.str()
				}
				sec_map[key] = scopes
			}
			security << sec_map
		}
	}
	
	return OpenAPIOperation{
		summary: if 'summary' in obj { obj['summary'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
		operation_id: if 'operationId' in obj { obj['operationId'].str() } else { '' }
		tags: tags
		parameters: parameters
		request_body: if 'requestBody' in obj { OpenAPIRequestBody.from_json(obj['requestBody']) } else { OpenAPIRequestBody{} }
		responses: responses
		deprecated: if 'deprecated' in obj { obj['deprecated'].bool() } else { false }
		security: security
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIPathItem
pub fn OpenAPIPathItem.from_json(j json2.Any) OpenAPIPathItem {
	obj := j.as_map()
	
	// Parse parameters array
	mut parameters := []OpenAPIParameter{}
	if 'parameters' in obj {
		for p in obj['parameters'].arr() {
			parameters << OpenAPIParameter.from_json(p)
		}
	}
	
	return OpenAPIPathItem{
		summary: if 'summary' in obj { obj['summary'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
		parameters: parameters
		get: if 'get' in obj { OpenAPIOperation.from_json(obj['get']) } else { OpenAPIOperation{} }
		post: if 'post' in obj { OpenAPIOperation.from_json(obj['post']) } else { OpenAPIOperation{} }
		put: if 'put' in obj { OpenAPIOperation.from_json(obj['put']) } else { OpenAPIOperation{} }
		delete: if 'delete' in obj { OpenAPIOperation.from_json(obj['delete']) } else { OpenAPIOperation{} }
		patch: if 'patch' in obj { OpenAPIOperation.from_json(obj['patch']) } else { OpenAPIOperation{} }
		head: if 'head' in obj { OpenAPIOperation.from_json(obj['head']) } else { OpenAPIOperation{} }
		options: if 'options' in obj { OpenAPIOperation.from_json(obj['options']) } else { OpenAPIOperation{} }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPISecurityScheme
pub fn OpenAPISecurityScheme.from_json(j json2.Any) OpenAPISecurityScheme {
	obj := j.as_map()
	return OpenAPISecurityScheme{
		scheme_type: if 'type' in obj { obj['type'].str() } else { '' }
		description: if 'description' in obj { obj['description'].str() } else { '' }
		name: if 'name' in obj { obj['name'].str() } else { '' }
		in_location: if 'in' in obj { obj['in'].str() } else { '' }
		scheme: if 'scheme' in obj { obj['scheme'].str() } else { '' }
		bearer_format: if 'bearerFormat' in obj { obj['bearerFormat'].str() } else { '' }
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIComponents
pub fn OpenAPIComponents.from_json(j json2.Any) OpenAPIComponents {
	obj := j.as_map()
	
	// Parse schemas map
	mut schemas := map[string]OpenAPISchema{}
	if 'schemas' in obj {
		schemas_obj := obj['schemas'].as_map()
		for key, val in schemas_obj {
			schemas[key] = OpenAPISchema.from_json(val)
		}
	}
	
	// Parse responses map
	mut responses := map[string]OpenAPIResponse{}
	if 'responses' in obj {
		responses_obj := obj['responses'].as_map()
		for key, val in responses_obj {
			responses[key] = OpenAPIResponse.from_json(val)
		}
	}
	
	// Parse parameters map
	mut parameters := map[string]OpenAPIParameter{}
	if 'parameters' in obj {
		parameters_obj := obj['parameters'].as_map()
		for key, val in parameters_obj {
			parameters[key] = OpenAPIParameter.from_json(val)
		}
	}
	
	// Parse request_bodies map
	mut request_bodies := map[string]OpenAPIRequestBody{}
	if 'requestBodies' in obj {
		request_bodies_obj := obj['requestBodies'].as_map()
		for key, val in request_bodies_obj {
			request_bodies[key] = OpenAPIRequestBody.from_json(val)
		}
	}
	
	// Parse headers map
	mut headers := map[string]OpenAPIHeader{}
	if 'headers' in obj {
		headers_obj := obj['headers'].as_map()
		for key, val in headers_obj {
			headers[key] = OpenAPIHeader.from_json(val)
		}
	}
	
	// Parse security_schemes map
	mut security_schemes := map[string]OpenAPISecurityScheme{}
	if 'securitySchemes' in obj {
		security_schemes_obj := obj['securitySchemes'].as_map()
		for key, val in security_schemes_obj {
			security_schemes[key] = OpenAPISecurityScheme.from_json(val)
		}
	}
	
	return OpenAPIComponents{
		schemas: schemas
		responses: responses
		parameters: parameters
		request_bodies: request_bodies
		headers: headers
		security_schemes: security_schemes
	}
}

// from_json - 从 JSON Any 对象反序列化 OpenAPIDocument
pub fn OpenAPIDocument.from_json(j json2.Any) OpenAPIDocument {
	obj := j.as_map()
	
	// Parse servers array
	mut servers := []OpenAPIServer{}
	if 'servers' in obj {
		for s in obj['servers'].arr() {
			servers << OpenAPIServer.from_json(s)
		}
	}
	
	// Parse paths map
	mut paths := map[string]OpenAPIPathItem{}
	if 'paths' in obj {
		paths_obj := obj['paths'].as_map()
		for key, val in paths_obj {
			paths[key] = OpenAPIPathItem.from_json(val)
		}
	}
	
	// Parse security array
	mut security := []map[string][]string{}
	if 'security' in obj {
		for sec in obj['security'].arr() {
			mut sec_map := map[string][]string{}
			sec_obj := sec.as_map()
			for key, val in sec_obj {
				mut scopes := []string{}
				for scope in val.arr() {
					scopes << scope.str()
				}
				sec_map[key] = scopes
			}
			security << sec_map
		}
	}
	
	// Parse tags array
	mut tags := []OpenAPITag{}
	if 'tags' in obj {
		for t in obj['tags'].arr() {
			tags << OpenAPITag.from_json(t)
		}
	}
	
	return OpenAPIDocument{
		openapi: if 'openapi' in obj { obj['openapi'].str() } else { '' }
		info: if 'info' in obj { OpenAPIInfo.from_json(obj['info']) } else { OpenAPIInfo{} }
		servers: servers
		paths: paths
		components: if 'components' in obj { OpenAPIComponents.from_json(obj['components']) } else { OpenAPIComponents{} }
		security: security
		tags: tags
		external_docs: if 'externalDocs' in obj { OpenAPIExternalDocs.from_json(obj['externalDocs']) } else { OpenAPIExternalDocs{} }
	}
}

// from_json_str - 从 JSON 字符串反序列化 OpenAPIDocument
pub fn OpenAPIDocument.from_json_str(json_str string) !OpenAPIDocument {
	parsed := json2.decode[json2.Any](json_str)!
	return OpenAPIDocument.from_json(parsed)
}


// ============================================================================
// OpenAPI 文档验证 (Task 4.1)
// ============================================================================

// OpenAPIErrorKind - OpenAPI 错误类型
pub enum OpenAPIErrorKind {
	missing_required_field
	invalid_version
	invalid_path
	invalid_parameter
	invalid_schema
	serialization_error
	deserialization_error
}

// OpenAPIError - OpenAPI 相关错误
pub struct OpenAPIError {
	Error
pub:
	kind       OpenAPIErrorKind
	error_msg  string
	path       string  // 可选：问题路径
	field      string  // 可选：问题字段
}

// msg - 实现 IError 接口
pub fn (e OpenAPIError) msg() string {
	return e.error_msg
}

// 支持的 OpenAPI 版本
const supported_openapi_versions = ['3.0.0', '3.0.1', '3.0.2', '3.0.3', '3.1.0']

// validate - 验证 OpenAPIDocument 的有效性
// 验证必需字段、OpenAPI 版本和路径格式
// 返回描述性错误信息
pub fn (doc OpenAPIDocument) validate() ! {
	// 1. 验证必需字段: openapi
	if is_empty(doc.openapi) {
		return error("Missing required field 'openapi' in OpenAPI document")
	}
	
	// 2. 验证 OpenAPI 版本 (3.0.x, 3.1.x)
	if doc.openapi !in supported_openapi_versions {
		return error("Unsupported OpenAPI version '${doc.openapi}'. Supported versions: ${supported_openapi_versions.join(', ')}")
	}
	
	// 3. 验证必需字段: info
	if is_empty(doc.info.title) {
		return error("Missing required field 'info.title' in OpenAPI document")
	}
	
	if is_empty(doc.info.version) {
		return error("Missing required field 'info.version' in OpenAPI document")
	}
	
	// 4. 验证路径格式
	for path, _ in doc.paths {
		// 路径必须以 '/' 开头
		if !path.starts_with('/') {
			return error("Invalid path '${path}': paths must start with '/'")
		}
		
		// 检查路径参数格式 - 支持 {param} 和 :param 两种格式
		// 验证 {param} 格式的括号匹配
		mut open_braces := 0
		mut last_open_idx := -1
		for i, c in path {
			if c == `{` {
				open_braces++
				last_open_idx = i
			} else if c == `}` {
				open_braces--
				if open_braces < 0 {
					return error("Invalid path '${path}': unmatched '}' at position ${i}")
				}
			}
		}
		if open_braces > 0 {
			return error("Invalid path '${path}': unmatched '{' at position ${last_open_idx}")
		}
		
		// 检查空路径参数 {} 或 :
		if path.contains('{}') {
			return error("Invalid path '${path}': empty path parameter '{}'")
		}
		
		// 检查连续斜杠
		if path.contains('//') {
			return error("Invalid path '${path}': contains consecutive slashes '//'")
		}
	}
	
	// 验证通过
	return
}

// validate_with_details - 验证并返回所有错误（不仅仅是第一个）
pub fn (doc OpenAPIDocument) validate_with_details() []OpenAPIError {
	mut errors := []OpenAPIError{}
	
	// 1. 验证必需字段: openapi
	if is_empty(doc.openapi) {
		errors << OpenAPIError{
			kind: .missing_required_field
			error_msg: "Missing required field 'openapi' in OpenAPI document"
			field: 'openapi'
		}
	} else if doc.openapi !in supported_openapi_versions {
		// 2. 验证 OpenAPI 版本
		errors << OpenAPIError{
			kind: .invalid_version
			error_msg: "Unsupported OpenAPI version '${doc.openapi}'. Supported versions: ${supported_openapi_versions.join(', ')}"
			field: 'openapi'
		}
	}
	
	// 3. 验证必需字段: info
	if is_empty(doc.info.title) {
		errors << OpenAPIError{
			kind: .missing_required_field
			error_msg: "Missing required field 'info.title' in OpenAPI document"
			field: 'info.title'
		}
	}
	
	if is_empty(doc.info.version) {
		errors << OpenAPIError{
			kind: .missing_required_field
			error_msg: "Missing required field 'info.version' in OpenAPI document"
			field: 'info.version'
		}
	}
	
	// 4. 验证路径格式
	for path, _ in doc.paths {
		// 路径必须以 '/' 开头
		if !path.starts_with('/') {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': paths must start with '/'"
				path: path
			}
			continue
		}
		
		// 检查路径参数格式
		mut open_braces := 0
		mut last_open_idx := -1
		mut has_brace_error := false
		for i, c in path {
			if c == `{` {
				open_braces++
				last_open_idx = i
			} else if c == `}` {
				open_braces--
				if open_braces < 0 {
					errors << OpenAPIError{
						kind: .invalid_path
						error_msg: "Invalid path '${path}': unmatched '}' at position ${i}"
						path: path
					}
					has_brace_error = true
					break
				}
			}
		}
		if !has_brace_error && open_braces > 0 {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': unmatched '{' at position ${last_open_idx}"
				path: path
			}
		}
		
		// 检查空路径参数
		if path.contains('{}') {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': empty path parameter '{}'"
				path: path
			}
		}
		
		// 检查连续斜杠
		if path.contains('//') {
			errors << OpenAPIError{
				kind: .invalid_path
				error_msg: "Invalid path '${path}': contains consecutive slashes '//'"
				path: path
			}
		}
	}
	
	return errors
}

// is_valid - 检查文档是否有效
pub fn (doc OpenAPIDocument) is_valid() bool {
	doc.validate() or { return false }
	return true
}


// ============================================================================
// OpenAPI 文档构建器 (Task 5)
// ============================================================================

// OpenAPIBuilder - 流式 API 构建器
// 使用示例:
//   doc := OpenAPIBuilder.new()
//       .openapi('3.0.0')
//       .title('My API')
//       .version('1.0.0')
//       .description('API description')
//       .server('https://api.example.com', 'Production server')
//       .tag('users', 'User operations')
//       .path('/users')
//           .get(OpenAPIOperation{ ... })
//           .post(OpenAPIOperation{ ... })
//           .done()
//       .build()!
pub struct OpenAPIBuilder {
mut:
	doc OpenAPIDocument
}

// new - 创建新的 OpenAPIBuilder 实例
pub fn OpenAPIBuilder.new() OpenAPIBuilder {
	return OpenAPIBuilder{
		doc: OpenAPIDocument{
			paths: map[string]OpenAPIPathItem{}
		}
	}
}

// openapi - 设置 OpenAPI 版本
pub fn (mut b OpenAPIBuilder) openapi(version string) &OpenAPIBuilder {
	b.doc.openapi = version
	return unsafe { b }
}

// info - 设置完整的 API 信息
pub fn (mut b OpenAPIBuilder) info(info OpenAPIInfo) &OpenAPIBuilder {
	b.doc.info = info
	return unsafe { b }
}

// title - 设置 API 标题
pub fn (mut b OpenAPIBuilder) title(title string) &OpenAPIBuilder {
	b.doc.info.title = title
	return unsafe { b }
}

// version - 设置 API 版本
pub fn (mut b OpenAPIBuilder) version(version string) &OpenAPIBuilder {
	b.doc.info.version = version
	return unsafe { b }
}

// description - 设置 API 描述
pub fn (mut b OpenAPIBuilder) description(desc string) &OpenAPIBuilder {
	b.doc.info.description = desc
	return unsafe { b }
}

// terms_of_service - 设置服务条款 URL
pub fn (mut b OpenAPIBuilder) terms_of_service(url string) &OpenAPIBuilder {
	b.doc.info.terms_of_service = url
	return unsafe { b }
}

// contact - 设置联系信息
pub fn (mut b OpenAPIBuilder) contact(contact OpenAPIContact) &OpenAPIBuilder {
	b.doc.info.contact = contact
	return unsafe { b }
}

// license - 设置许可证信息
pub fn (mut b OpenAPIBuilder) license(license OpenAPILicense) &OpenAPIBuilder {
	b.doc.info.license = license
	return unsafe { b }
}

// server - 添加服务器信息
pub fn (mut b OpenAPIBuilder) server(url string, description string) &OpenAPIBuilder {
	b.doc.servers << OpenAPIServer{
		url: url
		description: description
	}
	return unsafe { b }
}

// tag - 添加标签
pub fn (mut b OpenAPIBuilder) tag(name string, description string) &OpenAPIBuilder {
	b.doc.tags << OpenAPITag{
		name: name
		description: description
	}
	return unsafe { b }
}

// external_docs - 设置外部文档
pub fn (mut b OpenAPIBuilder) external_docs(url string, description string) &OpenAPIBuilder {
	b.doc.external_docs = OpenAPIExternalDocs{
		url: url
		description: description
	}
	return unsafe { b }
}

// add_schema - 添加可重用的 Schema 到 components
pub fn (mut b OpenAPIBuilder) add_schema(name string, schema OpenAPISchema) &OpenAPIBuilder {
	b.doc.components.schemas[name] = schema
	return unsafe { b }
}

// add_response - 添加可重用的 Response 到 components
pub fn (mut b OpenAPIBuilder) add_response(name string, response OpenAPIResponse) &OpenAPIBuilder {
	b.doc.components.responses[name] = response
	return unsafe { b }
}

// add_parameter - 添加可重用的 Parameter 到 components
pub fn (mut b OpenAPIBuilder) add_parameter(name string, param OpenAPIParameter) &OpenAPIBuilder {
	b.doc.components.parameters[name] = param
	return unsafe { b }
}

// add_security_scheme - 添加安全方案到 components
pub fn (mut b OpenAPIBuilder) add_security_scheme(name string, scheme OpenAPISecurityScheme) &OpenAPIBuilder {
	b.doc.components.security_schemes[name] = scheme
	return unsafe { b }
}

// security - 添加全局安全要求
pub fn (mut b OpenAPIBuilder) security(requirements map[string][]string) &OpenAPIBuilder {
	b.doc.security << requirements
	return unsafe { b }
}


// ============================================================================
// OpenAPIPathBuilder - 路径构建器 (Task 5.2)
// ============================================================================

// OpenAPIPathBuilder - 路径构建器
// 用于为特定路径添加 HTTP 方法操作
pub struct OpenAPIPathBuilder {
mut:
	parent    &OpenAPIBuilder = unsafe { nil }
	path      string
	path_item OpenAPIPathItem
}

// path - 开始构建路径，返回 OpenAPIPathBuilder
pub fn (mut b OpenAPIBuilder) path(path string) OpenAPIPathBuilder {
	// 如果路径已存在，获取现有的 path_item
	existing := b.doc.paths[path] or { OpenAPIPathItem{} }
	return OpenAPIPathBuilder{
		parent: unsafe { b }
		path: path
		path_item: existing
	}
}

// summary - 设置路径摘要
pub fn (mut pb OpenAPIPathBuilder) summary(summary string) &OpenAPIPathBuilder {
	pb.path_item.summary = summary
	return unsafe { pb }
}

// path_description - 设置路径描述
pub fn (mut pb OpenAPIPathBuilder) path_description(description string) &OpenAPIPathBuilder {
	pb.path_item.description = description
	return unsafe { pb }
}

// parameters - 设置路径级别的参数
pub fn (mut pb OpenAPIPathBuilder) parameters(params []OpenAPIParameter) &OpenAPIPathBuilder {
	pb.path_item.parameters = params
	return unsafe { pb }
}

// get - 添加 GET 操作
pub fn (mut pb OpenAPIPathBuilder) get(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.get = op
	return unsafe { pb }
}

// post - 添加 POST 操作
pub fn (mut pb OpenAPIPathBuilder) post(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.post = op
	return unsafe { pb }
}

// put - 添加 PUT 操作
pub fn (mut pb OpenAPIPathBuilder) put(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.put = op
	return unsafe { pb }
}

// delete - 添加 DELETE 操作
pub fn (mut pb OpenAPIPathBuilder) delete(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.delete = op
	return unsafe { pb }
}

// patch - 添加 PATCH 操作
pub fn (mut pb OpenAPIPathBuilder) patch(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.patch = op
	return unsafe { pb }
}

// head - 添加 HEAD 操作
pub fn (mut pb OpenAPIPathBuilder) head(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.head = op
	return unsafe { pb }
}

// options - 添加 OPTIONS 操作
pub fn (mut pb OpenAPIPathBuilder) options(op OpenAPIOperation) &OpenAPIPathBuilder {
	pb.path_item.options = op
	return unsafe { pb }
}

// done - 完成路径构建，返回父构建器
pub fn (mut pb OpenAPIPathBuilder) done() &OpenAPIBuilder {
	if pb.parent != unsafe { nil } {
		pb.parent.doc.paths[pb.path] = pb.path_item
	}
	return unsafe { pb.parent }
}


// ============================================================================
// OpenAPIBuilder build 方法 (Task 5.3)
// ============================================================================

// build - 构建并验证 OpenAPI 文档
// 调用 validate() 验证文档，如果验证失败则返回错误
pub fn (b OpenAPIBuilder) build() !OpenAPIDocument {
	// 验证文档
	b.doc.validate()!
	return b.doc
}

// build_unchecked - 构建 OpenAPI 文档（不验证）
// 用于需要跳过验证的场景
pub fn (b OpenAPIBuilder) build_unchecked() OpenAPIDocument {
	return b.doc
}

// validate - 验证当前构建的文档
pub fn (b OpenAPIBuilder) validate() ! {
	return b.doc.validate()
}

// get_document - 获取当前构建的文档（不验证）
pub fn (b OpenAPIBuilder) get_document() OpenAPIDocument {
	return b.doc
}


// ============================================================================
// 路由信息提取 (Task 8)
// ============================================================================

// RouteInfo - 路由信息结构体
// 包含路由的路径、HTTP 方法、路径参数和处理器信息
// 用于自动生成 OpenAPI 文档
pub struct RouteInfo {
pub:
	path        string    // 路由路径，如 "/users/:id"
	method      string    // HTTP 方法，如 "GET", "POST"
	path_params []string  // 路径参数列表，如 ["id"]
	handler     IHandler  // 路由处理器
}

// extract_path_params - 从路径中提取路径参数
// 支持 :param 格式的路径参数
// 例如: "/users/:id/posts/:postId" -> ["id", "postId"]
fn extract_path_params(path string) []string {
	mut params := []string{}
	segments := path.split('/')
	for segment in segments {
		if segment.starts_with(':') && segment.len > 1 {
			// 提取参数名（去掉冒号）
			param_name := segment[1..]
			params << param_name
		}
	}
	return params
}

// get_routes - 获取应用的所有路由信息
// 遍历所有注册的路由，包含子应用的路由
// 提取路径参数
// 返回 RouteInfo 数组
pub fn (app Hono) get_routes() []RouteInfo {
	mut routes := []RouteInfo{}
	
	// 从 context_router 获取所有路由
	// GET 路由
	for handler in app.context_router.handlers.get {
		routes << RouteInfo{
			path: handler.path
			method: 'GET'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// POST 路由
	for handler in app.context_router.handlers.post {
		routes << RouteInfo{
			path: handler.path
			method: 'POST'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// PUT 路由
	for handler in app.context_router.handlers.put {
		routes << RouteInfo{
			path: handler.path
			method: 'PUT'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// DELETE 路由
	for handler in app.context_router.handlers.delete {
		routes << RouteInfo{
			path: handler.path
			method: 'DELETE'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// PATCH 路由
	for handler in app.context_router.handlers.patch {
		routes << RouteInfo{
			path: handler.path
			method: 'PATCH'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// HEAD 路由
	for handler in app.context_router.handlers.head {
		routes << RouteInfo{
			path: handler.path
			method: 'HEAD'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// OPTIONS 路由
	for handler in app.context_router.handlers.options {
		routes << RouteInfo{
			path: handler.path
			method: 'OPTIONS'
			path_params: extract_path_params(handler.path)
			handler: handler
		}
	}
	
	// 从子应用获取路由（已经在 route() 方法中合并到主应用）
	// 子应用的路由已经通过 merge_routes_for_method 添加到 context_router 中
	// 所以上面的遍历已经包含了子应用的路由
	
	return routes
}

// generate_openapi_paths - 从路由信息生成 OpenAPI paths
// 将 RouteInfo 数组转换为 OpenAPI PathItem 映射
pub fn generate_openapi_paths(routes []RouteInfo) map[string]OpenAPIPathItem {
	mut paths := map[string]OpenAPIPathItem{}
	
	for route in routes {
		// 将 :param 格式转换为 {param} 格式（OpenAPI 标准）
		openapi_path := convert_path_to_openapi_format(route.path)
		
		// 获取或创建 PathItem
		mut path_item := paths[openapi_path] or { OpenAPIPathItem{} }
		
		// 创建基本的 Operation
		mut operation := OpenAPIOperation{
			responses: {
				'200': OpenAPIResponse{
					description: 'Successful response'
				}
			}
		}
		
		// 添加路径参数
		for param_name in route.path_params {
			operation.parameters << OpenAPIParameter{
				name: param_name
				in_location: 'path'
				required: true
				schema: OpenAPISchema{
					schema_type: 'string'
				}
			}
		}
		
		// 根据 HTTP 方法设置操作
		match route.method {
			'GET' { path_item.get = operation }
			'POST' { path_item.post = operation }
			'PUT' { path_item.put = operation }
			'DELETE' { path_item.delete = operation }
			'PATCH' { path_item.patch = operation }
			'HEAD' { path_item.head = operation }
			'OPTIONS' { path_item.options = operation }
			else {}
		}
		
		paths[openapi_path] = path_item
	}
	
	return paths
}

// convert_path_to_openapi_format - 将 v-hono 路径格式转换为 OpenAPI 格式
// 将 :param 转换为 {param}
// 例如: "/users/:id" -> "/users/{id}"
fn convert_path_to_openapi_format(path string) string {
	mut result := path
	segments := path.split('/')
	for segment in segments {
		if segment.starts_with(':') && segment.len > 1 {
			param_name := segment[1..]
			result = result.replace(':${param_name}', '{${param_name}}')
		}
	}
	return result
}
