// websocket.v - WebSocket Helper for v-hono
// Provides server-side WebSocket support with RFC 6455 compliance
module hono

import net.http
import crypto.sha1
import encoding.base64
import time

// ============================================================================
// WebSocket Constants
// ============================================================================

// WebSocket opcodes (RFC 6455)
pub const ws_opcode_continuation = u8(0x0)
pub const ws_opcode_text = u8(0x1)
pub const ws_opcode_binary = u8(0x2)
pub const ws_opcode_close = u8(0x8)
pub const ws_opcode_ping = u8(0x9)
pub const ws_opcode_pong = u8(0xA)

// WebSocket close codes (RFC 6455)
pub const ws_close_normal = 1000
pub const ws_close_going_away = 1001
pub const ws_close_protocol_error = 1002
pub const ws_close_unsupported_data = 1003
pub const ws_close_invalid_payload = 1007
pub const ws_close_policy_violation = 1008
pub const ws_close_message_too_big = 1009
pub const ws_close_internal_error = 1011

// WebSocket magic GUID for handshake (RFC 6455)
const ws_magic_guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

// ============================================================================
// WebSocket Options Configuration
// ============================================================================

// WebSocketOptions - Configuration options for WebSocket connections
pub struct WebSocketOptions {
pub:
	// Ping/Pong interval in milliseconds, 0 to disable
	ping_interval    int = 30000
	// Maximum message size in bytes
	max_message_size int = 1048576 // 1MB
	// Connection timeout in milliseconds
	timeout          int = 60000
	// Supported subprotocols list
	protocols        []string
}

// ============================================================================
// WebSocket Ready State
// ============================================================================

// WSReadyState - WebSocket connection state enumeration
pub enum WSReadyState {
	connecting = 0
	open       = 1
	closing    = 2
	closed     = 3
}

// ============================================================================
// WebSocket Events
// ============================================================================

// WSMessageEvent - Message event structure passed to on_message callback
pub struct WSMessageEvent {
pub:
	data       string // Message data (text)
	data_bytes []u8   // Message data (binary)
	is_binary  bool   // Whether this is a binary message
}

// WSCloseEvent - Close event structure passed to on_close callback
pub struct WSCloseEvent {
pub:
	code      int    // Close status code
	reason    string // Close reason
	was_clean bool   // Whether the close was clean
}

// ============================================================================
// WebSocket Event Handler Types
// ============================================================================

// WSOpenHandler - Handler type for WebSocket connection open event
pub type WSOpenHandler = fn (mut ws WSContext)

// WSMessageHandler - Handler type for WebSocket message received event
pub type WSMessageHandler = fn (event WSMessageEvent, mut ws WSContext)

// WSCloseHandler - Handler type for WebSocket connection close event
pub type WSCloseHandler = fn (event WSCloseEvent, mut ws WSContext)

// WSErrorHandler - Handler type for WebSocket error event
pub type WSErrorHandler = fn (error string, mut ws WSContext)

// WSEvents - WebSocket event handlers configuration
pub struct WSEvents {
pub:
	on_open    ?WSOpenHandler    // Called when connection is established
	on_message ?WSMessageHandler // Called when a message is received
	on_close   ?WSCloseHandler   // Called when connection is closed
	on_error   ?WSErrorHandler   // Called when an error occurs
}

// WSHandlerFactory - Factory function type that creates WSEvents from HTTP context
// This allows the handler to access HTTP context data (params, query, store) when setting up events
pub type WSHandlerFactory = fn (c Context) WSEvents

// ============================================================================
// WebSocket Frame Structure (Internal)
// ============================================================================

// WSFrame - Internal WebSocket frame representation
struct WSFrame {
pub:
	fin         bool   // Is this the final frame
	opcode      u8     // Operation code
	masked      bool   // Is the payload masked
	mask_key    [4]u8  // Masking key
	payload_len u64    // Payload length
	payload     []u8   // Payload data
}


// ============================================================================
// Connection State Change Event
// ============================================================================

// WSStateChangeEvent - Event structure for state change notifications
pub struct WSStateChangeEvent {
pub:
	previous_state WSReadyState // Previous connection state
	new_state      WSReadyState // New connection state
	timestamp      i64          // Unix timestamp of state change
}

// WSStateChangeHandler - Handler type for state change notifications
pub type WSStateChangeHandler = fn (event WSStateChangeEvent, mut ws WSContext)

// ============================================================================
// WebSocket Context
// ============================================================================

// WSContext - WebSocket context for connection operations
pub struct WSContext {
pub:
	http_ctx &Context           // Original HTTP context
	params   map[string]string  // Route parameters
	query    map[string]string  // Query parameters
	store    map[string]string  // Middleware store
pub mut:
	ready_state WSReadyState    // Connection state
	protocol    string          // Negotiated subprotocol
	socket      voidptr         // Underlying socket reference
	// Internal fields for frame handling
	send_fn     fn ([]u8) !     = unsafe { nil } // Function to send raw bytes
	close_fn    fn (int, string) ! = unsafe { nil } // Function to close connection
	// State change notification handler
	on_state_change ?WSStateChangeHandler
	// State transition history for debugging
	state_history []WSStateChangeEvent
	// Ping/Pong tracking
	ping_interval     int  // Ping interval in milliseconds (0 = disabled)
	last_ping_sent    i64  // Timestamp of last ping sent
	last_pong_received i64 // Timestamp of last pong received
	pong_timeout      int  // Pong timeout in milliseconds
	awaiting_pong     bool // Whether we're waiting for a pong response
}

// ============================================================================
// Connection State Machine
// ============================================================================

// Valid state transitions according to WebSocket protocol:
// connecting -> open (handshake successful)
// connecting -> closed (handshake failed)
// open -> closing (close initiated)
// open -> closed (abrupt close)
// closing -> closed (close handshake complete)

// is_valid_state_transition - Check if a state transition is valid
pub fn is_valid_state_transition(from WSReadyState, to WSReadyState) bool {
	match from {
		.connecting {
			// From connecting: can go to open (success) or closed (failure)
			return to == .open || to == .closed
		}
		.open {
			// From open: can go to closing (graceful) or closed (abrupt)
			return to == .closing || to == .closed
		}
		.closing {
			// From closing: can only go to closed
			return to == .closed
		}
		.closed {
			// From closed: no valid transitions
			return false
		}
	}
}

// transition_state - Safely transition to a new state with validation
// Returns true if transition was successful, false if invalid
pub fn (mut ws WSContext) transition_state(new_state WSReadyState) bool {
	old_state := ws.ready_state
	
	// Validate the transition
	if !is_valid_state_transition(old_state, new_state) {
		return false
	}
	
	// Perform the transition
	ws.ready_state = new_state
	
	// Create state change event
	event := WSStateChangeEvent{
		previous_state: old_state
		new_state: new_state
		timestamp: time.now().unix()
	}
	
	// Record in history
	ws.state_history << event
	
	// Notify handler if registered
	if handler := ws.on_state_change {
		handler(event, mut ws)
	}
	
	return true
}

// force_transition_state - Force a state transition without validation
// Use only for error recovery or testing scenarios
pub fn (mut ws WSContext) force_transition_state(new_state WSReadyState) {
	old_state := ws.ready_state
	ws.ready_state = new_state
	
	// Create state change event
	event := WSStateChangeEvent{
		previous_state: old_state
		new_state: new_state
		timestamp: time.now().unix()
	}
	
	// Record in history
	ws.state_history << event
	
	// Notify handler if registered
	if handler := ws.on_state_change {
		handler(event, mut ws)
	}
}

// get_state_history - Get the state transition history
pub fn (ws WSContext) get_state_history() []WSStateChangeEvent {
	return ws.state_history
}

// is_open - Check if connection is in open state
pub fn (ws WSContext) is_open() bool {
	return ws.ready_state == .open
}

// is_closed - Check if connection is closed or closing
pub fn (ws WSContext) is_closed() bool {
	return ws.ready_state == .closed || ws.ready_state == .closing
}

// can_send - Check if messages can be sent (only in open state)
pub fn (ws WSContext) can_send() bool {
	return ws.ready_state == .open
}

// set_state_change_handler - Register a handler for state change notifications
pub fn (mut ws WSContext) set_state_change_handler(handler WSStateChangeHandler) {
	ws.on_state_change = handler
}

// ============================================================================
// WebSocket Message Sending
// ============================================================================

// send - Send text message to the client
pub fn (mut ws WSContext) send(data string) ! {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	frame := encode_ws_frame(ws_opcode_text, data.bytes(), false)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(frame)!
	}
}

// send_bytes - Send binary message to the client
pub fn (mut ws WSContext) send_bytes(data []u8) ! {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	frame := encode_ws_frame(ws_opcode_binary, data, false)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(frame)!
	}
}

// send_json - Send JSON data to the client
// The data parameter should be a valid JSON string
pub fn (mut ws WSContext) send_json(data string) ! {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	// Send as text frame (JSON is text-based)
	frame := encode_ws_frame(ws_opcode_text, data.bytes(), false)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(frame)!
	}
}

// close - Initiate graceful WebSocket close handshake
pub fn (mut ws WSContext) close(code int, reason string) ! {
	if ws.ready_state == .closed || ws.ready_state == .closing {
		return
	}
	
	// Transition to closing state using state machine
	ws.transition_state(.closing)
	
	// Build and send close frame
	close_frame := build_close_frame(code, reason)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(close_frame) or {}
	}
	
	if ws.close_fn != unsafe { nil } {
		ws.close_fn(code, reason) or {}
	}
}

// ============================================================================
// Close Handshake Functions
// ============================================================================

// build_close_frame - Build a WebSocket close frame with status code and reason
pub fn build_close_frame(code int, reason string) []u8 {
	// Close frame payload: 2-byte status code + optional reason
	mut payload := []u8{cap: 2 + reason.len}
	payload << u8(code >> 8)
	payload << u8(code & 0xFF)
	if reason.len > 0 {
		payload << reason.bytes()
	}
	
	return encode_ws_frame(ws_opcode_close, payload, false)
}

// parse_close_frame - Parse a close frame payload to extract code and reason
pub fn parse_close_frame(payload []u8) (int, string) {
	mut code := ws_close_normal
	mut reason := ''
	
	if payload.len >= 2 {
		code = int(payload[0]) << 8 | int(payload[1])
		if payload.len > 2 {
			reason = payload[2..].bytestr()
		}
	}
	
	return code, reason
}

// is_valid_close_code - Check if a close code is valid according to RFC 6455
pub fn is_valid_close_code(code int) bool {
	// Valid close codes per RFC 6455:
	// 1000 - Normal closure
	// 1001 - Going away
	// 1002 - Protocol error
	// 1003 - Unsupported data
	// 1007 - Invalid frame payload data
	// 1008 - Policy violation
	// 1009 - Message too big
	// 1010 - Mandatory extension (client only)
	// 1011 - Internal server error
	// 3000-3999 - Reserved for libraries/frameworks
	// 4000-4999 - Reserved for private use
	
	// Invalid codes
	if code < 1000 {
		return false
	}
	if code >= 1004 && code <= 1006 {
		return false // Reserved, must not be used
	}
	if code >= 1012 && code <= 2999 {
		return false // Reserved for future use
	}
	if code > 4999 {
		return false // Out of range
	}
	
	return true
}

// handle_close_frame - Handle an incoming close frame and perform close handshake
// Returns the close event to be passed to the on_close callback
pub fn handle_close_frame(frame WSFrame, mut ws WSContext) WSCloseEvent {
	code, reason := parse_close_frame(frame.payload)
	
	// Determine if this was a clean close
	was_clean := is_valid_close_code(code)
	
	// If we're in open state, we need to send a close frame back (echo)
	if ws.ready_state == .open {
		// Transition to closing
		ws.transition_state(.closing)
		
		// Send close frame response (echo the code and reason)
		close_frame := build_close_frame(code, reason)
		if ws.send_fn != unsafe { nil } {
			ws.send_fn(close_frame) or {}
		}
	}
	
	// Transition to closed state
	ws.transition_state(.closed)
	
	return WSCloseEvent{
		code: code
		reason: reason
		was_clean: was_clean
	}
}

// initiate_close - Initiate a close handshake from the server side
// This sends a close frame and transitions to closing state
pub fn (mut ws WSContext) initiate_close(code int, reason string) ! {
	if ws.ready_state != .open {
		return error('Cannot initiate close: connection not open')
	}
	
	// Validate close code
	if !is_valid_close_code(code) {
		return error('Invalid close code: ${code}')
	}
	
	// Transition to closing state
	ws.transition_state(.closing)
	
	// Send close frame
	close_frame := build_close_frame(code, reason)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(close_frame)!
	}
}

// complete_close - Complete the close handshake after receiving close frame response
pub fn (mut ws WSContext) complete_close() {
	if ws.ready_state == .closing {
		ws.transition_state(.closed)
	}
}

// force_close - Force close the connection without handshake (for error scenarios)
pub fn (mut ws WSContext) force_close(code int, reason string) {
	// Force transition to closed state
	ws.force_transition_state(.closed)
	
	// Try to send close frame if possible
	close_frame := build_close_frame(code, reason)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(close_frame) or {}
	}
	
	// Call close function
	if ws.close_fn != unsafe { nil } {
		ws.close_fn(code, reason) or {}
	}
}

// ============================================================================
// Ping/Pong Handling
// ============================================================================

// send_ping - Send a ping frame to the client
// The payload is optional and will be echoed back in the pong response
pub fn (mut ws WSContext) send_ping(payload []u8) ! {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	// Ping payload must be 125 bytes or less per RFC 6455
	if payload.len > 125 {
		return error('Ping payload too large (max 125 bytes)')
	}
	
	frame := encode_ws_frame(ws_opcode_ping, payload, false)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(frame)!
	}
	
	// Track ping sent
	ws.last_ping_sent = time.now().unix()
	ws.awaiting_pong = true
}

// send_pong - Send a pong frame to the client
// The payload should match the ping payload received
pub fn (mut ws WSContext) send_pong(payload []u8) ! {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	// Pong payload must be 125 bytes or less per RFC 6455
	if payload.len > 125 {
		return error('Pong payload too large (max 125 bytes)')
	}
	
	frame := encode_ws_frame(ws_opcode_pong, payload, false)
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(frame)!
	}
}

// handle_ping - Handle an incoming ping frame by sending a pong response
// Returns the pong frame that was sent
pub fn (mut ws WSContext) handle_ping(payload []u8) ![]u8 {
	if ws.ready_state != .open {
		return error('WebSocket connection is not open')
	}
	
	// Build pong frame with same payload
	pong_frame := encode_ws_frame(ws_opcode_pong, payload, false)
	
	if ws.send_fn != unsafe { nil } {
		ws.send_fn(pong_frame)!
	}
	
	return pong_frame
}

// handle_pong - Handle an incoming pong frame
// Updates the last pong received timestamp and clears awaiting_pong flag
pub fn (mut ws WSContext) handle_pong(payload []u8) {
	ws.last_pong_received = time.now().unix()
	ws.awaiting_pong = false
}

// is_pong_timeout - Check if pong response has timed out
// Returns true if we're awaiting a pong and the timeout has elapsed
pub fn (ws WSContext) is_pong_timeout() bool {
	if !ws.awaiting_pong {
		return false
	}
	
	if ws.pong_timeout <= 0 {
		return false // No timeout configured
	}
	
	elapsed := time.now().unix() - ws.last_ping_sent
	timeout_seconds := ws.pong_timeout / 1000
	
	return elapsed > timeout_seconds
}

// should_send_ping - Check if it's time to send a ping based on the interval
pub fn (ws WSContext) should_send_ping() bool {
	if ws.ping_interval <= 0 {
		return false // Ping disabled
	}
	
	if ws.ready_state != .open {
		return false
	}
	
	// If we're already waiting for a pong, don't send another ping
	if ws.awaiting_pong {
		return false
	}
	
	// Check if enough time has passed since last ping
	elapsed := time.now().unix() - ws.last_ping_sent
	interval_seconds := ws.ping_interval / 1000
	
	return elapsed >= interval_seconds
}

// configure_ping - Configure ping/pong settings
pub fn (mut ws WSContext) configure_ping(interval int, timeout int) {
	ws.ping_interval = interval
	ws.pong_timeout = timeout
}

// build_ping_frame - Build a ping frame with optional payload
pub fn build_ping_frame(payload []u8) []u8 {
	return encode_ws_frame(ws_opcode_ping, payload, false)
}

// build_pong_frame - Build a pong frame with payload (should match ping payload)
pub fn build_pong_frame(payload []u8) []u8 {
	return encode_ws_frame(ws_opcode_pong, payload, false)
}

// is_ping_frame - Check if a frame is a ping frame
pub fn is_ping_frame(frame WSFrame) bool {
	return frame.opcode == ws_opcode_ping
}

// is_pong_frame - Check if a frame is a pong frame
pub fn is_pong_frame(frame WSFrame) bool {
	return frame.opcode == ws_opcode_pong
}

// get_context - Get the original HTTP context
pub fn (ws WSContext) get_context() &Context {
	return ws.http_ctx
}

// ============================================================================
// WebSocket Frame Encoding/Decoding
// ============================================================================

// encode_ws_frame - Encode a WebSocket frame
// opcode: frame type (text, binary, close, ping, pong)
// payload: frame payload data
// masked: whether to mask the payload (client->server frames must be masked)
pub fn encode_ws_frame(opcode u8, payload []u8, masked bool) []u8 {
	payload_len := payload.len
	mut frame := []u8{cap: 14 + payload_len} // Max header size + payload
	
	// First byte: FIN bit (1) + RSV (000) + opcode (4 bits)
	frame << u8(0x80 | (opcode & 0x0F))
	
	// Second byte: MASK bit + payload length
	mut mask_bit := u8(0)
	if masked {
		mask_bit = 0x80
	}
	
	if payload_len <= 125 {
		frame << mask_bit | u8(payload_len)
	} else if payload_len <= 65535 {
		frame << mask_bit | u8(126)
		frame << u8(payload_len >> 8)
		frame << u8(payload_len & 0xFF)
	} else {
		frame << mask_bit | u8(127)
		// 64-bit length (big-endian)
		for i := 7; i >= 0; i-- {
			frame << u8((payload_len >> (i * 8)) & 0xFF)
		}
	}
	
	// Add masking key and masked payload if masked
	if masked {
		mask_key := [u8(0x12), 0x34, 0x56, 0x78] // Simple mask key for testing
		frame << mask_key[0]
		frame << mask_key[1]
		frame << mask_key[2]
		frame << mask_key[3]
		
		for i, b in payload {
			frame << b ^ mask_key[i % 4]
		}
	} else {
		frame << payload
	}
	
	return frame
}

// decode_ws_frame - Decode a WebSocket frame
// Returns the decoded frame or an error if the frame is invalid
pub fn decode_ws_frame(data []u8) !WSFrame {
	if data.len < 2 {
		return error('Frame too short')
	}
	
	// Parse first byte
	fin := (data[0] & 0x80) != 0
	opcode := data[0] & 0x0F
	
	// Parse second byte
	masked := (data[1] & 0x80) != 0
	mut payload_len := u64(data[1] & 0x7F)
	mut offset := 2
	
	// Extended payload length
	if payload_len == 126 {
		if data.len < 4 {
			return error('Frame too short for extended length')
		}
		payload_len = u64(data[2]) << 8 | u64(data[3])
		offset = 4
	} else if payload_len == 127 {
		if data.len < 10 {
			return error('Frame too short for 64-bit length')
		}
		payload_len = 0
		for i := 0; i < 8; i++ {
			payload_len = (payload_len << 8) | u64(data[2 + i])
		}
		offset = 10
	}
	
	// Parse masking key
	mut mask_key := [4]u8{}
	if masked {
		if data.len < offset + 4 {
			return error('Frame too short for mask key')
		}
		mask_key[0] = data[offset]
		mask_key[1] = data[offset + 1]
		mask_key[2] = data[offset + 2]
		mask_key[3] = data[offset + 3]
		offset += 4
	}
	
	// Extract and unmask payload
	if data.len < offset + int(payload_len) {
		return error('Frame too short for payload')
	}
	
	mut payload := data[offset..offset + int(payload_len)].clone()
	if masked {
		for i := 0; i < payload.len; i++ {
			payload[i] = payload[i] ^ mask_key[i % 4]
		}
	}
	
	return WSFrame{
		fin: fin
		opcode: opcode
		masked: masked
		mask_key: mask_key
		payload_len: payload_len
		payload: payload
	}
}

// ============================================================================
// WebSocket Handshake
// ============================================================================

// compute_accept_key - Compute Sec-WebSocket-Accept from Sec-WebSocket-Key
// According to RFC 6455: base64(sha1(key + GUID))
pub fn compute_accept_key(key string) string {
	combined := key + ws_magic_guid
	hash := sha1.sum(combined.bytes())
	return base64.encode(hash)
}

// validate_upgrade_request - Validate WebSocket upgrade request headers
pub fn validate_upgrade_request(c Context) !string {
	// Check Upgrade header
	upgrade := c.req.header.get_custom('Upgrade') or {
		return error('Missing Upgrade header')
	}
	if upgrade.to_lower() != 'websocket' {
		return error('Invalid Upgrade header')
	}
	
	// Check Connection header
	connection := c.req.header.get_custom('Connection') or {
		return error('Missing Connection header')
	}
	if !connection.to_lower().contains('upgrade') {
		return error('Invalid Connection header')
	}
	
	// Check Sec-WebSocket-Key
	ws_key := c.req.header.get_custom('Sec-WebSocket-Key') or {
		return error('Missing Sec-WebSocket-Key header')
	}
	if ws_key.len == 0 {
		return error('Empty Sec-WebSocket-Key header')
	}
	
	// Check Sec-WebSocket-Version (must be 13)
	ws_version := c.req.header.get_custom('Sec-WebSocket-Version') or { '13' }
	if ws_version != '13' {
		return error('Unsupported WebSocket version')
	}
	
	return ws_key
}

// create_handshake_response - Create WebSocket handshake response
pub fn create_handshake_response(key string, protocol string) http.Response {
	accept_key := compute_accept_key(key)
	
	mut headers := http.new_header()
	headers.add_custom('Upgrade', 'websocket') or {}
	headers.add_custom('Connection', 'Upgrade') or {}
	headers.add_custom('Sec-WebSocket-Accept', accept_key) or {}
	
	if protocol.len > 0 {
		headers.add_custom('Sec-WebSocket-Protocol', protocol) or {}
	}
	
	return http.Response{
		status_code: 101
		header: headers
		body: ''
	}
}

// negotiate_subprotocol - Negotiate subprotocol from client request
pub fn negotiate_subprotocol(c Context, supported_protocols []string) string {
	if supported_protocols.len == 0 {
		return ''
	}
	
	// Get client's requested protocols
	client_protocols := c.req.header.get_custom('Sec-WebSocket-Protocol') or { '' }
	if client_protocols.len == 0 {
		return ''
	}
	
	// Parse comma-separated list
	requested := client_protocols.split(',').map(it.trim_space())
	
	// Find first matching protocol
	for proto in requested {
		if proto in supported_protocols {
			return proto
		}
	}
	
	return ''
}


// ============================================================================
// WebSocket Upgrade Handler
// ============================================================================

// upgrade_websocket - Create a WebSocket upgrade handler
// This function returns a middleware-compatible handler that performs the WebSocket upgrade
// and wires up the event callbacks from the factory function.
//
// Parameters:
//   factory: A function that receives the HTTP Context and returns WSEvents configuration
//   options: Optional WebSocket configuration (ping_interval, max_message_size, timeout, protocols)
//
// Returns:
//   A handler function compatible with v-hono's routing system
//
// Example:
//   app.get('/ws', upgrade_websocket(fn (c Context) WSEvents {
//       return WSEvents{
//           on_open: fn (mut ws WSContext) {
//               ws.send('Welcome!') or {}
//           }
//           on_message: fn (event WSMessageEvent, mut ws WSContext) {
//               ws.send('Echo: ${event.data}') or {}
//           }
//           on_close: fn (event WSCloseEvent, mut ws WSContext) {
//               println('Connection closed: ${event.code}')
//           }
//       }
//   }))
pub fn upgrade_websocket(factory WSHandlerFactory, options ...WebSocketOptions) fn (mut Context) http.Response {
	// Get options or use defaults
	opts := if options.len > 0 { options[0] } else { WebSocketOptions{} }
	
	return fn [factory, opts] (mut c Context) http.Response {
		// Validate the WebSocket upgrade request
		ws_key := validate_upgrade_request(c) or {
			// Return 400 Bad Request for invalid upgrade requests
			mut headers := http.new_header()
			headers.add_custom('Content-Type', 'text/plain') or {}
			return http.Response{
				status_code: 400
				header: headers
				body: 'Bad Request: ${err.msg()}'
			}
		}
		
		// Negotiate subprotocol if configured
		protocol := negotiate_subprotocol(c, opts.protocols)
		
		// Create WSContext with HTTP context data preserved
		mut ws_ctx := WSContext{
			http_ctx: unsafe { &c }
			params: c.params.clone()
			query: c.query.clone()
			store: c.store.clone()
			ready_state: .connecting
			protocol: protocol
			socket: unsafe { nil }
		}
		
		// Get event handlers from factory
		events := factory(c)
		
		// Create the handshake response
		response := create_handshake_response(ws_key, protocol)
		
		// Store WebSocket context and events in the HTTP context store for backend processing
		// The backend (picoev or uSockets) will retrieve these and handle the connection
		c.store['_ws_upgrade'] = 'true'
		c.store['_ws_key'] = ws_key
		c.store['_ws_protocol'] = protocol
		c.store['_ws_ping_interval'] = opts.ping_interval.str()
		c.store['_ws_max_message_size'] = opts.max_message_size.str()
		c.store['_ws_timeout'] = opts.timeout.str()
		
		// Transition to open state after handshake response is sent
		// Note: The actual state transition happens in the backend after sending the response
		ws_ctx.ready_state = .open
		
		// Invoke on_open callback if defined
		if on_open := events.on_open {
			on_open(mut ws_ctx)
		}
		
		return response
	}
}

// create_ws_context - Helper function to create a WSContext from an HTTP Context
// This is used internally by server backends when handling WebSocket connections
pub fn create_ws_context(c &Context, protocol string) WSContext {
	return WSContext{
		http_ctx: unsafe { c }
		params: c.params.clone()
		query: c.query.clone()
		store: c.store.clone()
		ready_state: .connecting
		protocol: protocol
		socket: unsafe { nil }
	}
}

// is_websocket_upgrade - Check if a request is a WebSocket upgrade request
// This helper function can be used by server backends to detect WebSocket upgrades
pub fn is_websocket_upgrade(c Context) bool {
	upgrade := c.req.header.get_custom('Upgrade') or { return false }
	if upgrade.to_lower() != 'websocket' {
		return false
	}
	
	connection := c.req.header.get_custom('Connection') or { return false }
	if !connection.to_lower().contains('upgrade') {
		return false
	}
	
	// Check for Sec-WebSocket-Key
	_ := c.req.header.get_custom('Sec-WebSocket-Key') or { return false }
	
	return true
}

// validate_message_size - Validate that a message does not exceed the configured maximum size
// Returns true if the message is within limits, false if it exceeds max_message_size
// If the message exceeds the limit, closes the connection with 1009 and invokes on_error
pub fn validate_message_size(frame WSFrame, max_message_size int, events WSEvents, mut ws WSContext) bool {
	// Only validate data frames (text and binary)
	if frame.opcode != ws_opcode_text && frame.opcode != ws_opcode_binary {
		return true
	}
	
	// Check if message size exceeds the limit
	if max_message_size > 0 && int(frame.payload_len) > max_message_size {
		// Invoke on_error callback
		error_msg := 'Message size ${frame.payload_len} exceeds maximum allowed size ${max_message_size}'
		if on_error := events.on_error {
			on_error(error_msg, mut ws)
		}
		
		// Close connection with 1009 (Message Too Big)
		ws.force_close(ws_close_message_too_big, 'Message too big')
		
		return false
	}
	
	return true
}

// process_ws_message - Process an incoming WebSocket message and invoke the appropriate callback
// This is used internally by server backends when handling incoming frames
pub fn process_ws_message(frame WSFrame, events WSEvents, mut ws WSContext) {
	match frame.opcode {
		ws_opcode_text {
			// Text message
			if on_message := events.on_message {
				event := WSMessageEvent{
					data: frame.payload.bytestr()
					data_bytes: frame.payload
					is_binary: false
				}
				on_message(event, mut ws)
			}
		}
		ws_opcode_binary {
			// Binary message
			if on_message := events.on_message {
				event := WSMessageEvent{
					data: ''
					data_bytes: frame.payload
					is_binary: true
				}
				on_message(event, mut ws)
			}
		}
		ws_opcode_close {
			// Handle close frame using the close handshake logic
			close_event := handle_close_frame(frame, mut ws)
			
			if on_close := events.on_close {
				on_close(close_event, mut ws)
			}
		}
		ws_opcode_ping {
			// Auto-respond to ping with pong (same payload) per RFC 6455
			ws.handle_ping(frame.payload) or {
				if on_error := events.on_error {
					on_error('Failed to send pong: ${err.msg()}', mut ws)
				}
			}
		}
		ws_opcode_pong {
			// Handle pong - update tracking for connection health
			ws.handle_pong(frame.payload)
		}
		else {
			// Unknown opcode - invoke error handler
			if on_error := events.on_error {
				on_error('Unknown opcode: ${frame.opcode}', mut ws)
			}
		}
	}
}

// handle_ws_error - Handle a WebSocket error and invoke the error callback
pub fn handle_ws_error(error_msg string, events WSEvents, mut ws WSContext) {
	if on_error := events.on_error {
		on_error(error_msg, mut ws)
	}
}

// process_ws_message_with_validation - Process an incoming WebSocket message with size validation
// This combines message size validation with message processing
// Returns true if the message was processed successfully, false if it was rejected due to size
pub fn process_ws_message_with_validation(frame WSFrame, max_message_size int, events WSEvents, mut ws WSContext) bool {
	// Validate message size first
	if !validate_message_size(frame, max_message_size, events, mut ws) {
		return false
	}
	
	// Process the message
	process_ws_message(frame, events, mut ws)
	return true
}
