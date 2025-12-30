// Keep-Alive HTTP 基准测试
module main

import net
import time

fn main() {
	addr := '127.0.0.1:9999'
	requests := 10000
	
	println('=== Keep-Alive HTTP 基准测试 ===')
	println('目标: ${addr}')
	println('请求数: ${requests}')
	println('')
	
	// 建立连接
	mut conn := net.dial_tcp(addr) or {
		println('连接失败: ${err}')
		return
	}
	defer { conn.close() or {} }
	
	// 预热
	println('预热中...')
	for _ in 0 .. 100 {
		send_keepalive_request(mut conn, addr) or {
			// 重连
			conn = net.dial_tcp(addr) or { continue }
			continue
		}
	}
	
	// 正式测试
	println('开始测试...')
	sw := time.new_stopwatch()
	mut success := 0
	
	for _ in 0 .. requests {
		send_keepalive_request(mut conn, addr) or {
			// 重连
			conn = net.dial_tcp(addr) or { continue }
			continue
		}
		success++
	}
	
	elapsed := sw.elapsed()
	elapsed_ms := f64(elapsed.milliseconds())
	rps := f64(success) * 1000.0 / elapsed_ms
	avg_us := elapsed_ms * 1000.0 / f64(success)
	
	println('')
	println('=== 结果 ===')
	println('成功请求: ${success}/${requests}')
	println('总耗时: ${elapsed_ms:.0f}ms')
	println('吞吐量: ${rps:.0f} req/s')
	println('平均延迟: ${avg_us:.2f}μs')
}

fn send_keepalive_request(mut conn net.TcpConn, addr string) ! {
	// 发送 HTTP 请求 (Keep-Alive)
	request := 'GET /api/health HTTP/1.1\r\nHost: ${addr}\r\nConnection: keep-alive\r\n\r\n'
	conn.write_string(request)!
	
	// 读取响应头和体
	mut buf := []u8{len: 256}
	conn.read(mut buf) or {}
}
