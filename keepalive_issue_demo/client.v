// Minimal client example - Test Keep-Alive connection reuse
module main

import net.http
import time

fn main() {
	println('=== V HTTP Keep-Alive Issue Demo ===\n')
	println('Sending 5 consecutive requests, observe the time for each...\n')
	
	url := 'http://127.0.0.1:8080/'
	
	for i in 1 .. 6 {
		start := time.now()
		
		resp := http.get(url) or {
			println('Request failed: ${err}')
			continue
		}
		
		elapsed := time.since(start)
		println('Request #${i}: ${elapsed.milliseconds()}ms - Status: ${resp.status_code}')
	}
	
	println('\n--- Analysis ---')
	println('If Keep-Alive works correctly:')
	println('  - First request: ~300ms (establish TCP connection)')
	println('  - Subsequent requests: ~1-10ms (reuse connection)')
	println('')
	println('Actual behavior (V language current):')
	println('  - Every request takes ~300ms (reconnect each time)')
	println('')
	println('Reason: net.http.Server calls conn.close() after each request')
}
