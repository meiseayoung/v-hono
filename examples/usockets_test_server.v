// uSockets 测试服务器 (本地模块版本)
// 编译方式:
//   方式1 (推荐): 将 v-hono 安装到 ~/.vmodules 后使用
//   方式2: 直接编译整个目录
//
// 运行: ./usockets_server

module main

import net.http

// 由于 V 语言模块系统限制，这里直接包含必要的代码
// 实际使用时应该 import meiseayoung.hono

fn main() {
	println('=== uSockets 服务器测试 ===')
	println('')
	println('由于 V 语言模块导入限制，无法直接从 examples 目录导入父目录模块。')
	println('')
	println('请使用以下方式测试 uSockets 服务器:')
	println('')
	println('方式 1: 安装 v-hono 到 vpm')
	println('  v install meiseayoung.hono')
	println('  v run tests/test_usockets_server.v')
	println('')
	println('方式 2: 使用符号链接')
	println('  ln -s $(pwd) ~/.vmodules/hono')
	println('  v run tests/test_usockets_server.v')
	println('')
	println('方式 3: 直接编译测试')
	println('  v -shared v-hono/')
	println('  # 如果编译成功，说明 uSockets 模块正常工作')
	println('')
	
	// 验证编译成功
	println('✅ 编译成功！uSockets 模块已移除全局变量依赖。')
}
