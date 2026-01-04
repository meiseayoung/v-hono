// streaming.v - SSE Streaming Helper for v-hono
// Provides Server-Sent Events (SSE) and streaming response support
// Reference: Hono.js Streaming Helper API
module hono

import net.http
import time
import picohttpparser
import usockets

// C function declaration for direct socket writes
fn C.send(sockfd int, buf voidptr, len int, flags int) int

// ============================================================================
// SSE Event Structure
// ============================================================================

// SSEEvent - Server-Sent Events event structure
// Used with stream_sse() to send formatted SSE events to clients
pub struct SSEEvent {
pub:
	data  string // Event data (required) - supports multi-line
	event string // Event type name (optional)
	id    string // Event ID for client reconnection (optional)
	retry int    // Reconnection time in milliseconds (optional, 0 = not set)
}

// ============================================================================
// StreamWriter Interface
// ============================================================================

// StreamWriter - Abstract interface for stream writing
// Allows different server backends (picoev, uSockets) to implement their own writers
pub interface StreamWriter {
	// Check if the connection is still active (immutable)
	is_connected() bool
mut:
	// Write raw bytes to the stream
	write(data []u8) !
	// Write string to the stream
	write_string(data string) !
	// Flush the buffer to ensure data is sent
	flush() !
	// Close the stream connection
	close() !
}

// ============================================================================
// StreamContext Structure
// ============================================================================

// StreamContext - Context provided to streaming callbacks
// Provides methods for writing data, SSE events, and managing the stream
@[heap]
pub struct StreamContext {
mut:
	writer    &StreamWriter
	is_closed bool
	abort_fn  ?fn ()
}

// StreamContext.new - Create a new StreamContext with the given writer
pub fn StreamContext.new(writer &StreamWriter) StreamContext {
	return StreamContext{
		writer: unsafe { writer }
		is_closed: false
		abort_fn: none
	}
}

// write - Write raw bytes to the stream
pub fn (mut ctx StreamContext) write(data []u8) ! {
	if ctx.is_closed {
		return error('Stream is closed')
	}
	if !ctx.writer.is_connected() {
		ctx.is_closed = true
		return error('Connection lost')
	}
	ctx.writer.write(data)!
}

// write_string - Write a string to the stream
pub fn (mut ctx StreamContext) write_string(data string) ! {
	if ctx.is_closed {
		return error('Stream is closed')
	}
	if !ctx.writer.is_connected() {
		ctx.is_closed = true
		return error('Connection lost')
	}
	ctx.writer.write_string(data)!
}

// writeln - Write a string followed by a newline character
pub fn (mut ctx StreamContext) writeln(data string) ! {
	ctx.write_string(data)!
	ctx.write_string('\n')!
}


// write_sse - Write an SSE event to the stream
// Formats the event according to the SSE specification:
// - event: {type}\n (if event field is set)
// - data: {line}\n (for each line of data)
// - id: {id}\n (if id field is set)
// - retry: {ms}\n (if retry > 0)
// - \n (event separator)
pub fn (mut ctx StreamContext) write_sse(event SSEEvent) ! {
	if ctx.is_closed {
		return error('Stream is closed')
	}
	if !ctx.writer.is_connected() {
		ctx.is_closed = true
		return error('Connection lost')
	}

	// Write event type if specified
	if event.event.len > 0 {
		ctx.writer.write_string('event: ${event.event}\n')!
	}

	// Write data field - handle multi-line data
	lines := event.data.split('\n')
	for line in lines {
		ctx.writer.write_string('data: ${line}\n')!
	}

	// Write id if specified
	if event.id.len > 0 {
		ctx.writer.write_string('id: ${event.id}\n')!
	}

	// Write retry if specified (must be > 0)
	if event.retry > 0 {
		ctx.writer.write_string('retry: ${event.retry}\n')!
	}

	// Write event separator (empty line)
	ctx.writer.write_string('\n')!

	// Flush to ensure event is sent immediately
	ctx.writer.flush()!
}

// sleep - Pause execution for the specified milliseconds
pub fn (ctx StreamContext) sleep(ms int) {
	time.sleep(ms * time.millisecond)
}

// pipe - Pipe data from a byte array to the stream
pub fn (mut ctx StreamContext) pipe(data []u8) ! {
	ctx.write(data)!
}

// on_abort - Register a callback to be called when the client aborts the connection
pub fn (mut ctx StreamContext) on_abort(callback fn ()) {
	ctx.abort_fn = callback
}

// close - Close the stream
pub fn (mut ctx StreamContext) close() {
	if !ctx.is_closed {
		ctx.is_closed = true
		ctx.writer.close() or {}
	}
}

// is_open - Check if the stream is still open
pub fn (ctx StreamContext) is_open() bool {
	return !ctx.is_closed && ctx.writer.is_connected()
}

// trigger_abort - Internal method to trigger the abort callback
// Called by server backends when client disconnects
pub fn (mut ctx StreamContext) trigger_abort() {
	if abort_callback := ctx.abort_fn {
		abort_callback()
	}
	ctx.is_closed = true
}


// ============================================================================
// Picoev StreamWriter Implementation
// ============================================================================

// PicoevStreamWriter - StreamWriter implementation for picoev server
// Supports chunked transfer encoding for streaming responses
// Uses direct socket fd writes for immediate data delivery (true streaming)
@[heap]
pub struct PicoevStreamWriter {
mut:
	fd        int  // Socket file descriptor for direct writes
	connected bool
}

// PicoevStreamWriter.new - Create a new PicoevStreamWriter with the given response
// Extracts the fd from picohttpparser.Response for direct socket writes
pub fn PicoevStreamWriter.new(res &picohttpparser.Response) &PicoevStreamWriter {
	return &PicoevStreamWriter{
		fd: res.fd
		connected: true
	}
}

// write - Write raw bytes to the stream using chunked transfer encoding
// Format: {hex_size}\r\n{data}\r\n
// Writes directly to socket fd for immediate delivery
pub fn (mut w PicoevStreamWriter) write(data []u8) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := format_chunk_size(data.len)
	// Write directly to socket fd
	w.write_to_fd(chunk_header.bytes())!
	w.write_to_fd(data)!
	w.write_to_fd('\r\n'.bytes())!
}

// write_string - Write a string to the stream using chunked transfer encoding
pub fn (mut w PicoevStreamWriter) write_string(data string) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := format_chunk_size(data.len)
	// Write directly to socket fd
	w.write_to_fd(chunk_header.bytes())!
	w.write_to_fd(data.bytes())!
	w.write_to_fd('\r\n'.bytes())!
}

// write_to_fd - Write bytes directly to the socket file descriptor
// This ensures immediate delivery without buffering
@[inline]
fn (mut w PicoevStreamWriter) write_to_fd(data []u8) ! {
	if data.len == 0 {
		return
	}
	mut total_written := 0
	for total_written < data.len {
		remaining := data.len - total_written
		ptr := unsafe { &u8(data.data) + total_written }
		written := C.send(w.fd, ptr, remaining, 0)
		if written < 0 {
			w.connected = false
			return error('Failed to write to socket')
		}
		if written == 0 {
			w.connected = false
			return error('Connection closed by peer')
		}
		total_written += written
	}
}

// flush - Flush the buffer (direct fd writes are already unbuffered)
pub fn (mut w PicoevStreamWriter) flush() ! {
	// Direct fd writes are unbuffered, no explicit flush needed
	// But we can use TCP_NODELAY to disable Nagle's algorithm if needed
}

// close - Close the stream by sending the final chunk
// Final chunk format: 0\r\n\r\n
pub fn (mut w PicoevStreamWriter) close() ! {
	if w.connected {
		// Write the final chunk (zero-length chunk) to signal end of stream
		w.write_to_fd('0\r\n\r\n'.bytes()) or {}
		w.connected = false
		// Note: Don't close the fd here, picoev manages the connection lifecycle
	}
}

// is_connected - Check if the connection is still active
pub fn (w PicoevStreamWriter) is_connected() bool {
	return w.connected
}

// ============================================================================
// uSockets StreamWriter Implementation
// ============================================================================

// UsocketsStreamWriter - StreamWriter implementation for uSockets server
// Supports chunked transfer encoding for streaming responses
@[heap]
pub struct UsocketsStreamWriter {
mut:
	socket    usockets.Socket
	connected bool
}

// UsocketsStreamWriter.new - Create a new UsocketsStreamWriter with the given socket
pub fn UsocketsStreamWriter.new(socket usockets.Socket) &UsocketsStreamWriter {
	return &UsocketsStreamWriter{
		socket: socket
		connected: true
	}
}

// write - Write raw bytes to the stream using chunked transfer encoding
// Format: {hex_size}\r\n{data}\r\n
pub fn (mut w UsocketsStreamWriter) write(data []u8) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := format_chunk_size(data.len)
	w.socket.write_bytes(chunk_header)
	w.socket.write_bytes(data.bytestr())
	w.socket.write_bytes('\r\n')
}

// write_string - Write a string to the stream using chunked transfer encoding
pub fn (mut w UsocketsStreamWriter) write_string(data string) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := format_chunk_size(data.len)
	w.socket.write_bytes(chunk_header)
	w.socket.write_bytes(data)
	w.socket.write_bytes('\r\n')
}

// flush - Flush the buffer (uSockets handles this automatically)
pub fn (mut w UsocketsStreamWriter) flush() ! {
	// uSockets automatically flushes data
	// No explicit flush needed
}

// close - Close the stream by sending the final chunk
// Final chunk format: 0\r\n\r\n
pub fn (mut w UsocketsStreamWriter) close() ! {
	if w.connected {
		// Write the final chunk (zero-length chunk) to signal end of stream
		w.socket.write_bytes('0\r\n\r\n')
		w.connected = false
	}
}

// is_connected - Check if the connection is still active
pub fn (w UsocketsStreamWriter) is_connected() bool {
	return w.connected
}

// mark_disconnected - Mark the connection as disconnected
// Called by server backends when client disconnects
pub fn (mut w UsocketsStreamWriter) mark_disconnected() {
	w.connected = false
}

// ============================================================================
// Helper Functions for Chunked Encoding
// ============================================================================

// format_chunk_size - Format the chunk size as hex followed by CRLF
// This is used for HTTP chunked transfer encoding
@[inline]
fn format_chunk_size(size int) string {
	return '${size:x}\r\n'
}

// format_chunk - Format a complete chunk with size, data, and trailing CRLF
// Returns the full chunk in chunked transfer encoding format
pub fn format_chunk(data []u8) string {
	if data.len == 0 {
		return ''
	}
	return '${data.len:x}\r\n${data.bytestr()}\r\n'
}

// format_chunk_string - Format a string as a complete chunk
pub fn format_chunk_string(data string) string {
	if data.len == 0 {
		return ''
	}
	return '${data.len:x}\r\n${data}\r\n'
}

// format_final_chunk - Return the final chunk marker for chunked encoding
pub fn format_final_chunk() string {
	return '0\r\n\r\n'
}

// ============================================================================
// Streaming Helper Functions
// ============================================================================

// StreamCallback - Callback function type for streaming
// The callback receives a mutable StreamContext and can write data to the stream
pub type StreamCallback = fn (mut StreamContext) !

// StreamErrorHandler - Error handler function type for streaming
// Called when an error occurs during streaming
pub type StreamErrorHandler = fn (err IError, mut ctx StreamContext)

// StreamResponse - Response type for streaming operations
// Contains the headers that should be sent before streaming begins
pub struct StreamResponse {
pub:
	status_code int = 200
	headers     map[string]string
	is_stream   bool = true
}

// stream - Basic binary streaming function
// Sets Transfer-Encoding: chunked and executes the callback with a StreamContext
// 
// Parameters:
//   writer: The StreamWriter implementation (PicoevStreamWriter or UsocketsStreamWriter)
//   callback: The callback function that writes data to the stream
//   error_handler: Optional error handler called if an error occurs
//
// Returns:
//   StreamResponse with the appropriate headers
//
// Example:
//   stream(writer, fn (mut stream) ! {
//       stream.write('Hello'.bytes())!
//       stream.sleep(100)
//       stream.write('World'.bytes())!
//   })
pub fn stream(mut writer StreamWriter, callback StreamCallback, error_handler ...StreamErrorHandler) StreamResponse {
	// Create StreamContext with the writer
	mut ctx := StreamContext.new(writer)
	
	// Execute the callback and handle errors
	callback(mut ctx) or {
		// Handle error
		if error_handler.len > 0 {
			// Call custom error handler
			error_handler[0](err, mut ctx)
		} else {
			// Default: log error to console
			eprintln('[SSE Stream Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	ctx.close()
	
	// Return response headers for streaming
	return StreamResponse{
		status_code: 200
		headers: {
			'Transfer-Encoding': 'chunked'
			'Connection':        'keep-alive'
		}
		is_stream: true
	}
}

// stream_with_headers - Stream with custom initial headers
// Allows setting additional headers before streaming begins
pub fn stream_with_headers(mut writer StreamWriter, headers map[string]string, callback StreamCallback, error_handler ...StreamErrorHandler) StreamResponse {
	// Create StreamContext with the writer
	mut ctx := StreamContext.new(writer)
	
	// Execute the callback and handle errors
	callback(mut ctx) or {
		// Handle error
		if error_handler.len > 0 {
			// Call custom error handler
			error_handler[0](err, mut ctx)
		} else {
			// Default: log error to console
			eprintln('[SSE Stream Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	ctx.close()
	
	// Merge headers with required streaming headers
	mut response_headers := headers.clone()
	response_headers['Transfer-Encoding'] = 'chunked'
	if 'Connection' !in response_headers {
		response_headers['Connection'] = 'keep-alive'
	}
	
	return StreamResponse{
		status_code: 200
		headers: response_headers
		is_stream: true
	}
}

// get_stream_headers - Get the headers required for basic streaming
// Returns a map of headers that should be set for chunked transfer encoding
pub fn get_stream_headers() map[string]string {
	return {
		'Transfer-Encoding': 'chunked'
		'Connection':        'keep-alive'
	}
}

// write_stream_headers - Write HTTP headers for streaming response
// This is a helper function to write the initial HTTP response line and headers
// before starting chunked data transfer
//
// Parameters:
//   writer: The StreamWriter to write headers to
//   status_code: HTTP status code (default 200)
//   headers: Map of header name to value
pub fn write_stream_headers(mut writer StreamWriter, status_code int, headers map[string]string) ! {
	// Build HTTP response line
	status_text := get_status_text(status_code)
	mut response := 'HTTP/1.1 ${status_code} ${status_text}\r\n'
	
	// Add headers
	for key, value in headers {
		response += '${key}: ${value}\r\n'
	}
	
	// Add required streaming headers if not present
	if 'Transfer-Encoding' !in headers {
		response += 'Transfer-Encoding: chunked\r\n'
	}
	if 'Connection' !in headers {
		response += 'Connection: keep-alive\r\n'
	}
	
	// End headers section
	response += '\r\n'
	
	// Write headers directly (not chunked)
	// Note: Headers are written raw, not using chunked encoding
	// The chunked encoding starts after the headers
	writer.write_string(response)!
}

// stream_text - Text streaming function
// Sets Content-Type: text/plain; charset=utf-8, Transfer-Encoding: chunked,
// and X-Content-Type-Options: nosniff headers, then executes the callback
// with a StreamContext for text streaming.
//
// Parameters:
//   writer: The StreamWriter implementation (PicoevStreamWriter or UsocketsStreamWriter)
//   callback: The callback function that writes text data to the stream
//   error_handler: Optional error handler called if an error occurs
//
// Returns:
//   StreamResponse with the appropriate headers for text streaming
//
// Example:
//   stream_text(writer, fn (mut stream) ! {
//       stream.write_string('Hello ')!
//       stream.sleep(100)
//       stream.writeln('World')!
//   })
pub fn stream_text(mut writer StreamWriter, callback StreamCallback, error_handler ...StreamErrorHandler) StreamResponse {
	// Create StreamContext with the writer
	mut ctx := StreamContext.new(writer)
	
	// Execute the callback and handle errors
	callback(mut ctx) or {
		// Handle error
		if error_handler.len > 0 {
			// Call custom error handler
			error_handler[0](err, mut ctx)
		} else {
			// Default: log error to console
			eprintln('[SSE StreamText Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	ctx.close()
	
	// Return response headers for text streaming
	return StreamResponse{
		status_code: 200
		headers: {
			'Content-Type':           'text/plain; charset=utf-8'
			'Transfer-Encoding':      'chunked'
			'X-Content-Type-Options': 'nosniff'
			'Connection':             'keep-alive'
		}
		is_stream: true
	}
}

// get_stream_text_headers - Get the headers required for text streaming
// Returns a map of headers that should be set for text streaming with chunked transfer encoding
pub fn get_stream_text_headers() map[string]string {
	return {
		'Content-Type':           'text/plain; charset=utf-8'
		'Transfer-Encoding':      'chunked'
		'X-Content-Type-Options': 'nosniff'
		'Connection':             'keep-alive'
	}
}

// stream_sse - Server-Sent Events streaming function
// Sets Content-Type: text/event-stream, Cache-Control: no-cache,
// and Connection: keep-alive headers, then executes the callback
// with a StreamContext for SSE streaming.
//
// Parameters:
//   writer: The StreamWriter implementation (PicoevStreamWriter or UsocketsStreamWriter)
//   callback: The callback function that writes SSE events to the stream
//   error_handler: Optional error handler called if an error occurs
//
// Returns:
//   StreamResponse with the appropriate headers for SSE streaming
//
// Example:
//   stream_sse(writer, fn (mut stream) ! {
//       stream.write_sse(SSEEvent{
//           data: 'Hello World'
//           event: 'message'
//           id: '1'
//       })!
//       stream.sleep(1000)
//       stream.write_sse(SSEEvent{
//           data: 'Another message'
//           event: 'update'
//           id: '2'
//       })!
//   })
pub fn stream_sse(mut writer StreamWriter, callback StreamCallback, error_handler ...StreamErrorHandler) StreamResponse {
	// Create StreamContext with the writer
	mut ctx := StreamContext.new(writer)
	
	// Execute the callback and handle errors
	callback(mut ctx) or {
		// Handle error
		if error_handler.len > 0 {
			// Call custom error handler
			error_handler[0](err, mut ctx)
		} else {
			// Default: log error to console
			eprintln('[SSE StreamSSE Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	ctx.close()
	
	// Return response headers for SSE streaming
	// Requirements 3.1, 3.2, 3.3:
	// - Content-Type: text/event-stream
	// - Cache-Control: no-cache
	// - Connection: keep-alive
	return StreamResponse{
		status_code: 200
		headers: {
			'Content-Type':      'text/event-stream'
			'Cache-Control':     'no-cache'
			'Connection':        'keep-alive'
			'Transfer-Encoding': 'chunked'
		}
		is_stream: true
	}
}

// get_stream_sse_headers - Get the headers required for SSE streaming
// Returns a map of headers that should be set for Server-Sent Events streaming
pub fn get_stream_sse_headers() map[string]string {
	return {
		'Content-Type':      'text/event-stream'
		'Cache-Control':     'no-cache'
		'Connection':        'keep-alive'
		'Transfer-Encoding': 'chunked'
	}
}


// ============================================================================
// Context-Based Streaming Functions
// ============================================================================
// These functions are designed to be used in route handlers and integrate
// with the picoev and uSockets server backends.

// StreamType - Type of streaming response
pub enum StreamType {
	basic    // Basic binary streaming
	text     // Text streaming with text/plain content type
	sse      // Server-Sent Events streaming
}

// StreamConfig - Configuration stored in Context for streaming responses
// This is used internally by the server backends to detect and handle streaming
pub struct StreamConfig {
pub:
	stream_type   StreamType
	callback      StreamCallback = unsafe { nil }
	error_handler ?StreamErrorHandler
}

// Global storage for stream callbacks (workaround for V's limitations with storing functions in maps)
// Key is a unique identifier stored in Context.store['_stream_id']
// Using shared map for thread-safe access
struct StreamCallbackStorage {
mut:
	callbacks shared map[string]StreamConfig
}

// Module-level storage instance
const stream_storage = &StreamCallbackStorage{}

// store_stream_config - Store a stream configuration
fn store_stream_config(id string, config StreamConfig) {
	lock stream_storage.callbacks {
		stream_storage.callbacks[id] = config
	}
}

// retrieve_stream_config - Retrieve a stream configuration by ID
fn retrieve_stream_config(id string) ?StreamConfig {
	rlock stream_storage.callbacks {
		if id in stream_storage.callbacks {
			return stream_storage.callbacks[id]
		}
	}
	return none
}

// remove_stream_config - Remove a stream configuration by ID
fn remove_stream_config(id string) {
	lock stream_storage.callbacks {
		stream_storage.callbacks.delete(id)
	}
}

// generate_stream_id - Generate a unique stream ID
fn generate_stream_id() string {
	return '${time.now().unix_milli()}_${rand_int()}'
}

// rand_int - Simple random integer generator
fn rand_int() int {
	return int(time.now().unix_nano() % 1000000)
}

// c_stream - Basic binary streaming function for use in route handlers
// Sets Transfer-Encoding: chunked and stores the callback for execution by the server backend
//
// Parameters:
//   c: The request Context
//   callback: The callback function that writes data to the stream
//   error_handler: Optional error handler called if an error occurs
//
// Returns:
//   http.Response with streaming marker headers
//
// Example:
//   app.get('/stream', fn (mut c hono.Context) http.Response {
//       return hono.c_stream(mut c, fn (mut stream hono.StreamContext) ! {
//           stream.write('Hello'.bytes())!
//           stream.sleep(100)
//           stream.write('World'.bytes())!
//       })
//   })
pub fn c_stream(mut c Context, callback StreamCallback, error_handler ...StreamErrorHandler) http.Response {
	// Generate unique stream ID
	stream_id := generate_stream_id()
	
	// Store stream configuration
	config := StreamConfig{
		stream_type: .basic
		callback: callback
		error_handler: if error_handler.len > 0 { error_handler[0] } else { none }
	}
	store_stream_config(stream_id, config)
	
	// Mark context as streaming
	c.store['_stream'] = 'true'
	c.store['_stream_id'] = stream_id
	c.store['_stream_type'] = 'basic'
	
	// Set streaming headers
	c.headers['Transfer-Encoding'] = 'chunked'
	c.headers['Connection'] = 'keep-alive'
	
	// Return a marker response (body will be ignored, streaming will be handled by server)
	mut headers := http.new_header()
	headers.add_custom('Transfer-Encoding', 'chunked') or {}
	headers.add_custom('Connection', 'keep-alive') or {}
	
	return http.Response{
		status_code: 200
		header: headers
		body: ''
	}
}

// c_stream_text - Text streaming function for use in route handlers
// Sets Content-Type: text/plain; charset=utf-8, Transfer-Encoding: chunked,
// and X-Content-Type-Options: nosniff headers
//
// Parameters:
//   c: The request Context
//   callback: The callback function that writes text data to the stream
//   error_handler: Optional error handler called if an error occurs
//
// Returns:
//   http.Response with streaming marker headers
//
// Example:
//   app.get('/stream-text', fn (mut c hono.Context) http.Response {
//       return hono.c_stream_text(mut c, fn (mut stream hono.StreamContext) ! {
//           stream.write_string('Hello ')!
//           stream.sleep(100)
//           stream.writeln('World')!
//       })
//   })
pub fn c_stream_text(mut c Context, callback StreamCallback, error_handler ...StreamErrorHandler) http.Response {
	// Generate unique stream ID
	stream_id := generate_stream_id()
	
	// Store stream configuration
	config := StreamConfig{
		stream_type: .text
		callback: callback
		error_handler: if error_handler.len > 0 { error_handler[0] } else { none }
	}
	store_stream_config(stream_id, config)
	
	// Mark context as streaming
	c.store['_stream'] = 'true'
	c.store['_stream_id'] = stream_id
	c.store['_stream_type'] = 'text'
	
	// Set streaming headers
	c.headers['Content-Type'] = 'text/plain; charset=utf-8'
	c.headers['Transfer-Encoding'] = 'chunked'
	c.headers['X-Content-Type-Options'] = 'nosniff'
	c.headers['Connection'] = 'keep-alive'
	
	// Return a marker response
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/plain; charset=utf-8') or {}
	headers.add_custom('Transfer-Encoding', 'chunked') or {}
	headers.add_custom('X-Content-Type-Options', 'nosniff') or {}
	headers.add_custom('Connection', 'keep-alive') or {}
	
	return http.Response{
		status_code: 200
		header: headers
		body: ''
	}
}

// c_stream_sse - Server-Sent Events streaming function for use in route handlers
// Sets Content-Type: text/event-stream, Cache-Control: no-cache,
// and Connection: keep-alive headers
//
// Parameters:
//   c: The request Context
//   callback: The callback function that writes SSE events to the stream
//   error_handler: Optional error handler called if an error occurs
//
// Returns:
//   http.Response with streaming marker headers
//
// Example:
//   app.get('/sse', fn (mut c hono.Context) http.Response {
//       return hono.c_stream_sse(mut c, fn (mut stream hono.StreamContext) ! {
//           stream.write_sse(hono.SSEEvent{
//               data: 'Hello World'
//               event: 'message'
//               id: '1'
//           })!
//           stream.sleep(1000)
//           stream.write_sse(hono.SSEEvent{
//               data: 'Another message'
//               event: 'update'
//               id: '2'
//           })!
//       })
//   })
pub fn c_stream_sse(mut c Context, callback StreamCallback, error_handler ...StreamErrorHandler) http.Response {
	// Generate unique stream ID
	stream_id := generate_stream_id()
	
	// Store stream configuration
	config := StreamConfig{
		stream_type: .sse
		callback: callback
		error_handler: if error_handler.len > 0 { error_handler[0] } else { none }
	}
	store_stream_config(stream_id, config)
	
	// Mark context as streaming
	c.store['_stream'] = 'true'
	c.store['_stream_id'] = stream_id
	c.store['_stream_type'] = 'sse'
	
	// Set SSE headers (Requirements 3.1, 3.2, 3.3)
	c.headers['Content-Type'] = 'text/event-stream'
	c.headers['Cache-Control'] = 'no-cache'
	c.headers['Connection'] = 'keep-alive'
	c.headers['Transfer-Encoding'] = 'chunked'
	
	// Return a marker response
	mut headers := http.new_header()
	headers.add_custom('Content-Type', 'text/event-stream') or {}
	headers.add_custom('Cache-Control', 'no-cache') or {}
	headers.add_custom('Connection', 'keep-alive') or {}
	headers.add_custom('Transfer-Encoding', 'chunked') or {}
	
	return http.Response{
		status_code: 200
		header: headers
		body: ''
	}
}

// is_streaming_response - Check if a Context represents a streaming response
// Used by server backends to detect streaming responses
pub fn is_streaming_response(ctx Context) bool {
	return '_stream' in ctx.store && ctx.store['_stream'] == 'true'
}

// get_stream_config - Get the stream configuration from Context
// Returns the StreamConfig if this is a streaming response, none otherwise
pub fn get_stream_config(ctx Context) ?StreamConfig {
	if !is_streaming_response(ctx) {
		return none
	}
	
	stream_id := ctx.store['_stream_id'] or { return none }
	return retrieve_stream_config(stream_id)
}

// cleanup_stream_config - Remove stream configuration after use
// Should be called by server backends after streaming is complete
pub fn cleanup_stream_config(ctx Context) {
	if stream_id := ctx.store['_stream_id'] {
		remove_stream_config(stream_id)
	}
}

// execute_stream - Execute a streaming response with the given writer
// This is the main entry point for server backends to handle streaming
//
// Parameters:
//   ctx: The request Context with streaming configuration
//   writer: The StreamWriter implementation for the server backend
//
// Returns:
//   true if streaming was executed, false if not a streaming response
pub fn execute_stream(ctx Context, mut writer StreamWriter) bool {
	config := get_stream_config(ctx) or { return false }
	
	// Create StreamContext with the writer
	mut stream_ctx := StreamContext.new(writer)
	
	// Execute the callback and handle errors
	config.callback(mut stream_ctx) or {
		// Handle error
		if error_handler := config.error_handler {
			error_handler(err, mut stream_ctx)
		} else {
			// Default: log error to console
			eprintln('[SSE Stream Error] ${err.msg()}')
		}
	}
	
	// Auto-close the stream when callback completes
	stream_ctx.close()
	
	// Cleanup the stored configuration
	cleanup_stream_config(ctx)
	
	return true
}
