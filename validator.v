module hono

import net.http
import x.json2
import regex

// ValidationTarget 枚举 - 验证目标类型
pub enum ValidationTarget {
	json    // JSON body
	query   // Query parameters
	param   // Path parameters
	header  // Request headers
	form    // Form data
}

// Schema 联合类型 - 支持多种 Schema 类型
pub type Schema = StringSchema | IntSchema | FloatSchema | BoolSchema | ArraySchema | ObjectSchema

// StringSchema 结构体 - 字符串验证规则
pub struct StringSchema {
pub:
	required    bool
	min_length  int
	max_length  int
	pattern     string
	enum_values []string
	default_val string
}

// IntSchema 结构体 - 整数验证规则
pub struct IntSchema {
pub:
	required    bool
	min         ?int
	max         ?int
	enum_values []int
	default_val int
}

// FloatSchema 结构体 - 浮点数验证规则
pub struct FloatSchema {
pub:
	required    bool
	min         ?f64
	max         ?f64
	default_val f64
}

// BoolSchema 结构体 - 布尔验证规则
pub struct BoolSchema {
pub:
	required    bool
	default_val bool
}


// ArraySchema 结构体 - 数组验证规则
pub struct ArraySchema {
pub:
	required  bool
	min_items int
	max_items int
	items     &Schema = unsafe { nil }
}

// ObjectSchema 结构体 - 对象验证规则
pub struct ObjectSchema {
pub:
	required   bool
	properties map[string]Schema
}

// ValidationResult 结构体 - 验证结果
pub struct ValidationResult {
pub:
	success bool
	errors  []ValidationError
	data    map[string]json2.Any
}

// ValidationError 结构体 - 验证错误
pub struct ValidationError {
pub:
	field   string
	message string
	code    string
}

// ValidatorOptions 结构体 - 验证器配置选项
pub struct ValidatorOptions {
pub:
	on_error ?fn ([]ValidationError, mut Context) http.Response
}


// ============================================================================
// Schema Builder API - 工厂函数
// ============================================================================

// v_string - 创建字符串 Schema
pub fn v_string() StringSchema {
	return StringSchema{}
}

// v_int - 创建整数 Schema
pub fn v_int() IntSchema {
	return IntSchema{}
}

// v_float - 创建浮点数 Schema
pub fn v_float() FloatSchema {
	return FloatSchema{}
}

// v_bool - 创建布尔 Schema
pub fn v_bool() BoolSchema {
	return BoolSchema{}
}

// v_array - 创建数组 Schema
pub fn v_array(items Schema) ArraySchema {
	// 直接存储 Schema 的副本
	return ArraySchema{
		items: &items
	}
}

// v_object - 创建对象 Schema
pub fn v_object(properties map[string]Schema) ObjectSchema {
	return ObjectSchema{
		properties: properties
	}
}

// ============================================================================
// StringSchema 链式方法
// ============================================================================

// required - 设置为必需字段
pub fn (s StringSchema) required() StringSchema {
	return StringSchema{
		...s
		required: true
	}
}

// min - 设置最小长度
pub fn (s StringSchema) min(len int) StringSchema {
	return StringSchema{
		...s
		min_length: len
	}
}

// max - 设置最大长度
pub fn (s StringSchema) max(len int) StringSchema {
	return StringSchema{
		...s
		max_length: len
	}
}

// pattern - 设置正则表达式模式
pub fn (s StringSchema) pattern(regex_pattern string) StringSchema {
	return StringSchema{
		...s
		pattern: regex_pattern
	}
}

// enum_of - 设置枚举值
pub fn (s StringSchema) enum_of(values []string) StringSchema {
	return StringSchema{
		...s
		enum_values: values
	}
}

// default_value - 设置默认值
pub fn (s StringSchema) default_value(val string) StringSchema {
	return StringSchema{
		...s
		default_val: val
	}
}


// ============================================================================
// IntSchema 链式方法
// ============================================================================

// required - 设置为必需字段
pub fn (s IntSchema) required() IntSchema {
	return IntSchema{
		...s
		required: true
	}
}

// min - 设置最小值
pub fn (s IntSchema) min(val int) IntSchema {
	return IntSchema{
		...s
		min: val
	}
}

// max - 设置最大值
pub fn (s IntSchema) max(val int) IntSchema {
	return IntSchema{
		...s
		max: val
	}
}

// enum_of - 设置枚举值
pub fn (s IntSchema) enum_of(values []int) IntSchema {
	return IntSchema{
		...s
		enum_values: values
	}
}

// default_value - 设置默认值
pub fn (s IntSchema) default_value(val int) IntSchema {
	return IntSchema{
		...s
		default_val: val
	}
}

// ============================================================================
// FloatSchema 链式方法
// ============================================================================

// required - 设置为必需字段
pub fn (s FloatSchema) required() FloatSchema {
	return FloatSchema{
		...s
		required: true
	}
}

// min - 设置最小值
pub fn (s FloatSchema) min(val f64) FloatSchema {
	return FloatSchema{
		...s
		min: val
	}
}

// max - 设置最大值
pub fn (s FloatSchema) max(val f64) FloatSchema {
	return FloatSchema{
		...s
		max: val
	}
}

// default_value - 设置默认值
pub fn (s FloatSchema) default_value(val f64) FloatSchema {
	return FloatSchema{
		...s
		default_val: val
	}
}

// ============================================================================
// BoolSchema 链式方法
// ============================================================================

// required - 设置为必需字段
pub fn (s BoolSchema) required() BoolSchema {
	return BoolSchema{
		...s
		required: true
	}
}

// default_value - 设置默认值
pub fn (s BoolSchema) default_value(val bool) BoolSchema {
	return BoolSchema{
		...s
		default_val: val
	}
}


// ============================================================================
// ArraySchema 链式方法
// ============================================================================

// required - 设置为必需字段
pub fn (s ArraySchema) required() ArraySchema {
	return ArraySchema{
		...s
		required: true
	}
}

// min_items_count - 设置最小元素数量
pub fn (s ArraySchema) min_items_count(count int) ArraySchema {
	return ArraySchema{
		...s
		min_items: count
	}
}

// max_items_count - 设置最大元素数量
pub fn (s ArraySchema) max_items_count(count int) ArraySchema {
	return ArraySchema{
		...s
		max_items: count
	}
}

// ============================================================================
// ObjectSchema 链式方法
// ============================================================================

// required - 设置为必需字段
pub fn (s ObjectSchema) required() ObjectSchema {
	return ObjectSchema{
		...s
		required: true
	}
}


// ============================================================================
// 验证逻辑实现
// ============================================================================

// validate_value - 验证单个值
fn validate_value(field_name string, value json2.Any, schema Schema) []ValidationError {
	mut errors := []ValidationError{}
	
	match schema {
		StringSchema {
			errors << validate_string(field_name, value, schema)
		}
		IntSchema {
			errors << validate_int(field_name, value, schema)
		}
		FloatSchema {
			errors << validate_float(field_name, value, schema)
		}
		BoolSchema {
			errors << validate_bool(field_name, value, schema)
		}
		ArraySchema {
			errors << validate_array(field_name, value, schema)
		}
		ObjectSchema {
			errors << validate_object(field_name, value, schema)
		}
	}
	
	return errors
}

// validate_string - 验证字符串值
fn validate_string(field_name string, value json2.Any, schema StringSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// 检查值是否为 null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// 获取字符串值
	str_val := value.str()
	
	// 检查空字符串
	if str_val.len == 0 && schema.required {
		errors << ValidationError{
			field: field_name
			message: 'Field is required'
			code: 'required'
		}
		return errors
	}
	
	// 检查最小长度
	if schema.min_length > 0 && str_val.len < schema.min_length {
		errors << ValidationError{
			field: field_name
			message: 'String length must be at least ${schema.min_length}'
			code: 'min_length'
		}
	}
	
	// 检查最大长度
	if schema.max_length > 0 && str_val.len > schema.max_length {
		errors << ValidationError{
			field: field_name
			message: 'String length must be at most ${schema.max_length}'
			code: 'max_length'
		}
	}
	
	// 检查正则表达式模式
	if schema.pattern.len > 0 {
		mut re := regex.regex_opt(schema.pattern) or {
			errors << ValidationError{
				field: field_name
				message: 'Invalid pattern: ${schema.pattern}'
				code: 'invalid_pattern'
			}
			return errors
		}
		
		if !re.matches_string(str_val) {
			errors << ValidationError{
				field: field_name
				message: 'Value does not match pattern: ${schema.pattern}'
				code: 'pattern'
			}
		}
	}
	
	// 检查枚举值
	if schema.enum_values.len > 0 {
		if str_val !in schema.enum_values {
			errors << ValidationError{
				field: field_name
				message: 'Value must be one of: ${schema.enum_values.join(", ")}'
				code: 'enum'
			}
		}
	}
	
	return errors
}


// validate_int - 验证整数值
fn validate_int(field_name string, value json2.Any, schema IntSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// 检查值是否为 null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// 尝试转换为整数
	int_val := value.int()
	
	// 检查最小值
	if min := schema.min {
		if int_val < min {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at least ${min}'
				code: 'min'
			}
		}
	}
	
	// 检查最大值
	if max := schema.max {
		if int_val > max {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at most ${max}'
				code: 'max'
			}
		}
	}
	
	// 检查枚举值
	if schema.enum_values.len > 0 {
		if int_val !in schema.enum_values {
			errors << ValidationError{
				field: field_name
				message: 'Value must be one of: ${schema.enum_values}'
				code: 'enum'
			}
		}
	}
	
	return errors
}

// validate_float - 验证浮点数值
fn validate_float(field_name string, value json2.Any, schema FloatSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// 检查值是否为 null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// 尝试转换为浮点数
	float_val := value.f64()
	
	// 检查最小值
	if min := schema.min {
		if float_val < min {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at least ${min}'
				code: 'min'
			}
		}
	}
	
	// 检查最大值
	if max := schema.max {
		if float_val > max {
			errors << ValidationError{
				field: field_name
				message: 'Value must be at most ${max}'
				code: 'max'
			}
		}
	}
	
	return errors
}

// validate_bool - 验证布尔值
fn validate_bool(field_name string, value json2.Any, schema BoolSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// 检查值是否为 null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// 验证是否为布尔类型
	match value {
		bool {
			// 有效的布尔值
		}
		else {
			// 尝试从字符串转换
			str_val := value.str().to_lower()
			if str_val !in ['true', 'false', '1', '0'] {
				errors << ValidationError{
					field: field_name
					message: 'Value must be a boolean'
					code: 'type'
				}
			}
		}
	}
	
	return errors
}


// validate_array - 验证数组值
fn validate_array(field_name string, value json2.Any, schema ArraySchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// 检查值是否为 null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// 获取数组
	arr := value.arr()
	
	// 检查最小元素数量
	if schema.min_items > 0 && arr.len < schema.min_items {
		errors << ValidationError{
			field: field_name
			message: 'Array must have at least ${schema.min_items} items'
			code: 'min_items'
		}
	}
	
	// 检查最大元素数量
	if schema.max_items > 0 && arr.len > schema.max_items {
		errors << ValidationError{
			field: field_name
			message: 'Array must have at most ${schema.max_items} items'
			code: 'max_items'
		}
	}
	
	// 验证数组元素
	if schema.items != unsafe { nil } {
		for i, item in arr {
			item_errors := validate_value('${field_name}[${i}]', item, *schema.items)
			errors << item_errors
		}
	}
	
	return errors
}

// validate_object - 验证对象值（递归验证嵌套属性）
fn validate_object(field_name string, value json2.Any, schema ObjectSchema) []ValidationError {
	mut errors := []ValidationError{}
	
	// 检查值是否为 null
	if value is json2.Null {
		if schema.required {
			errors << ValidationError{
				field: field_name
				message: 'Field is required'
				code: 'required'
			}
		}
		return errors
	}
	
	// 获取对象
	obj := value.as_map()
	
	// 验证每个属性
	for prop_name, prop_schema in schema.properties {
		full_field_name := if field_name.len > 0 { '${field_name}.${prop_name}' } else { prop_name }
		
		if prop_name in obj {
			prop_value := obj[prop_name] or { json2.Null{} }
			prop_errors := validate_value(full_field_name, prop_value, prop_schema)
			errors << prop_errors
		} else {
			// 字段不存在，检查是否必需
			is_required := match prop_schema {
				StringSchema { prop_schema.required }
				IntSchema { prop_schema.required }
				FloatSchema { prop_schema.required }
				BoolSchema { prop_schema.required }
				ArraySchema { prop_schema.required }
				ObjectSchema { prop_schema.required }
			}
			
			if is_required {
				errors << ValidationError{
					field: full_field_name
					message: 'Field is required'
					code: 'required'
				}
			}
		}
	}
	
	return errors
}

// validate_schema - 验证数据是否符合 ObjectSchema
pub fn validate_schema(data map[string]json2.Any, schema ObjectSchema) ValidationResult {
	mut errors := []ValidationError{}
	
	// 验证每个属性
	for prop_name, prop_schema in schema.properties {
		if prop_name in data {
			prop_value := data[prop_name] or { json2.Null{} }
			prop_errors := validate_value(prop_name, prop_value, prop_schema)
			errors << prop_errors
		} else {
			// 字段不存在，检查是否必需
			is_required := match prop_schema {
				StringSchema { prop_schema.required }
				IntSchema { prop_schema.required }
				FloatSchema { prop_schema.required }
				BoolSchema { prop_schema.required }
				ArraySchema { prop_schema.required }
				ObjectSchema { prop_schema.required }
			}
			
			if is_required {
				errors << ValidationError{
					field: prop_name
					message: 'Field is required'
					code: 'required'
				}
			}
		}
	}
	
	return ValidationResult{
		success: errors.len == 0
		errors: errors
		data: data
	}
}


// ============================================================================
// 验证中间件实现
// ============================================================================

// validator - 验证中间件工厂函数
// 返回一个 ContextMiddleware，用于验证请求数据
pub fn validator(target ValidationTarget, schema ObjectSchema, options ...ValidatorOptions) ContextMiddleware {
	opts := if options.len > 0 { options[0] } else { ValidatorOptions{} }
	
	return fn [target, schema, opts] (mut c Context, next fn (mut Context) http.Response) http.Response {
		// 根据目标类型获取数据
		data := get_validation_data(c, target) or {
			// 解析错误
			errors := [ValidationError{
				field: ''
				message: err.msg()
				code: 'parse_error'
			}]
			
			// 使用自定义错误处理器或默认响应
			if on_error := opts.on_error {
				return on_error(errors, mut c)
			}
			
			c.status(400)
			return c.json(build_error_response(errors))
		}
		
		// 验证数据
		result := validate_schema(data, schema)
		
		if !result.success {
			// 使用自定义错误处理器或默认响应
			if on_error := opts.on_error {
				return on_error(result.errors, mut c)
			}
			
			c.status(400)
			return c.json(build_error_response(result.errors))
		}
		
		// 将验证后的数据存储到 Context
		store_validated_data(mut c, result.data)
		
		// 继续处理请求
		return next(mut c)
	}
}

// get_validation_data - 根据目标类型获取要验证的数据
fn get_validation_data(c Context, target ValidationTarget) !map[string]json2.Any {
	match target {
		.json {
			return parse_json_body(c)
		}
		.query {
			return parse_query_params(c)
		}
		.param {
			return parse_path_params(c)
		}
		.header {
			return parse_headers(c)
		}
		.form {
			return parse_form_data(c)
		}
	}
}

// parse_json_body - 解析 JSON 请求体
fn parse_json_body(c Context) !map[string]json2.Any {
	if c.body.len == 0 {
		return map[string]json2.Any{}
	}
	
	raw := json2.decode[json2.Any](c.body) or {
		return error('Invalid JSON: ${err}')
	}
	
	return raw.as_map()
}

// parse_query_params - 解析查询参数
fn parse_query_params(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	for key, value in c.query {
		data[key] = json2.Any(value)
	}
	
	return data
}

// parse_path_params - 解析路径参数
fn parse_path_params(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	for key, value in c.params {
		data[key] = json2.Any(value)
	}
	
	return data
}

// parse_headers - 解析请求头
fn parse_headers(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	// 获取常用请求头
	common_headers := ['Content-Type', 'Accept', 'Authorization', 'X-Request-ID', 
		'X-Forwarded-For', 'User-Agent', 'Host', 'Origin', 'Referer']
	
	for header_name in common_headers {
		if header_value := c.req.header.get_custom(header_name) {
			data[header_name] = json2.Any(header_value)
		}
	}
	
	return data
}

// parse_form_data - 解析表单数据
fn parse_form_data(c Context) !map[string]json2.Any {
	mut data := map[string]json2.Any{}
	
	if c.body.len == 0 {
		return data
	}
	
	// 解析 application/x-www-form-urlencoded 格式
	pairs := c.body.split('&')
	for pair in pairs {
		eq_pos := pair.index('=') or { continue }
		if eq_pos == 0 {
			continue
		}
		
		key := pair[..eq_pos]
		value := if eq_pos + 1 < pair.len { pair[eq_pos + 1..] } else { '' }
		
		// URL 解码
		decoded_key := url_decode(key)
		decoded_value := url_decode(value)
		
		data[decoded_key] = json2.Any(decoded_value)
	}
	
	return data
}


// url_decode - URL 解码
fn url_decode(s string) string {
	mut result := []u8{}
	mut i := 0
	
	for i < s.len {
		if s[i] == `%` && i + 2 < s.len {
			// 尝试解码十六进制
			hex_str := s[i + 1..i + 3]
			if hex_val := hex_to_byte(hex_str) {
				result << hex_val
				i += 3
				continue
			}
		} else if s[i] == `+` {
			result << ` `
			i++
			continue
		}
		
		result << s[i]
		i++
	}
	
	return result.bytestr()
}

// hex_to_byte - 将两位十六进制字符串转换为字节
fn hex_to_byte(hex string) ?u8 {
	if hex.len != 2 {
		return none
	}
	
	high := hex_char_to_val(hex[0]) or { return none }
	low := hex_char_to_val(hex[1]) or { return none }
	
	return u8(high * 16 + low)
}

// hex_char_to_val - 将十六进制字符转换为数值
fn hex_char_to_val(c u8) ?int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a` + 10)
	}
	if c >= `A` && c <= `F` {
		return int(c - `A` + 10)
	}
	return none
}

// store_validated_data - 将验证后的数据存储到 Context
fn store_validated_data(mut c Context, data map[string]json2.Any) {
	// 将数据序列化为 JSON 字符串存储
	mut json_parts := []string{}
	for key, value in data {
		json_parts << '"${key}":${value.json_str()}'
	}
	json_str := '{${json_parts.join(",")}}'
	c.set('validated_data', json_str)
	
	// 同时存储各个字段的字符串值（便于快速访问）
	for key, value in data {
		c.set('validated_${key}', value.str())
	}
}

// build_error_response - 构建错误响应 JSON
fn build_error_response(errors []ValidationError) string {
	mut error_parts := []string{}
	
	for err in errors {
		error_parts << '{"field":"${err.field}","message":"${err.message}","code":"${err.code}"}'
	}
	
	return '{"error":"Bad Request","errors":[${error_parts.join(",")}]}'
}

// get_validated_data - 从 Context 获取验证后的数据
pub fn get_validated_data(c Context) map[string]string {
	mut data := map[string]string{}
	
	// 从 store 中获取所有以 validated_ 开头的键
	for key, value in c.store {
		if key.starts_with('validated_') && key != 'validated_data' {
			field_name := key[10..] // 移除 'validated_' 前缀
			data[field_name] = value
		}
	}
	
	return data
}

// get_validated_json - 从 Context 获取验证后的完整 JSON 数据
pub fn get_validated_json(c Context) ?string {
	return c.get('validated_data')
}

// get_validated_field - 从 Context 获取单个验证后的字段值
pub fn get_validated_field(c Context, field string) ?string {
	return c.get('validated_${field}')
}
