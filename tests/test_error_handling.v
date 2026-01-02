import meiseayoung.hono
import net.http

fn main() {
	println('=== 统一错误处理系统测试 ===')
	
	// 测试1: 错误响应格式一致性
	test_error_response_format()
	
	// 测试2: 错误处理便捷方法
	test_error_convenience_methods()
	
	// 测试3: 参数验证错误处理
	test_parameter_validation_errors()
	
	// 测试4: 资源相关错误处理
	test_resource_errors()
	
	// 测试5: 文件操作错误处理
	test_file_operation_errors()
	
	println('✅ 所有错误处理测试完成')
}

fn test_error_response_format() {
	println('\n📊 测试错误响应格式一致性...')
	
	// 创建模拟Context
	mut ctx := create_mock_context()
	
	// 测试标准错误响应
	response := ctx.bad_request('Test error message')
	
	// 验证响应状态码
	if response.status_code == 400 {
		println('  ✅ 状态码正确: 400')
	} else {
		println('  ❌ 状态码错误: ${response.status_code}')
	}
	
	// 验证响应格式
	if response.body.contains('"error"') && response.body.contains('"message"') {
		println('  ✅ 响应格式包含必要字段')
	} else {
		println('  ❌ 响应格式缺少必要字段')
	}
	
	// 验证Content-Type
	content_type := response.header.get_custom('Content-Type') or { '' }
	if content_type.contains('application/json') {
		println('  ✅ Content-Type正确: ${content_type}')
	} else {
		println('  ❌ Content-Type错误: ${content_type}')
	}
}

fn test_error_convenience_methods() {
	println('\n📊 测试错误处理便捷方法...')
	
	mut ctx := create_mock_context()
	
	// 测试各种错误类型
	error_tests := [
		['bad_request', '400'],
		['unauthorized', '401'],
		['forbidden', '403'],
		['not_found', '404'],
		['internal_error', '500']
	]
	
	mut passed := 0
	for test_data in error_tests {
		test_name := test_data[0]
		expected_code := test_data[1].int()
		
		response := match test_name {
			'bad_request' { ctx.bad_request('Test message') }
			'unauthorized' { ctx.unauthorized('Test message') }
			'forbidden' { ctx.forbidden('Test message') }
			'not_found' { ctx.not_found('Test message') }
			'internal_error' { ctx.internal_error('Test message') }
			else { http.Response{} }
		}
		
		if response.status_code == expected_code {
			println('  ✅ ${test_name}: ${expected_code}')
			passed++
		} else {
			println('  ❌ ${test_name}: 期望${expected_code}, 实际${response.status_code}')
		}
	}
	
	println('  便捷方法测试通过: ${passed}/${error_tests.len}')
}

fn test_parameter_validation_errors() {
	println('\n📊 测试参数验证错误处理...')
	
	mut ctx := create_mock_context()
	
	// 测试缺失参数错误
	response1 := ctx.missing_parameter('user_id')
	if response1.status_code == 400 && response1.body.contains('user_id') {
		println('  ✅ 缺失参数错误处理正确')
	} else {
		println('  ❌ 缺失参数错误处理失败')
	}
	
	// 测试无效参数错误
	response2 := ctx.invalid_parameter('email', 'Invalid email format')
	if response2.status_code == 400 && response2.body.contains('email') {
		println('  ✅ 无效参数错误处理正确')
	} else {
		println('  ❌ 无效参数错误处理失败')
	}
	
	// 测试验证错误
	field_errors := {
		'email': 'Invalid format'
		'age': 'Must be positive'
	}
	response3 := ctx.validation_error('Validation failed', field_errors)
	if response3.status_code == 422 && response3.body.contains('details') {
		println('  ✅ 验证错误处理正确')
	} else {
		println('  ❌ 验证错误处理失败')
	}
}

fn test_resource_errors() {
	println('\n📊 测试资源相关错误处理...')
	
	mut ctx := create_mock_context()
	
	// 测试资源未找到错误
	response1 := ctx.resource_not_found('user', '123')
	if response1.status_code == 404 && response1.body.contains('user') {
		println('  ✅ 资源未找到错误处理正确')
	} else {
		println('  ❌ 资源未找到错误处理失败')
	}
	
	// 测试资源冲突错误
	response2 := ctx.resource_conflict('user', 'Email already exists')
	if response2.status_code == 409 && response2.body.contains('conflict') {
		println('  ✅ 资源冲突错误处理正确')
	} else {
		println('  ❌ 资源冲突错误处理失败')
	}
}

fn test_file_operation_errors() {
	println('\n📊 测试文件操作错误处理...')
	
	mut ctx := create_mock_context()
	
	// 测试文件操作错误
	response1 := ctx.file_operation_error('read', 'test.txt', 'File not found')
	if response1.status_code == 500 && response1.body.contains('File operation failed') {
		println('  ✅ 文件操作错误处理正确')
	} else {
		println('  ❌ 文件操作错误处理失败')
	}
	
	// 测试数据库操作错误
	response2 := ctx.database_error('insert', 'Connection timeout')
	if response2.status_code == 500 && response2.body.contains('Database operation failed') {
		println('  ✅ 数据库操作错误处理正确')
	} else {
		println('  ❌ 数据库操作错误处理失败')
	}
}

// 创建模拟Context用于测试
fn create_mock_context() hono.Context {
	// 创建模拟请求
	req := http.Request{
		method: .get
		url: '/test'
		header: http.new_header()
		data: ''
	}
	
	// 创建Context
	return hono.Context.new(req, map[string]string{}, map[string]string{}, '')
}