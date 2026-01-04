// SSE Streaming Demo - Server-Sent Events Example for v-hono
// This example demonstrates all SSE streaming helper functions:
// - stream() - Basic binary streaming
// - stream_text() - Text streaming
// - stream_sse() - Server-Sent Events streaming
//
// Run with: v -enable-globals run examples/sse_demo.v
// Then open a browser and navigate to http://127.0.0.1:3000
// Or use curl to test the endpoints:
//   curl http://127.0.0.1:3000/stream
//   curl http://127.0.0.1:3000/stream-text
//   curl http://127.0.0.1:3000/sse
//
// Features demonstrated:
// - Basic binary streaming with stream()
// - Text streaming with stream_text()
// - SSE event streaming with stream_sse()
// - Error handling with custom error handlers
// - SSE event fields (data, event, id, retry)
// - Multi-line data in SSE events
// - Sleep/delay between stream writes
// - onAbort callback for client disconnection
module main

import net.http
import os
import hono

fn main() {
	mut app := hono.Hono.new()

	// =========================================================================
	// Static HTML page for testing SSE
	// =========================================================================
	
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.html(get_sse_test_page())
	})

	// =========================================================================
	// Basic Binary Streaming Example
	// =========================================================================
	
	// Basic stream - demonstrates binary data streaming
	// Sets Transfer-Encoding: chunked header
	app.get('/stream', fn (mut c hono.Context) http.Response {
		return hono.c_stream(mut c, fn (mut stream hono.StreamContext) ! {
			// Register abort callback for client disconnection
			stream.on_abort(fn () {
				println('[Stream] Client disconnected')
			})
			
			// Stream binary data in chunks
			for i in 0 .. 5 {
				data := 'Chunk ${i + 1}: Hello from binary stream!\n'
				stream.write(data.bytes())!
				stream.sleep(500) // 500ms delay between chunks
			}
			
			stream.write('Stream complete!\n'.bytes())!
		})
	})

	// =========================================================================
	// Text Streaming Example
	// =========================================================================
	
	// Text stream - demonstrates text data streaming
	// Sets Content-Type: text/plain; charset=utf-8
	// Sets Transfer-Encoding: chunked
	// Sets X-Content-Type-Options: nosniff
	app.get('/stream-text', fn (mut c hono.Context) http.Response {
		return hono.c_stream_text(mut c, fn (mut stream hono.StreamContext) ! {
			// Register abort callback
			stream.on_abort(fn () {
				println('[StreamText] Client disconnected')
			})
			
			// Stream text data with writeln (adds newline automatically)
			stream.writeln('=== Text Streaming Demo ===')!
			stream.sleep(300)
			
			for i in 0 .. 5 {
				stream.write_string('Processing item ${i + 1}... ')!
				stream.sleep(200)
				stream.writeln('Done!')!
				stream.sleep(300)
			}
			
			stream.writeln('')!
			stream.writeln('All items processed successfully!')!
		})
	})

	// =========================================================================
	// SSE (Server-Sent Events) Streaming Example
	// =========================================================================
	
	// SSE stream - demonstrates Server-Sent Events
	// Sets Content-Type: text/event-stream
	// Sets Cache-Control: no-cache
	// Sets Connection: keep-alive
	app.get('/sse', fn (mut c hono.Context) http.Response {
		return hono.c_stream_sse(mut c, fn (mut stream hono.StreamContext) ! {
			// Register abort callback
			stream.on_abort(fn () {
				println('[SSE] Client disconnected')
			})
			
			// Send initial connection event
			stream.write_sse(hono.SSEEvent{
				data: 'Connected to SSE stream'
				event: 'connect'
				id: '0'
			})!
			
			// Send periodic updates
			for i in 1 .. 6 {
				stream.sleep(1000) // 1 second delay
				
				stream.write_sse(hono.SSEEvent{
					data: 'Update ${i}: Current time is ${get_timestamp()}'
					event: 'update'
					id: '${i}'
				})!
			}
			
			// Send completion event
			stream.write_sse(hono.SSEEvent{
				data: 'Stream completed'
				event: 'complete'
				id: '999'
			})!
		})
	})

	// =========================================================================
	// SSE with Multi-line Data Example
	// =========================================================================
	
	// SSE with multi-line data - demonstrates multi-line data handling
	app.get('/sse-multiline', fn (mut c hono.Context) http.Response {
		return hono.c_stream_sse(mut c, fn (mut stream hono.StreamContext) ! {
			// Send event with multi-line data
			stream.write_sse(hono.SSEEvent{
				data: 'Line 1: First line of data\nLine 2: Second line of data\nLine 3: Third line of data'
				event: 'multiline'
				id: '1'
			})!
			
			stream.sleep(1000)
			
			// Send JSON data (multi-line formatted)
			json_data := '{\n  "name": "v-hono",\n  "version": "1.0.0",\n  "features": ["SSE", "WebSocket", "Streaming"]\n}'
			stream.write_sse(hono.SSEEvent{
				data: json_data
				event: 'json'
				id: '2'
			})!
		})
	})

	// =========================================================================
	// SSE with Retry Field Example
	// =========================================================================
	
	// SSE with retry - demonstrates retry field for reconnection
	app.get('/sse-retry', fn (mut c hono.Context) http.Response {
		return hono.c_stream_sse(mut c, fn (mut stream hono.StreamContext) ! {
			// Send event with retry field (tells client to reconnect after 3 seconds)
			stream.write_sse(hono.SSEEvent{
				data: 'This event includes a retry field'
				event: 'message'
				id: '1'
				retry: 3000 // 3 seconds
			})!
			
			stream.sleep(1000)
			
			// Send another event without retry
			stream.write_sse(hono.SSEEvent{
				data: 'This event does not include retry'
				event: 'message'
				id: '2'
			})!
		})
	})

	// =========================================================================
	// SSE with Error Handling Example
	// =========================================================================
	
	// SSE with error handling - demonstrates custom error handler
	app.get('/sse-error', fn (mut c hono.Context) http.Response {
		return hono.c_stream_sse(mut c, fn (mut stream hono.StreamContext) ! {
			// Send initial event
			stream.write_sse(hono.SSEEvent{
				data: 'Starting stream with potential error...'
				event: 'start'
				id: '1'
			})!
			
			stream.sleep(1000)
			
			// Simulate an error condition
			// In real applications, this could be a database error, API failure, etc.
			should_error := true
			if should_error {
				return error('Simulated error for demonstration')
			}
			
			// This won't be reached due to the error above
			stream.write_sse(hono.SSEEvent{
				data: 'This message will not be sent'
				event: 'message'
				id: '2'
			})!
		}, fn (err IError, mut stream hono.StreamContext) {
			// Custom error handler - send error event to client
			println('[SSE Error Handler] Error occurred: ${err.msg()}')
			
			// Try to send error event to client before closing
			stream.write_sse(hono.SSEEvent{
				data: 'Error: ${err.msg()}'
				event: 'error'
				id: 'error'
			}) or {
				println('[SSE Error Handler] Failed to send error event: ${err}')
			}
		})
	})

	// =========================================================================
	// Real-time Counter Example
	// =========================================================================
	
	// Real-time counter - demonstrates continuous SSE updates
	app.get('/sse-counter', fn (mut c hono.Context) http.Response {
		return hono.c_stream_sse(mut c, fn (mut stream hono.StreamContext) ! {
			mut counter := 0
			
			// Send counter updates every 500ms for 20 iterations
			for _ in 0 .. 20 {
				if !stream.is_open() {
					println('[Counter] Stream closed, stopping')
					break
				}
				
				counter++
				stream.write_sse(hono.SSEEvent{
					data: '${counter}'
					event: 'counter'
					id: '${counter}'
				})!
				
				stream.sleep(500)
			}
			
			// Send completion event
			stream.write_sse(hono.SSEEvent{
				data: 'Counter finished at ${counter}'
				event: 'complete'
				id: 'done'
			})!
		})
	})

	// =========================================================================
	// Pipe Example - Stream file content
	// =========================================================================
	
	// Pipe example - demonstrates piping data to stream
	app.get('/stream-pipe', fn (mut c hono.Context) http.Response {
		return hono.c_stream(mut c, fn (mut stream hono.StreamContext) ! {
			// Create some sample data to pipe
			sample_data := 'This is sample data that will be piped to the stream.\n'.repeat(5)
			
			// Pipe the data in chunks
			chunk_size := 50
			mut offset := 0
			
			for offset < sample_data.len {
				end := if offset + chunk_size > sample_data.len { sample_data.len } else { offset + chunk_size }
				chunk := sample_data[offset..end]
				stream.pipe(chunk.bytes())!
				offset = end
				stream.sleep(100)
			}
		})
	})

	// =========================================================================
	// REST API endpoints for demonstration
	// =========================================================================
	
	app.get('/api/status', fn (mut c hono.Context) http.Response {
		return c.json('{"status":"running","streaming_endpoints":["/stream","/stream-text","/sse","/sse-multiline","/sse-retry","/sse-error","/sse-counter","/stream-pipe"]}')
	})

	// =========================================================================
	// Start the server
	// =========================================================================
	
	println('============================================================')
	println('SSE Streaming Demo Server')
	println('============================================================')
	println('')
	println('Server starting on http://127.0.0.1:3000')
	println('')
	println('Streaming Endpoints:')
	println('  http://127.0.0.1:3000/stream          - Basic binary streaming')
	println('  http://127.0.0.1:3000/stream-text     - Text streaming')
	println('  http://127.0.0.1:3000/sse             - SSE event streaming')
	println('  http://127.0.0.1:3000/sse-multiline   - SSE with multi-line data')
	println('  http://127.0.0.1:3000/sse-retry       - SSE with retry field')
	println('  http://127.0.0.1:3000/sse-error       - SSE with error handling')
	println('  http://127.0.0.1:3000/sse-counter     - Real-time counter')
	println('  http://127.0.0.1:3000/stream-pipe     - Pipe data to stream')
	println('')
	println('HTTP Endpoints:')
	println('  http://127.0.0.1:3000/                - Test page')
	println('  http://127.0.0.1:3000/api/status      - Server status')
	println('')
	println('Test with curl:')
	println('  curl http://127.0.0.1:3000/stream')
	println('  curl http://127.0.0.1:3000/stream-text')
	println('  curl http://127.0.0.1:3000/sse')
	println('')
	println('============================================================')
	
	app.listen(':3000')
}

// get_timestamp - Get current timestamp string
fn get_timestamp() string {
	return '${os.execute("echo %TIME%").output.trim_space()}'
}



// get_sse_test_page - Returns HTML test page for SSE streaming
fn get_sse_test_page() string {
	sq := "'"
	return '<!DOCTYPE html>
<html>
<head>
<title>v-hono SSE Streaming Demo</title>
<style>
* { box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 1000px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
h1 { color: #667eea; margin-bottom: 10px; }
h2 { color: #333; font-size: 1.2em; margin: 20px 0 10px; }
.subtitle { color: #666; margin-bottom: 30px; }
.card { background: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
.endpoint { display: flex; align-items: center; gap: 10px; margin: 10px 0; flex-wrap: wrap; }
.endpoint-url { font-family: monospace; background: #f0f0f0; padding: 8px 12px; border-radius: 4px; flex: 1; min-width: 200px; }
button { padding: 8px 16px; border-radius: 4px; border: none; cursor: pointer; font-size: 14px; transition: background 0.2s; }
.btn-connect { background: #667eea; color: white; }
.btn-connect:hover { background: #5a6fd6; }
.btn-disconnect { background: #e74c3c; color: white; }
.btn-disconnect:hover { background: #c0392b; }
.btn-clear { background: #95a5a6; color: white; }
.btn-clear:hover { background: #7f8c8d; }
.status { padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
.status-connected { background: #27ae60; color: white; }
.status-disconnected { background: #e74c3c; color: white; }
.status-connecting { background: #f39c12; color: white; }
.output { height: 200px; overflow-y: auto; background: #1e1e1e; color: #d4d4d4; padding: 15px; border-radius: 4px; font-family: monospace; font-size: 13px; line-height: 1.5; }
.output:empty::before { content: "No messages yet..."; color: #666; }
.msg { margin: 2px 0; padding: 2px 0; }
.msg-event { color: #569cd6; }
.msg-data { color: #ce9178; }
.msg-id { color: #b5cea8; }
.msg-retry { color: #dcdcaa; }
.msg-system { color: #6a9955; font-style: italic; }
.msg-error { color: #f44747; }
.msg-text { color: #d4d4d4; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(450px, 1fr)); gap: 20px; }
@media (max-width: 600px) { .grid { grid-template-columns: 1fr; } .endpoint { flex-direction: column; align-items: stretch; } }
</style>
</head>
<body>
<h1>v-hono SSE Streaming Demo</h1>
<p class="subtitle">Test Server-Sent Events and streaming responses</p>

<div class="grid">
  <div class="card">
    <h2>SSE Event Stream</h2>
    <div class="endpoint">
      <span class="endpoint-url">/sse</span>
      <button class="btn-connect" onclick="connectSSE(${sq}/sse${sq}, ${sq}sse-output${sq}, ${sq}sse-status${sq})">Connect</button>
      <button class="btn-disconnect" onclick="disconnectSSE(${sq}sse${sq})">Disconnect</button>
      <span id="sse-status" class="status status-disconnected">Disconnected</span>
    </div>
    <div id="sse-output" class="output"></div>
    <button class="btn-clear" onclick="clearOutput(${sq}sse-output${sq})">Clear</button>
  </div>

  <div class="card">
    <h2>Multi-line SSE</h2>
    <div class="endpoint">
      <span class="endpoint-url">/sse-multiline</span>
      <button class="btn-connect" onclick="connectSSE(${sq}/sse-multiline${sq}, ${sq}multiline-output${sq}, ${sq}multiline-status${sq})">Connect</button>
      <button class="btn-disconnect" onclick="disconnectSSE(${sq}multiline${sq})">Disconnect</button>
      <span id="multiline-status" class="status status-disconnected">Disconnected</span>
    </div>
    <div id="multiline-output" class="output"></div>
    <button class="btn-clear" onclick="clearOutput(${sq}multiline-output${sq})">Clear</button>
  </div>

  <div class="card">
    <h2>Real-time Counter</h2>
    <div class="endpoint">
      <span class="endpoint-url">/sse-counter</span>
      <button class="btn-connect" onclick="connectSSE(${sq}/sse-counter${sq}, ${sq}counter-output${sq}, ${sq}counter-status${sq})">Connect</button>
      <button class="btn-disconnect" onclick="disconnectSSE(${sq}counter${sq})">Disconnect</button>
      <span id="counter-status" class="status status-disconnected">Disconnected</span>
    </div>
    <div id="counter-output" class="output"></div>
    <button class="btn-clear" onclick="clearOutput(${sq}counter-output${sq})">Clear</button>
  </div>

  <div class="card">
    <h2>Error Handling</h2>
    <div class="endpoint">
      <span class="endpoint-url">/sse-error</span>
      <button class="btn-connect" onclick="connectSSE(${sq}/sse-error${sq}, ${sq}error-output${sq}, ${sq}error-status${sq})">Connect</button>
      <button class="btn-disconnect" onclick="disconnectSSE(${sq}error${sq})">Disconnect</button>
      <span id="error-status" class="status status-disconnected">Disconnected</span>
    </div>
    <div id="error-output" class="output"></div>
    <button class="btn-clear" onclick="clearOutput(${sq}error-output${sq})">Clear</button>
  </div>

  <div class="card">
    <h2>Text Stream</h2>
    <div class="endpoint">
      <span class="endpoint-url">/stream-text</span>
      <button class="btn-connect" onclick="fetchStream(${sq}/stream-text${sq}, ${sq}text-output${sq}, ${sq}text-status${sq})">Fetch</button>
      <span id="text-status" class="status status-disconnected">Ready</span>
    </div>
    <div id="text-output" class="output"></div>
    <button class="btn-clear" onclick="clearOutput(${sq}text-output${sq})">Clear</button>
  </div>

  <div class="card">
    <h2>Binary Stream</h2>
    <div class="endpoint">
      <span class="endpoint-url">/stream</span>
      <button class="btn-connect" onclick="fetchStream(${sq}/stream${sq}, ${sq}binary-output${sq}, ${sq}binary-status${sq})">Fetch</button>
      <span id="binary-status" class="status status-disconnected">Ready</span>
    </div>
    <div id="binary-output" class="output"></div>
    <button class="btn-clear" onclick="clearOutput(${sq}binary-output${sq})">Clear</button>
  </div>
</div>

<script>
var connections = {};

function log(outputId, msg, type) {
  var output = document.getElementById(outputId);
  var div = document.createElement(${sq}div${sq});
  div.className = ${sq}msg msg-${sq} + (type || ${sq}text${sq});
  div.textContent = msg;
  output.appendChild(div);
  output.scrollTop = output.scrollHeight;
}

function setStatus(statusId, status) {
  var el = document.getElementById(statusId);
  el.textContent = status;
  el.className = ${sq}status status-${sq} + status.toLowerCase();
}

function clearOutput(outputId) {
  document.getElementById(outputId).innerHTML = ${sq}${sq};
}

function connectSSE(url, outputId, statusId) {
  var key = outputId.replace(${sq}-output${sq}, ${sq}${sq});
  if (connections[key]) {
    connections[key].close();
  }
  
  setStatus(statusId, ${sq}Connecting${sq});
  log(outputId, ${sq}Connecting to ${sq} + url + ${sq}...${sq}, ${sq}system${sq});
  
  var es = new EventSource(url);
  connections[key] = es;
  
  es.onopen = function() {
    setStatus(statusId, ${sq}Connected${sq});
    log(outputId, ${sq}Connected!${sq}, ${sq}system${sq});
  };
  
  es.onmessage = function(e) {
    log(outputId, ${sq}data: ${sq} + e.data, ${sq}data${sq});
  };
  
  es.onerror = function() {
    setStatus(statusId, ${sq}Disconnected${sq});
    log(outputId, ${sq}Connection closed${sq}, ${sq}system${sq});
    connections[key] = null;
  };
  
  // Listen for custom event types
  [${sq}connect${sq}, ${sq}update${sq}, ${sq}complete${sq}, ${sq}multiline${sq}, ${sq}json${sq}, ${sq}message${sq}, ${sq}counter${sq}, ${sq}start${sq}, ${sq}error${sq}].forEach(function(type) {
    es.addEventListener(type, function(e) {
      log(outputId, ${sq}event: ${sq} + type, ${sq}event${sq});
      log(outputId, ${sq}data: ${sq} + e.data, ${sq}data${sq});
      if (e.lastEventId) log(outputId, ${sq}id: ${sq} + e.lastEventId, ${sq}id${sq});
    });
  });
}

function disconnectSSE(key) {
  if (connections[key]) {
    connections[key].close();
    connections[key] = null;
    setStatus(key + ${sq}-status${sq}, ${sq}Disconnected${sq});
    log(key + ${sq}-output${sq}, ${sq}Disconnected by user${sq}, ${sq}system${sq});
  }
}

async function fetchStream(url, outputId, statusId) {
  setStatus(statusId, ${sq}Connecting${sq});
  log(outputId, ${sq}Fetching ${sq} + url + ${sq}...${sq}, ${sq}system${sq});
  
  try {
    var response = await fetch(url);
    var reader = response.body.getReader();
    var decoder = new TextDecoder();
    
    setStatus(statusId, ${sq}Connected${sq});
    
    while (true) {
      var result = await reader.read();
      if (result.done) break;
      var text = decoder.decode(result.value, {stream: true});
      log(outputId, text, ${sq}text${sq});
    }
    
    setStatus(statusId, ${sq}Disconnected${sq});
    log(outputId, ${sq}Stream complete${sq}, ${sq}system${sq});
  } catch (err) {
    setStatus(statusId, ${sq}Disconnected${sq});
    log(outputId, ${sq}Error: ${sq} + err.message, ${sq}error${sq});
  }
}
</script>
</body>
</html>'
}
