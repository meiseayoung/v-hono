// test_openapi_structures.v - 测试 OpenAPI 数据结构
import meiseayoung.hono

// OpenAPI 数据结构测试
// 测试 OpenAPI 3.0/3.1 规范的数据结构定义

struct TestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats TestStats) run_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🧪 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats TestStats) print_summary() {
	println('\n=== OpenAPI 数据结构测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个测试失败')
	}
}

// 测试 1: OpenAPIContact 结构体
fn test_openapi_contact() bool {
	contact := hono.OpenAPIContact{
		name: 'API Support'
		url: 'https://example.com/support'
		email: 'support@example.com'
	}
	return contact.name == 'API Support' && 
		contact.url == 'https://example.com/support' && 
		contact.email == 'support@example.com'
}

// 测试 2: OpenAPILicense 结构体
fn test_openapi_license() bool {
	license := hono.OpenAPILicense{
		name: 'MIT'
		url: 'https://opensource.org/licenses/MIT'
	}
	return license.name == 'MIT' && 
		license.url == 'https://opensource.org/licenses/MIT'
}

// 测试 3: OpenAPIInfo 结构体
fn test_openapi_info() bool {
	info := hono.OpenAPIInfo{
		title: 'My API'
		version: '1.0.0'
		description: 'A sample API'
		terms_of_service: 'https://example.com/tos'
		contact: hono.OpenAPIContact{
			name: 'Support'
		}
		license: hono.OpenAPILicense{
			name: 'MIT'
		}
	}
	return info.title == 'My API' && 
		info.version == '1.0.0' && 
		info.description == 'A sample API'
}

// 测试 4: OpenAPIServer 结构体
fn test_openapi_server() bool {
	server := hono.OpenAPIServer{
		url: 'https://api.example.com'
		description: 'Production server'
	}
	return server.url == 'https://api.example.com' && 
		server.description == 'Production server'
}

// 测试 5: OpenAPITag 结构体
fn test_openapi_tag() bool {
	tag := hono.OpenAPITag{
		name: 'users'
		description: 'User operations'
		external_docs: hono.OpenAPIExternalDocs{
			url: 'https://docs.example.com/users'
			description: 'User documentation'
		}
	}
	return tag.name == 'users' && 
		tag.description == 'User operations'
}

// 测试 6: OpenAPIParameter 结构体
fn test_openapi_parameter() bool {
	param := hono.OpenAPIParameter{
		name: 'id'
		in_location: 'path'
		description: 'User ID'
		required: true
		deprecated: false
		schema: hono.OpenAPISchema{
			schema_type: 'integer'
			format: 'int64'
		}
	}
	return param.name == 'id' && 
		param.in_location == 'path' && 
		param.required == true
}

// 测试 7: OpenAPIResponse 结构体
fn test_openapi_response() bool {
	response := hono.OpenAPIResponse{
		description: 'Successful response'
		content: {
			'application/json': hono.OpenAPIMediaType{
				schema: hono.OpenAPISchema{
					schema_type: 'object'
				}
			}
		}
	}
	return response.description == 'Successful response' && 
		'application/json' in response.content
}

// 测试 8: OpenAPIOperation 结构体
fn test_openapi_operation() bool {
	op := hono.OpenAPIOperation{
		summary: 'Get user'
		description: 'Get user by ID'
		operation_id: 'getUser'
		tags: ['users']
		responses: {
			'200': hono.OpenAPIResponse{
				description: 'Success'
			}
		}
	}
	return op.summary == 'Get user' && 
		op.operation_id == 'getUser' && 
		'users' in op.tags
}

// 测试 9: OpenAPIPathItem 结构体
fn test_openapi_path_item() bool {
	path_item := hono.OpenAPIPathItem{
		summary: 'User operations'
		get: hono.OpenAPIOperation{
			summary: 'Get user'
			responses: {
				'200': hono.OpenAPIResponse{
					description: 'Success'
				}
			}
		}
		post: hono.OpenAPIOperation{
			summary: 'Create user'
			responses: {
				'201': hono.OpenAPIResponse{
					description: 'Created'
				}
			}
		}
	}
	return path_item.summary == 'User operations' && 
		path_item.get.summary == 'Get user' && 
		path_item.post.summary == 'Create user'
}

// 测试 10: OpenAPISchema 结构体
fn test_openapi_schema() bool {
	schema := hono.OpenAPISchema{
		schema_type: 'object'
		title: 'User'
		description: 'User object'
		required: ['id', 'name']
		properties: {
			'id': hono.OpenAPISchema{
				schema_type: 'integer'
				format: 'int64'
			}
			'name': hono.OpenAPISchema{
				schema_type: 'string'
			}
		}
	}
	return schema.schema_type == 'object' && 
		schema.title == 'User' && 
		'id' in schema.required && 
		'name' in schema.properties
}

// 测试 11: OpenAPISecurityScheme 结构体
fn test_openapi_security_scheme() bool {
	scheme := hono.OpenAPISecurityScheme{
		scheme_type: 'http'
		description: 'Bearer token authentication'
		scheme: 'bearer'
		bearer_format: 'JWT'
	}
	return scheme.scheme_type == 'http' && 
		scheme.scheme == 'bearer' && 
		scheme.bearer_format == 'JWT'
}

// 测试 12: OpenAPIComponents 结构体
fn test_openapi_components() bool {
	components := hono.OpenAPIComponents{
		schemas: {
			'User': hono.OpenAPISchema{
				schema_type: 'object'
			}
		}
		security_schemes: {
			'bearerAuth': hono.OpenAPISecurityScheme{
				scheme_type: 'http'
				scheme: 'bearer'
			}
		}
	}
	return 'User' in components.schemas && 
		'bearerAuth' in components.security_schemes
}

// 测试 13: OpenAPIDocument 结构体
fn test_openapi_document() bool {
	doc := hono.OpenAPIDocument{
		openapi: '3.0.0'
		info: hono.OpenAPIInfo{
			title: 'My API'
			version: '1.0.0'
		}
		servers: [
			hono.OpenAPIServer{
				url: 'https://api.example.com'
			}
		]
		paths: {
			'/users': hono.OpenAPIPathItem{
				get: hono.OpenAPIOperation{
					summary: 'List users'
					responses: {
						'200': hono.OpenAPIResponse{
							description: 'Success'
						}
					}
				}
			}
		}
		tags: [
			hono.OpenAPITag{
				name: 'users'
			}
		]
	}
	return doc.openapi == '3.0.0' && 
		doc.info.title == 'My API' && 
		'/users' in doc.paths
}

// 测试 14: 参数位置支持 (path, query, header, cookie)
fn test_parameter_locations() bool {
	locations := ['path', 'query', 'header', 'cookie']
	for loc in locations {
		param := hono.OpenAPIParameter{
			name: 'test'
			in_location: loc
		}
		if param.in_location != loc {
			return false
		}
	}
	return true
}

// 测试 15: HTTP 方法支持
fn test_http_methods() bool {
	path_item := hono.OpenAPIPathItem{
		get: hono.OpenAPIOperation{
			summary: 'GET'
			responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
		}
		post: hono.OpenAPIOperation{
			summary: 'POST'
			responses: {'201': hono.OpenAPIResponse{description: 'Created'}}
		}
		put: hono.OpenAPIOperation{
			summary: 'PUT'
			responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
		}
		delete: hono.OpenAPIOperation{
			summary: 'DELETE'
			responses: {'204': hono.OpenAPIResponse{description: 'No Content'}}
		}
		patch: hono.OpenAPIOperation{
			summary: 'PATCH'
			responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
		}
		head: hono.OpenAPIOperation{
			summary: 'HEAD'
			responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
		}
		options: hono.OpenAPIOperation{
			summary: 'OPTIONS'
			responses: {'200': hono.OpenAPIResponse{description: 'OK'}}
		}
	}
	return path_item.get.summary == 'GET' && 
		path_item.post.summary == 'POST' && 
		path_item.put.summary == 'PUT' && 
		path_item.delete.summary == 'DELETE' && 
		path_item.patch.summary == 'PATCH' && 
		path_item.head.summary == 'HEAD' && 
		path_item.options.summary == 'OPTIONS'
}

fn main() {
	println('🚀 开始 OpenAPI 数据结构测试...\n')

	mut stats := TestStats{}

	// 运行所有测试
	stats.run_test('OpenAPIContact 结构体', test_openapi_contact)
	stats.run_test('OpenAPILicense 结构体', test_openapi_license)
	stats.run_test('OpenAPIInfo 结构体', test_openapi_info)
	stats.run_test('OpenAPIServer 结构体', test_openapi_server)
	stats.run_test('OpenAPITag 结构体', test_openapi_tag)
	stats.run_test('OpenAPIParameter 结构体', test_openapi_parameter)
	stats.run_test('OpenAPIResponse 结构体', test_openapi_response)
	stats.run_test('OpenAPIOperation 结构体', test_openapi_operation)
	stats.run_test('OpenAPIPathItem 结构体', test_openapi_path_item)
	stats.run_test('OpenAPISchema 结构体', test_openapi_schema)
	stats.run_test('OpenAPISecurityScheme 结构体', test_openapi_security_scheme)
	stats.run_test('OpenAPIComponents 结构体', test_openapi_components)
	stats.run_test('OpenAPIDocument 结构体', test_openapi_document)
	stats.run_test('参数位置支持', test_parameter_locations)
	stats.run_test('HTTP 方法支持', test_http_methods)

	// 打印测试总结
	stats.print_summary()
}
