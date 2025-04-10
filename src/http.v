// 一个使用通道和线程的V语言HTTP服务器示例
import net.http
import time

// 定义请求结构
struct Request {
	id int
	url string
	method string
	timestamp time.Time
}

// 定义响应结构
struct Response {
	id int
	status_code int
	body string
	processing_time time.Duration
}

// 请求处理器 - 模拟处理HTTP请求
fn request_processor(req_chan chan Request, resp_chan chan Response) {
	for {
		// 从请求通道获取请求，如果通道关闭则退出循环
		req := <-req_chan or { break }

		// 记录开始处理时间
		start := time.now()

		// 根据URL模拟不同的处理时间和结果
		mut body := ''
		mut status := 200

		if req.url.contains('/api/') {
			// API请求需要更长的处理时间
			time.sleep(100 * time.millisecond)
			body = '{"status": "success", "data": {"id": ${req.id}}}'
		} else if req.url.contains('/slow/') {
			// 慢速请求
			time.sleep(300 * time.millisecond)
			body = '<html><body>Slow page content</body></html>'
		} else if req.url.contains('/error/') {
			// 错误请求
			time.sleep(50 * time.millisecond)
			status = 500
			body = 'Internal Server Error'
		} else {
			// 一般页面请求
			time.sleep(80 * time.millisecond)
			body = '<html><body>Regular page content</body></html>'
		}

		// 计算处理时间
		processing_time := time.now() - start

		// 将响应发送到响应通道
		resp_chan <- Response{
			id: req.id
			status_code: status
			body: body
			processing_time: processing_time
		}
	}
}

// 日志器 - 记录请求和响应
fn logger(log_chan chan string) {
	for {
		log_msg := <-log_chan or { break }
		println('[${time.now().format_ss_milli()}] $log_msg')
	}
}

// 统计分析器 - 收集和分析响应数据
fn stats_analyzer(resp_chan chan Response, log_chan chan string) {
	mut total_requests := 0
	mut success_requests := 0
	mut error_requests := 0
	mut total_processing_time := time.Duration(0)

	for {
		resp := <-resp_chan or { break }

		total_requests++
		total_processing_time += resp.processing_time

		if resp.status_code >= 200 && resp.status_code < 400 {
			success_requests++
		} else {
			error_requests++
		}

		// 每10个请求生成一次统计报告
		if total_requests % 10 == 0 {
			avg_time := total_processing_time / total_requests
			log_chan <- 'STATS: Total: $total_requests, Success: $success_requests, Errors: $error_requests, Avg Time: ${avg_time}ms'
		}
	}
}

// 模拟HTTP服务器处理请求的函数
fn handle_request(id int, url string, method string, req_chan chan Request, log_chan chan string) {
	// 创建请求对象
	req := Request{
		id: id
		url: url
		method: method
		timestamp: time.now()
	}

	// 记录请求信息
	log_chan <- 'REQUEST #$id: $method $url'

	// 发送请求到处理通道
	req_chan <- req
}

fn main() {
	// 创建通道
	req_chan := chan Request{cap: 100} // 请求通道，缓冲容量100
	resp_chan1 := chan Response{cap: 100} // 响应通道1，用于响应处理
	resp_chan2 := chan Response{cap: 100} // 响应通道2，用于统计分析
	log_chan := chan string{cap: 200} // 日志通道

	// 启动日志记录器线程
	spawn logger(log_chan)

	// 启动多个请求处理器线程（工作池）
	worker_count := 5
	for i in 0..worker_count {
		spawn request_processor(req_chan, resp_chan1)
	}

	// 启动统计分析器线程
	spawn stats_analyzer(resp_chan2, log_chan)

	// 模拟接收HTTP请求
	request_count := 30
	for i in 0..request_count {
		// 随机生成不同类型的URL
		url_types := ['/api/user', '/api/data', '/slow/page', '/error/test', '/home', '/about']
		url := url_types[i % url_types.len]
		method := if i % 5 == 0 { 'POST' } else { 'GET' }

		// 处理请求
		handle_request(i, url, method, req_chan, log_chan)

		// 从响应通道1接收响应并复制到响应通道2用于统计
		if i > 0 && i % 3 == 0 {
			for j in 0..3 {
				if resp := <-resp_chan1 {
					log_chan <- 'RESPONSE #${resp.id}: Status ${resp.status_code}, Processed in ${resp.processing_time}ms'
					resp_chan2 <- resp
				}
			}
		}

		// 模拟请求到达间隔
		time.sleep(50 * time.millisecond)
	}

	// 等待所有响应处理完毕
	time.sleep(1 * time.second)

	// 处理剩余的响应
	remaining := request_count - (request_count / 3 * 3)
	for i in 0..remaining {
		if resp := <-resp_chan1 {
			log_chan <- 'RESPONSE #${resp.id}: Status ${resp.status_code}, Processed in ${resp.processing_time}ms'
			resp_chan2 <- resp
		}
	}

	// 最终统计
	log_chan <- 'SERVER SHUTDOWN: All requests processed'

	// 给统计分析器线程时间处理最后的数据
	time.sleep(500 * time.millisecond)

	// 关闭通道
	req_chan.close()
	resp_chan1.close()
	resp_chan2.close()
	log_chan.close()

	// 给所有线程时间完成和退出
	time.sleep(100 * time.millisecond)
	println('Server shutdown complete')
}
