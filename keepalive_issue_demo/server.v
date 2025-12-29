// Minimal server example - Demonstrate Keep-Alive issue
module main

import net.http
import time

struct MyHandler {}

fn (_ MyHandler) handle(req http.Request) http.Response {
	now := time.now()
	println('[${now.format_ss_micro()}] Received request: ${req.method} ${req.url}')
	
	return http.Response{
		status_code: 200
		status_msg: 'OK'
		header: http.new_custom_header_from_map({
			'Content-Type': 'text/plain'
			'Connection': 'keep-alive'  // Set but not effective
		}) or { http.new_header() }
		body: 'Hello! Time: ${now.format_ss_micro()}'
	}
}

fn main() {
	println('Starting server at http://localhost:8080')
	println('Server sends Connection: keep-alive in response header')
	println('But due to V stdlib limitation, connection is still closed')
	
	mut server := http.Server{
		handler: MyHandler{}
		addr: ':8080'
	}
	server.listen_and_serve()
}
