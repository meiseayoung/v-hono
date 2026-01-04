// WebSocket Demo - Chat Room Example for v-hono
// This example demonstrates all WebSocket event handlers and configuration options.
//
// Run with: v run examples/websocket_demo.v
// Then open a browser and navigate to http://127.0.0.1:3000
// Or use a WebSocket client to connect to ws://127.0.0.1:3000/ws/chat/general
//
// Features demonstrated:
// - WebSocket upgrade handling
// - Event handlers (on_open, on_message, on_close, on_error)
// - Route parameters (/ws/chat/:room)
// - Query parameters (?username=xxx)
// - Subprotocol negotiation
// - Custom configuration options (ping interval, max message size, timeout)
// - JSON message handling
// - Binary message handling
// - Middleware integration with WebSocket routes
module main

import net.http
import time
import os
import hono

fn main() {
	mut app := hono.Hono.new()

	// =========================================================================
	// Middleware - Runs before WebSocket upgrade
	// =========================================================================
	
	// Logger middleware - logs all requests including WebSocket upgrades
	app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
		start := time.now()
		response := next(mut c)
		duration := time.since(start)
		println('[${time.now().format_ss()}] ${c.req.method} ${c.path} - ${response.status_code} (${duration})')
		return response
	})

	// =========================================================================
	// Static HTML page for testing WebSocket
	// =========================================================================
	
	app.get('/', fn (mut c hono.Context) http.Response {
		// Try to load the HTML file from the examples directory
		html_content := os.read_file('examples/websocket_test.html') or {
			// Fallback to a simple HTML page if file not found
			return c.html(get_simple_test_page())
		}
		return c.html(html_content)
	})

	// =========================================================================
	// Basic WebSocket Echo Example
	// =========================================================================
	
	// Simple echo WebSocket - echoes back any message received
	app.ws('/ws/echo', fn (c hono.Context) hono.WSEvents {
		return hono.WSEvents{
			on_open: fn (mut ws hono.WSContext) {
				println('[Echo] Client connected')
				ws.send('Welcome to the echo server!') or {
					println('[Echo] Failed to send welcome: ${err}')
				}
			}
			on_message: fn (event hono.WSMessageEvent, mut ws hono.WSContext) {
				if event.is_binary {
					println('[Echo] Received binary message: ${event.data_bytes.len} bytes')
					ws.send_bytes(event.data_bytes) or {
						println('[Echo] Failed to echo binary: ${err}')
					}
				} else {
					println('[Echo] Received: ${event.data}')
					ws.send('Echo: ${event.data}') or {
						println('[Echo] Failed to echo: ${err}')
					}
				}
			}
			on_close: fn (event hono.WSCloseEvent, mut ws hono.WSContext) {
				println('[Echo] Client disconnected - Code: ${event.code}, Reason: ${event.reason}, Clean: ${event.was_clean}')
			}
			on_error: fn (error string, mut ws hono.WSContext) {
				println('[Echo] Error: ${error}')
			}
		}
	})

	// =========================================================================
	// Chat Room WebSocket with Route Parameters
	// =========================================================================
	
	// Chat room WebSocket - demonstrates route parameters and query parameters
	// URL format: /ws/chat/:room?username=xxx
	app.ws('/ws/chat/:room', fn (c hono.Context) hono.WSEvents {
		// Access route parameters from the HTTP context
		room := c.params['room'] or { 'general' }
		username := c.query['username'] or { 'anonymous' }
		
		println('[Chat] User "${username}" joining room "${room}"')
		
		return hono.WSEvents{
			on_open: fn [room, username] (mut ws hono.WSContext) {
				// Access preserved context data
				actual_room := ws.params['room'] or { room }
				actual_user := ws.query['username'] or { username }
				
				println('[Chat/${actual_room}] ${actual_user} connected')
				
				// Send welcome message as JSON
				welcome := '{"type":"system","message":"Welcome to room ${actual_room}, ${actual_user}!"}'
				ws.send_json(welcome) or {
					println('[Chat] Failed to send welcome: ${err}')
				}
				
				// Broadcast join notification
				join_msg := '{"type":"join","user":"${actual_user}","room":"${actual_room}"}'
				ws.send_json(join_msg) or {}
			}
			on_message: fn [room, username] (event hono.WSMessageEvent, mut ws hono.WSContext) {
				actual_room := ws.params['room'] or { room }
				actual_user := ws.query['username'] or { username }
				
				println('[Chat/${actual_room}] ${actual_user}: ${event.data}')
				
				// Echo the message back with metadata
				response := '{"type":"message","user":"${actual_user}","room":"${actual_room}","content":"${event.data}"}'
				ws.send_json(response) or {
					println('[Chat] Failed to send response: ${err}')
				}
			}
			on_close: fn [room, username] (event hono.WSCloseEvent, mut ws hono.WSContext) {
				actual_room := ws.params['room'] or { room }
				actual_user := ws.query['username'] or { username }
				
				println('[Chat/${actual_room}] ${actual_user} disconnected (code: ${event.code})')
			}
			on_error: fn [room, username] (error string, mut ws hono.WSContext) {
				actual_room := ws.params['room'] or { room }
				actual_user := ws.query['username'] or { username }
				
				println('[Chat/${actual_room}] Error for ${actual_user}: ${error}')
			}
		}
	})

	// =========================================================================
	// WebSocket with Custom Configuration Options
	// =========================================================================
	
	// Configured WebSocket - demonstrates custom options
	app.ws('/ws/configured', fn (c hono.Context) hono.WSEvents {
		return hono.WSEvents{
			on_open: fn (mut ws hono.WSContext) {
				println('[Configured] Client connected with custom settings')
				ws.send('Connected with custom configuration!') or {}
			}
			on_message: fn (event hono.WSMessageEvent, mut ws hono.WSContext) {
				println('[Configured] Message: ${event.data}')
				ws.send('Received: ${event.data}') or {}
			}
			on_close: fn (event hono.WSCloseEvent, mut ws hono.WSContext) {
				println('[Configured] Disconnected')
			}
			on_error: fn (error string, mut ws hono.WSContext) {
				println('[Configured] Error: ${error}')
			}
		}
	}, hono.WebSocketOptions{
		ping_interval: 15000      // Send ping every 15 seconds
		max_message_size: 65536   // Max 64KB messages
		timeout: 30000            // 30 second timeout
		protocols: ['chat', 'json']  // Supported subprotocols
	})

	// =========================================================================
	// WebSocket with Subprotocol Negotiation
	// =========================================================================
	
	// Subprotocol WebSocket - demonstrates protocol negotiation
	app.ws('/ws/protocol', fn (c hono.Context) hono.WSEvents {
		return hono.WSEvents{
			on_open: fn (mut ws hono.WSContext) {
				protocol := ws.protocol
				println('[Protocol] Client connected with protocol: ${protocol}')
				
				if protocol == 'json' {
					ws.send_json('{"status":"connected","protocol":"json"}') or {}
				} else {
					ws.send('Connected with protocol: ${protocol}') or {}
				}
			}
			on_message: fn (event hono.WSMessageEvent, mut ws hono.WSContext) {
				protocol := ws.protocol
				println('[Protocol] Message (${protocol}): ${event.data}')
				
				if protocol == 'json' {
					ws.send_json('{"echo":"${event.data}"}') or {}
				} else {
					ws.send('Echo: ${event.data}') or {}
				}
			}
			on_close: fn (event hono.WSCloseEvent, mut ws hono.WSContext) {
				println('[Protocol] Disconnected')
			}
			on_error: fn (error string, mut ws hono.WSContext) {
				println('[Protocol] Error: ${error}')
			}
		}
	}, hono.WebSocketOptions{
		protocols: ['json', 'text', 'binary']
	})

	// =========================================================================
	// Binary Data WebSocket
	// =========================================================================
	
	// Binary WebSocket - demonstrates binary message handling
	app.ws('/ws/binary', fn (c hono.Context) hono.WSEvents {
		return hono.WSEvents{
			on_open: fn (mut ws hono.WSContext) {
				println('[Binary] Client connected')
				ws.send('Binary WebSocket ready. Send binary data!') or {}
			}
			on_message: fn (event hono.WSMessageEvent, mut ws hono.WSContext) {
				if event.is_binary {
					println('[Binary] Received ${event.data_bytes.len} bytes')
					
					// Echo back the binary data
					ws.send_bytes(event.data_bytes) or {
						println('[Binary] Failed to echo: ${err}')
					}
					
					// Also send a text confirmation
					ws.send('Received ${event.data_bytes.len} bytes of binary data') or {}
				} else {
					println('[Binary] Received text: ${event.data}')
					ws.send('Please send binary data, not text!') or {}
				}
			}
			on_close: fn (event hono.WSCloseEvent, mut ws hono.WSContext) {
				println('[Binary] Disconnected')
			}
			on_error: fn (error string, mut ws hono.WSContext) {
				println('[Binary] Error: ${error}')
			}
		}
	})

	// =========================================================================
	// REST API endpoints for demonstration
	// =========================================================================
	
	app.get('/api/rooms', fn (mut c hono.Context) http.Response {
		return c.json('{"rooms":["general","tech","random"]}')
	})

	app.get('/api/status', fn (mut c hono.Context) http.Response {
		return c.json('{"status":"running","websocket_endpoints":["/ws/echo","/ws/chat/:room","/ws/configured","/ws/protocol","/ws/binary"]}')
	})

	// =========================================================================
	// Start the server
	// =========================================================================
	
	println('============================================================')
	println('WebSocket Demo Server')
	println('============================================================')
	println('')
	println('Server starting on http://127.0.0.1:3000')
	println('')
	println('WebSocket Endpoints:')
	println('  ws://127.0.0.1:3000/ws/echo           - Simple echo server')
	println('  ws://127.0.0.1:3000/ws/chat/:room     - Chat room with route params')
	println('  ws://127.0.0.1:3000/ws/configured     - Custom configuration demo')
	println('  ws://127.0.0.1:3000/ws/protocol       - Subprotocol negotiation')
	println('  ws://127.0.0.1:3000/ws/binary         - Binary data handling')
	println('')
	println('HTTP Endpoints:')
	println('  http://127.0.0.1:3000/                - Test page')
	println('  http://127.0.0.1:3000/api/rooms       - List rooms')
	println('  http://127.0.0.1:3000/api/status      - Server status')
	println('')
	println('============================================================')
	
	app.listen(':3000')
}

// Simple fallback test page when HTML file is not found
fn get_simple_test_page() string {
	return '<!DOCTYPE html>
<html>
<head>
<title>v-hono WebSocket Demo</title>
<style>
body{font-family:sans-serif;max-width:800px;margin:50px auto;padding:20px}
h1{color:#667eea}
.card{background:#f5f5f5;padding:20px;margin:20px 0;border-radius:8px}
input,button{padding:10px;margin:5px;border-radius:4px;border:1px solid #ccc}
button{background:#667eea;color:white;border:none;cursor:pointer}
button:hover{background:#5a6fd6}
#messages{height:200px;overflow-y:auto;background:white;padding:10px;border:1px solid #ccc;border-radius:4px}
.msg{padding:5px;margin:2px 0;border-radius:4px}
.sent{background:#e3f2fd}
.received{background:#e8f5e9}
.system{background:#fff3e0}
</style>
</head>
<body>
<h1>v-hono WebSocket Demo</h1>
<div class="card">
<h3>Connection</h3>
<input type="text" id="url" value="ws://127.0.0.1:3000/ws/echo" style="width:300px">
<button onclick="connect()">Connect</button>
<button onclick="disconnect()">Disconnect</button>
<span id="status">Disconnected</span>
</div>
<div class="card">
<h3>Send Message</h3>
<input type="text" id="msg" placeholder="Type message..." style="width:300px">
<button onclick="send()">Send</button>
</div>
<div class="card">
<h3>Messages</h3>
<div id="messages"></div>
</div>
<script>
var ws=null;
function log(t,c){var m=document.getElementById("messages");m.innerHTML+="<div class=msg "+c+">"+t+"</div>";m.scrollTop=m.scrollHeight}
function connect(){if(ws)return;ws=new WebSocket(document.getElementById("url").value);ws.onopen=function(){document.getElementById("status").textContent="Connected";log("Connected","system")};ws.onmessage=function(e){log("Received: "+e.data,"received")};ws.onclose=function(){document.getElementById("status").textContent="Disconnected";log("Disconnected","system");ws=null};ws.onerror=function(){log("Error","system")}}
function disconnect(){if(ws)ws.close()}
function send(){if(!ws)return;var m=document.getElementById("msg").value;ws.send(m);log("Sent: "+m,"sent");document.getElementById("msg").value=""}
</script>
</body>
</html>'
}
