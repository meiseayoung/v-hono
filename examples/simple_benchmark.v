// 简单 HTTP 压测 - veb vs v-hono
// v run simple_benchmark.v

module main

import net.http
import time

const requests = 50

fn main() {
	println('╔═══════════════════════════════════════════════════════════════╗')
	println('║           简单 HTTP 压测 - veb vs v-hono                      ║')
	println('╚═══════════════════════════════════════════════════════════════╝')
	println('')
	
	// 测试 veb
	println('测试 veb (http://127.0.0.1:8080/)...')
	veb_result := benchmark_server('http://127.0.0.1:8080/')
	println('  结果: ${veb_result.rps:.0} req/s | avg: ${veb_result.avg_ms:.2}ms | 成功: ${veb_result.success}/${veb_result.total}')
	
	// 测试 v-hono
	println('')
	println('测试 v-hono (http://127.0.0.1:8081/)...')
	hono_result := benchmark_server('http://127.0.0.1:8081/')
	println('  结果: ${hono_result.rps:.0} req/s | avg: ${hono_result.avg_ms:.2}ms | 成功: ${hono_result.success}/${hono_result.total}')
	
	// 对比
	println('')
	println('═══════════════════════════════════════════════════════════════')
	if veb_result.rps > 0 && hono_result.rps > 0 {
		if hono_result.rps > veb_result.rps {
			ratio := hono_result.rps / veb_result.rps
			println('v-hono 快 ${ratio:.2}x')
		} else {
			ratio := veb_result.rps / hono_result.rps
			println('veb 快 ${ratio:.2}x')
		}
	}
	println('═══════════════════════════════════════════════════════════════')
}

struct Result {
	total   int
	success int
	rps     f64
	avg_ms  f64
}

fn benchmark_server(url string) Result {
	// 先检查服务器
	http.get(url) or {
		println('  ⚠️ 服务器不可用')
		return Result{}
	}
	
	mut success := 0
	mut total_ms := f64(0)
	
	start := time.now()
	
	for i in 0 .. requests {
		req_start := time.now()
		resp := http.get(url) or {
			continue
		}
		req_ms := f64(time.since(req_start).microseconds()) / 1000.0
		
		if resp.status_code == 200 {
			success++
		}
		total_ms += req_ms
		
		// 进度
		if (i + 1) % 10 == 0 {
			print('.')
		}
	}
	println('')
	
	elapsed := time.since(start)
	elapsed_ms := elapsed.milliseconds()
	
	rps := if elapsed_ms > 0 { f64(requests) * 1000.0 / f64(elapsed_ms) } else { 0.0 }
	avg_ms := if requests > 0 { total_ms / f64(requests) } else { 0.0 }
	
	return Result{
		total: requests
		success: success
		rps: rps
		avg_ms: avg_ms
	}
}
