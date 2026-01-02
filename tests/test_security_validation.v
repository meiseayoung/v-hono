import meiseayoung.hono

fn main() {
	println('=== 测试输入验证和路径安全 ===')
	
	println('1. 路径安全验证测试')
	
	// 测试安全路径
	safe_paths := [
		'test.txt',
		'images/photo.jpg',
		'docs/readme.md',
		'assets/style.css'
	]
	
	for path in safe_paths {
		result := hono.validate_file_path(path, hono.default_path_validation_options()) or {
			println('   ❌ 安全路径被拒绝: $path - $err')
			continue
		}
		println('   ✅ 安全路径通过: $path -> $result')
	}
	
	// 测试危险路径
	dangerous_paths := [
		'../etc/passwd',
		'..\\windows\\system32',
		'/etc/shadow',
		'C:\\Windows\\System32',
		'test<script>.html',
		'file|pipe.txt',
		'test?.txt',
		'file*.log'
	]
	
	for path in dangerous_paths {
		result := hono.validate_file_path(path, hono.default_path_validation_options()) or {
			println('   ✅ 危险路径被正确拒绝: $path - $err')
			continue
		}
		println('   ❌ 危险路径未被拒绝: $path -> $result')
	}
	
	println('2. 文件哈希验证测试')
	
	// 测试有效哈希
	valid_hashes := [
		'5d41402abc4b2a76b9719d911017c592',  // MD5 of "hello"
		'098f6bcd4621d373cade4e832627b4f6',  // MD5 of "test"
		'e99a18c428cb38d5f260853678922e03'   // MD5 of "abc123"
	]
	
	for hash in valid_hashes {
		result := hono.validate_file_hash(hash) or {
			println('   ❌ 有效哈希被拒绝: $hash - $err')
			continue
		}
		println('   ✅ 有效哈希通过: $hash -> $result')
	}
	
	// 测试无效哈希
	invalid_hashes := [
		'',                                   // 空哈希
		'invalid',                           // 太短
		'5d41402abc4b2a76b9719d911017c592x', // 包含非十六进制字符
		'5d41402abc4b2a76b9719d911017c59',   // 太短
		'5d41402abc4b2a76b9719d911017c5922'  // 太长
	]
	
	for hash in invalid_hashes {
		result := hono.validate_file_hash(hash) or {
			println('   ✅ 无效哈希被正确拒绝: "$hash" - $err')
			continue
		}
		println('   ❌ 无效哈希未被拒绝: "$hash" -> $result')
	}
	
	println('3. 文件名验证测试')
	
	// 测试有效文件名
	valid_filenames := [
		'document.pdf',
		'image_001.jpg',
		'data-file.json',
		'report_2023.xlsx'
	]
	
	for filename in valid_filenames {
		result := hono.validate_filename(filename) or {
			println('   ❌ 有效文件名被拒绝: $filename - $err')
			continue
		}
		println('   ✅ 有效文件名通过: $filename -> $result')
	}
	
	// 测试无效文件名
	invalid_filenames := [
		'',           // 空文件名
		'CON.txt',    // Windows 保留名
		'file<>.txt', // 危险字符
		'file|pipe.txt',
		'test?.doc',
		'a'.repeat(300) // 太长的文件名
	]
	
	for filename in invalid_filenames {
		result := hono.validate_filename(filename) or {
			println('   ✅ 无效文件名被正确拒绝: "$filename" - $err')
			continue
		}
		println('   ❌ 无效文件名未被拒绝: "$filename" -> $result')
	}
	
	println('4. 文件大小验证测试')
	
	max_size := 10 * 1024 * 1024 // 10MB
	
	// 测试有效大小
	valid_sizes := ['1024', '5242880', '10485760'] // 1KB, 5MB, 10MB
	
	for size_str in valid_sizes {
		result := hono.validate_file_size(size_str, max_size) or {
			println('   ❌ 有效大小被拒绝: $size_str - $err')
			continue
		}
		println('   ✅ 有效大小通过: $size_str -> ${result} bytes')
	}
	
	// 测试无效大小
	invalid_sizes := ['', '0', '-1024', '20971520'] // 空, 0, 负数, 20MB(超过限制)
	
	for size_str in invalid_sizes {
		result := hono.validate_file_size(size_str, max_size) or {
			println('   ✅ 无效大小被正确拒绝: "$size_str" - $err')
			continue
		}
		println('   ❌ 无效大小未被拒绝: "$size_str" -> ${result}')
	}
	
	println('5. 分片索引验证测试')
	
	max_chunks := 100
	
	// 测试有效索引
	valid_indices := ['0', '50', '99']
	
	for index_str in valid_indices {
		result := hono.validate_chunk_index(index_str, max_chunks) or {
			println('   ❌ 有效索引被拒绝: $index_str - $err')
			continue
		}
		println('   ✅ 有效索引通过: $index_str -> $result')
	}
	
	// 测试无效索引
	invalid_indices := ['', '-1', '100', 'abc']
	
	for index_str in invalid_indices {
		result := hono.validate_chunk_index(index_str, max_chunks) or {
			println('   ✅ 无效索引被正确拒绝: "$index_str" - $err')
			continue
		}
		println('   ❌ 无效索引未被拒绝: "$index_str" -> $result')
	}
	
	println('6. 安全内容类型检测测试')
	
	test_files := [
		'document.pdf',
		'image.jpg',
		'style.css',
		'script.js',
		'data.json',
		'unknown.xyz'
	]
	
	for file in test_files {
		content_type := hono.get_safe_content_type(file)
		println('   文件: $file -> Content-Type: $content_type')
	}
	
	println('✅ 输入验证和路径安全测试完成！')
	println('   优化效果：')
	println('   - 统一的安全验证模块，避免代码重复')
	println('   - 增强的路径遍历攻击防护')
	println('   - 严格的输入验证（哈希、文件名、大小等）')
	println('   - 文件类型白名单机制')
	println('   - 可配置的安全选项')
}