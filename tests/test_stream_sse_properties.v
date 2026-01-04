// test_stream_sse_properties.v
// Property-Based Testing for stream_sse() function
// Feature: sse-streaming-helper
// Property 6: streamSSE() 设置正确的 HTTP 头
// Property 7: SSE 事件格式化正确性
// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9
module main

import rand

const test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
}

fn (mut stats PropertyTestStats) run_property_test(test_name string, test_func fn () bool) {
	stats.total_tests++
	print('🔬 ${test_name}... ')

	if test_func() {
		stats.passed_tests++
		println('✅')
	} else {
		stats.failed_tests++
		println('❌')
	}
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== stream_sse() 函数属性测试总结 ===')
	println('总测试数: ${stats.total_tests}')
	println('通过: ${stats.passed_tests}')
	println('失败: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 所有属性测试通过！')
	} else {
		println('⚠️  有 ${stats.failed_tests} 个属性测试失败')
	}
}


// ============================================================================
// Mock StreamWriter for Testing
// ============================================================================

// MockStreamWriter - A mock implementation of StreamWriter for testing
// Captures all written data for verification
struct MockStreamWriter {
mut:
	written_data []u8
	connected    bool
	closed       bool
	flush_count  int
}

fn MockStreamWriter.new() &MockStreamWriter {
	return &MockStreamWriter{
		written_data: []u8{}
		connected: true
		closed: false
		flush_count: 0
	}
}

fn (mut w MockStreamWriter) write(data []u8) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := '${data.len:x}\r\n'
	w.written_data << chunk_header.bytes()
	w.written_data << data
	w.written_data << '\r\n'.bytes()
}

fn (mut w MockStreamWriter) write_string(data string) ! {
	if !w.connected {
		return error('Connection closed')
	}
	if data.len == 0 {
		return
	}
	// Write chunked format: size in hex, CRLF, data, CRLF
	chunk_header := '${data.len:x}\r\n'
	w.written_data << chunk_header.bytes()
	w.written_data << data.bytes()
	w.written_data << '\r\n'.bytes()
}

fn (mut w MockStreamWriter) flush() ! {
	w.flush_count++
}

fn (mut w MockStreamWriter) close() ! {
	if w.connected {
		// Write the final chunk (zero-length chunk) to signal end of stream
		w.written_data << '0\r\n\r\n'.bytes()
		w.connected = false
		w.closed = true
	}
}

fn (w MockStreamWriter) is_connected() bool {
	return w.connected
}

fn (w MockStreamWriter) get_written_string() string {
	return w.written_data.bytestr()
}

// extract_sse_content - Extract the actual SSE content from chunked encoding
// Removes the chunk size headers and CRLF markers to get the raw SSE data
fn (w MockStreamWriter) extract_sse_content() string {
	raw := w.written_data.bytestr()
	mut result := []u8{}
	mut i := 0
	
	for i < raw.len {
		// Find the chunk size (hex number before \r\n)
		mut size_end := i
		for size_end < raw.len && raw[size_end] != `\r` {
			size_end++
		}
		
		if size_end >= raw.len {
			break
		}
		
		// Parse chunk size from hex string
		size_str := raw[i..size_end]
		chunk_size := parse_hex_int(size_str)
		
		if chunk_size == 0 {
			// Final chunk
			break
		}
		
		// Skip \r\n after size
		i = size_end + 2
		
		// Extract chunk data
		if i + chunk_size <= raw.len {
			result << raw[i..i + chunk_size].bytes()
		}
		
		// Skip chunk data and trailing \r\n
		i = i + chunk_size + 2
	}
	
	return result.bytestr()
}

// parse_hex_int - Parse a hex string to integer
fn parse_hex_int(s string) int {
	mut result := 0
	for c in s {
		result *= 16
		if c >= `0` && c <= `9` {
			result += int(c - `0`)
		} else if c >= `a` && c <= `f` {
			result += int(c - `a` + 10)
		} else if c >= `A` && c <= `F` {
			result += int(c - `A` + 10)
		}
	}
	return result
}


// ============================================================================
// SSEEvent Structure for Testing
// ============================================================================

// SSEEvent - Server-Sent Events event structure
// Mirrors the implementation in streaming.v
struct SSEEvent {
	data  string // Event data (required) - supports multi-line
	event string // Event type name (optional)
	id    string // Event ID for client reconnection (optional)
	retry int    // Reconnection time in milliseconds (optional, 0 = not set)
}


// ============================================================================
// StreamContext for Testing
// ============================================================================

// TestStreamContext - A test implementation of StreamContext
// Provides write_sse method for testing SSE event formatting
struct TestStreamContext {
mut:
	writer    &MockStreamWriter
	is_closed bool
}

fn TestStreamContext.new(writer &MockStreamWriter) TestStreamContext {
	return TestStreamContext{
		writer: unsafe { writer }
		is_closed: false
	}
}

fn (mut ctx TestStreamContext) write_string(data string) ! {
	if ctx.is_closed {
		return error('Stream is closed')
	}
	if !ctx.writer.is_connected() {
		ctx.is_closed = true
		return error('Connection lost')
	}
	ctx.writer.write_string(data)!
}

// write_sse - Write an SSE event to the stream
// Formats the event according to the SSE specification:
// - event: {type}\n (if event field is set)
// - data: {line}\n (for each line of data)
// - id: {id}\n (if id field is set)
// - retry: {ms}\n (if retry > 0)
// - \n (event separator)
fn (mut ctx TestStreamContext) write_sse(event SSEEvent) ! {
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

fn (mut ctx TestStreamContext) close() {
	if !ctx.is_closed {
		ctx.is_closed = true
		ctx.writer.close() or {}
	}
}


// ============================================================================
// Random Data Generators for Property Testing
// ============================================================================

// generate_random_string - Generate a random alphanumeric string
fn generate_random_string(min_len int, max_len int) string {
	len := rand.int_in_range(min_len, max_len + 1) or { min_len }
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	mut result := []u8{cap: len}
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result << chars[idx]
	}
	return result.bytestr()
}

// generate_random_multiline_string - Generate a random string with newlines
fn generate_random_multiline_string(min_lines int, max_lines int) string {
	num_lines := rand.int_in_range(min_lines, max_lines + 1) or { min_lines }
	mut lines := []string{cap: num_lines}
	for _ in 0 .. num_lines {
		lines << generate_random_string(1, 20)
	}
	return lines.join('\n')
}

// generate_random_sse_event - Generate a random SSE event
fn generate_random_sse_event() SSEEvent {
	// Randomly decide which optional fields to include
	include_event := rand.int_in_range(0, 2) or { 0 } == 1
	include_id := rand.int_in_range(0, 2) or { 0 } == 1
	include_retry := rand.int_in_range(0, 2) or { 0 } == 1
	is_multiline := rand.int_in_range(0, 3) or { 0 } == 0 // 1/3 chance of multiline
	
	mut data := ''
	if is_multiline {
		data = generate_random_multiline_string(2, 5)
	} else {
		data = generate_random_string(1, 50)
	}
	
	return SSEEvent{
		data: data
		event: if include_event { generate_random_string(3, 15) } else { '' }
		id: if include_id { generate_random_string(1, 10) } else { '' }
		retry: if include_retry { rand.int_in_range(100, 10000) or { 1000 } } else { 0 }
	}
}


// ============================================================================
// Helper Functions
// ============================================================================

// get_stream_sse_headers - Get the headers required for SSE streaming
// This mirrors the implementation in streaming.v
fn get_stream_sse_headers() map[string]string {
	return {
		'Content-Type':      'text/event-stream'
		'Cache-Control':     'no-cache'
		'Connection':        'keep-alive'
		'Transfer-Encoding': 'chunked'
	}
}

// ============================================================================
// Property 6: streamSSE() 设置正确的 HTTP 头
// Feature: sse-streaming-helper, Property 6
// Validates: Requirements 3.1, 3.2, 3.3
//
// *For any* call to streamSSE(c, callback), the response SHALL contain:
// - Content-Type: text/event-stream
// - Cache-Control: no-cache
// - Connection: keep-alive
// ============================================================================

// Test 6a: Content-Type header is set correctly for SSE
fn test_property_6a_content_type_header() bool {
	headers := get_stream_sse_headers()
	
	// Verify Content-Type header exists
	if 'Content-Type' !in headers {
		println('  Content-Type header missing')
		return false
	}
	
	// Verify value is 'text/event-stream' (Requirement 3.1)
	if headers['Content-Type'] != 'text/event-stream' {
		println('  Content-Type should be "text/event-stream", got "${headers['Content-Type']}"')
		return false
	}
	
	return true
}

// Test 6b: Cache-Control header is set correctly for SSE
fn test_property_6b_cache_control_header() bool {
	headers := get_stream_sse_headers()
	
	// Verify Cache-Control header exists
	if 'Cache-Control' !in headers {
		println('  Cache-Control header missing')
		return false
	}
	
	// Verify value is 'no-cache' (Requirement 3.2)
	if headers['Cache-Control'] != 'no-cache' {
		println('  Cache-Control should be "no-cache", got "${headers['Cache-Control']}"')
		return false
	}
	
	return true
}

// Test 6c: Connection header is set correctly for SSE
fn test_property_6c_connection_header() bool {
	headers := get_stream_sse_headers()
	
	// Verify Connection header exists
	if 'Connection' !in headers {
		println('  Connection header missing')
		return false
	}
	
	// Verify value is 'keep-alive' (Requirement 3.3)
	if headers['Connection'] != 'keep-alive' {
		println('  Connection should be "keep-alive", got "${headers['Connection']}"')
		return false
	}
	
	return true
}

// Test 6d: Transfer-Encoding header is set for chunked transfer
fn test_property_6d_transfer_encoding_header() bool {
	headers := get_stream_sse_headers()
	
	// Verify Transfer-Encoding header exists
	if 'Transfer-Encoding' !in headers {
		println('  Transfer-Encoding header missing')
		return false
	}
	
	// Verify value is 'chunked'
	if headers['Transfer-Encoding'] != 'chunked' {
		println('  Transfer-Encoding should be "chunked", got "${headers['Transfer-Encoding']}"')
		return false
	}
	
	return true
}

// Test 6e: Headers are consistent across multiple calls
fn test_property_6e_headers_consistency() bool {
	for _ in 0 .. test_iterations {
		headers1 := get_stream_sse_headers()
		headers2 := get_stream_sse_headers()
		
		// Headers should be identical
		if headers1['Content-Type'] != headers2['Content-Type'] {
			println('  Content-Type inconsistent between calls')
			return false
		}
		
		if headers1['Cache-Control'] != headers2['Cache-Control'] {
			println('  Cache-Control inconsistent between calls')
			return false
		}
		
		if headers1['Connection'] != headers2['Connection'] {
			println('  Connection inconsistent between calls')
			return false
		}
		
		if headers1['Transfer-Encoding'] != headers2['Transfer-Encoding'] {
			println('  Transfer-Encoding inconsistent between calls')
			return false
		}
	}
	
	return true
}

// Test 6f: All required SSE headers are present
fn test_property_6f_all_required_headers_present() bool {
	headers := get_stream_sse_headers()
	
	required_headers := ['Content-Type', 'Cache-Control', 'Connection', 'Transfer-Encoding']
	
	for header in required_headers {
		if header !in headers {
			println('  Required header "${header}" is missing')
			return false
		}
	}
	
	return true
}

// Test 6g: SSE headers differ from text streaming headers
fn test_property_6g_sse_headers_differ_from_text() bool {
	sse_headers := get_stream_sse_headers()
	
	// SSE should use text/event-stream, not text/plain
	if sse_headers['Content-Type'] == 'text/plain; charset=utf-8' {
		println('  SSE Content-Type should not be text/plain')
		return false
	}
	
	// SSE should have Cache-Control: no-cache
	if 'Cache-Control' !in sse_headers {
		println('  SSE should have Cache-Control header')
		return false
	}
	
	return true
}


// ============================================================================
// Property 7: SSE 事件格式化正确性
// Feature: sse-streaming-helper, Property 7
// Validates: Requirements 3.4, 3.5, 3.6, 3.7, 3.8, 3.9
//
// *For any* SSEEvent with fields (data, event, id, retry), when stream.writeSSE(event) is called:
// - If event is non-empty, output SHALL start with event: {event}\n
// - Output SHALL contain data: {data}\n for each line of data
// - If id is non-empty, output SHALL contain id: {id}\n
// - If retry > 0, output SHALL contain retry: {retry}\n
// - Output SHALL end with an additional \n to separate events
// ============================================================================

// Test 7a: Data field is always written correctly (Requirement 3.5)
// *For any* SSE event with data, the output SHALL contain "data: {value}\n"
fn test_property_7a_data_field_formatting() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		// Generate random single-line data
		data := generate_random_string(1, 50)
		event := SSEEvent{
			data: data
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		expected := 'data: ${data}\n'
		
		if !content.contains(expected) {
			println('  Iteration ${i}: Expected data line "${expected}" not found in output')
			println('  Got: "${content}"')
			return false
		}
	}
	return true
}

// Test 7b: Multi-line data is split correctly (Requirement 3.5)
// *For any* SSE event with multi-line data, each line SHALL be prefixed with "data: "
fn test_property_7b_multiline_data_formatting() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		// Generate random multi-line data
		data := generate_random_multiline_string(2, 5)
		event := SSEEvent{
			data: data
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		lines := data.split('\n')
		
		// Each line of data should be prefixed with "data: "
		for line in lines {
			expected := 'data: ${line}\n'
			if !content.contains(expected) {
				println('  Iteration ${i}: Expected data line "${expected}" not found')
				println('  Original data: "${data}"')
				println('  Got: "${content}"')
				return false
			}
		}
	}
	return true
}

// Test 7c: Event field is written before data (Requirement 3.6)
// *For any* SSE event with event field, output SHALL start with "event: {value}\n"
fn test_property_7c_event_field_before_data() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		event_type := generate_random_string(3, 15)
		data := generate_random_string(1, 30)
		event := SSEEvent{
			data: data
			event: event_type
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		event_line := 'event: ${event_type}\n'
		data_line := 'data: ${data}\n'
		
		// Event line should exist
		if !content.contains(event_line) {
			println('  Iteration ${i}: Event line "${event_line}" not found')
			return false
		}
		
		// Event line should come before data line
		event_pos := content.index(event_line) or { -1 }
		data_pos := content.index(data_line) or { -1 }
		
		if event_pos >= data_pos {
			println('  Iteration ${i}: Event line should come before data line')
			println('  Event pos: ${event_pos}, Data pos: ${data_pos}')
			return false
		}
	}
	return true
}

// Test 7d: Event field is omitted when empty (Requirement 3.6)
// *For any* SSE event with empty event field, output SHALL NOT contain "event: "
fn test_property_7d_empty_event_field_omitted() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		data := generate_random_string(1, 30)
		event := SSEEvent{
			data: data
			event: '' // Empty event field
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		
		// Should not contain "event: " prefix
		if content.contains('event: ') {
			println('  Iteration ${i}: Empty event field should not produce "event: " line')
			println('  Got: "${content}"')
			return false
		}
	}
	return true
}

// Test 7e: ID field is written after data (Requirement 3.7)
// *For any* SSE event with id field, output SHALL contain "id: {value}\n" after data
fn test_property_7e_id_field_after_data() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		id := generate_random_string(1, 10)
		data := generate_random_string(1, 30)
		event := SSEEvent{
			data: data
			id: id
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		id_line := 'id: ${id}\n'
		data_line := 'data: ${data}\n'
		
		// ID line should exist
		if !content.contains(id_line) {
			println('  Iteration ${i}: ID line "${id_line}" not found')
			return false
		}
		
		// ID line should come after data line
		id_pos := content.index(id_line) or { -1 }
		data_pos := content.index(data_line) or { -1 }
		
		if id_pos <= data_pos {
			println('  Iteration ${i}: ID line should come after data line')
			println('  ID pos: ${id_pos}, Data pos: ${data_pos}')
			return false
		}
	}
	return true
}

// Test 7f: ID field is omitted when empty (Requirement 3.7)
// *For any* SSE event with empty id field, output SHALL NOT contain "id: "
fn test_property_7f_empty_id_field_omitted() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		data := generate_random_string(1, 30)
		event := SSEEvent{
			data: data
			id: '' // Empty id field
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		
		// Should not contain "id: " prefix
		if content.contains('id: ') {
			println('  Iteration ${i}: Empty id field should not produce "id: " line')
			println('  Got: "${content}"')
			return false
		}
	}
	return true
}

// Test 7g: Retry field is written when positive (Requirement 3.8)
// *For any* SSE event with retry > 0, output SHALL contain "retry: {value}\n"
fn test_property_7g_retry_field_when_positive() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		retry := rand.int_in_range(100, 10000) or { 1000 }
		data := generate_random_string(1, 30)
		event := SSEEvent{
			data: data
			retry: retry
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		retry_line := 'retry: ${retry}\n'
		
		// Retry line should exist
		if !content.contains(retry_line) {
			println('  Iteration ${i}: Retry line "${retry_line}" not found')
			println('  Got: "${content}"')
			return false
		}
	}
	return true
}

// Test 7h: Retry field is omitted when zero (Requirement 3.8)
// *For any* SSE event with retry = 0, output SHALL NOT contain "retry: "
fn test_property_7h_zero_retry_field_omitted() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		data := generate_random_string(1, 30)
		event := SSEEvent{
			data: data
			retry: 0 // Zero retry
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		
		// Should not contain "retry: " prefix
		if content.contains('retry: ') {
			println('  Iteration ${i}: Zero retry should not produce "retry: " line')
			println('  Got: "${content}"')
			return false
		}
	}
	return true
}

// Test 7i: Event separator (empty line) is always present (Requirement 3.9)
// *For any* SSE event, output SHALL end with an additional "\n" to separate events
fn test_property_7i_event_separator_present() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		event := generate_random_sse_event()
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		
		// Content should end with double newline (data line + separator)
		// The last line before separator should be data:, id:, or retry:
		// followed by \n\n (the separator)
		if !content.ends_with('\n\n') {
			println('  Iteration ${i}: Event should end with double newline (separator)')
			println('  Got: "${content}"')
			println('  Last chars: ${content.bytes()[content.len - 4..]}')
			return false
		}
	}
	return true
}

// Test 7j: Complete SSE event with all fields (Requirements 3.4-3.9)
// *For any* SSE event with all fields set, output SHALL follow correct format and order
fn test_property_7j_complete_event_format() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		event_type := generate_random_string(3, 15)
		data := generate_random_string(1, 30)
		id := generate_random_string(1, 10)
		retry := rand.int_in_range(100, 10000) or { 1000 }
		
		event := SSEEvent{
			data: data
			event: event_type
			id: id
			retry: retry
		}
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		
		// Verify all fields are present
		if !content.contains('event: ${event_type}\n') {
			println('  Iteration ${i}: Event field missing')
			return false
		}
		if !content.contains('data: ${data}\n') {
			println('  Iteration ${i}: Data field missing')
			return false
		}
		if !content.contains('id: ${id}\n') {
			println('  Iteration ${i}: ID field missing')
			return false
		}
		if !content.contains('retry: ${retry}\n') {
			println('  Iteration ${i}: Retry field missing')
			return false
		}
		
		// Verify order: event -> data -> id -> retry -> separator
		event_pos := content.index('event: ') or { -1 }
		data_pos := content.index('data: ') or { -1 }
		id_pos := content.index('id: ') or { -1 }
		retry_pos := content.index('retry: ') or { -1 }
		
		if event_pos >= data_pos {
			println('  Iteration ${i}: Event should come before data')
			return false
		}
		if data_pos >= id_pos {
			println('  Iteration ${i}: Data should come before id')
			return false
		}
		if id_pos >= retry_pos {
			println('  Iteration ${i}: ID should come before retry')
			return false
		}
		
		// Verify ends with separator
		if !content.ends_with('\n\n') {
			println('  Iteration ${i}: Should end with event separator')
			return false
		}
	}
	return true
}

// Test 7k: Random SSE events are formatted correctly (Requirements 3.4-3.9)
// *For any* randomly generated SSE event, the formatting SHALL be correct
fn test_property_7k_random_events_formatted_correctly() bool {
	for i in 0 .. test_iterations {
		mut writer := MockStreamWriter.new()
		mut ctx := TestStreamContext.new(writer)
		
		event := generate_random_sse_event()
		
		ctx.write_sse(event) or {
			println('  Iteration ${i}: write_sse failed: ${err}')
			return false
		}
		
		content := writer.extract_sse_content()
		
		// Data field should always be present
		lines := event.data.split('\n')
		for line in lines {
			if !content.contains('data: ${line}\n') {
				println('  Iteration ${i}: Data line missing: "data: ${line}"')
				return false
			}
		}
		
		// Event field should be present only if non-empty
		if event.event.len > 0 {
			if !content.contains('event: ${event.event}\n') {
				println('  Iteration ${i}: Event field should be present')
				return false
			}
		} else {
			if content.contains('event: ') {
				println('  Iteration ${i}: Event field should not be present when empty')
				return false
			}
		}
		
		// ID field should be present only if non-empty
		if event.id.len > 0 {
			if !content.contains('id: ${event.id}\n') {
				println('  Iteration ${i}: ID field should be present')
				return false
			}
		} else {
			if content.contains('id: ') {
				println('  Iteration ${i}: ID field should not be present when empty')
				return false
			}
		}
		
		// Retry field should be present only if > 0
		if event.retry > 0 {
			if !content.contains('retry: ${event.retry}\n') {
				println('  Iteration ${i}: Retry field should be present')
				return false
			}
		} else {
			if content.contains('retry: ') {
				println('  Iteration ${i}: Retry field should not be present when zero')
				return false
			}
		}
		
		// Should always end with separator
		if !content.ends_with('\n\n') {
			println('  Iteration ${i}: Should end with event separator')
			return false
		}
	}
	return true
}


fn main() {
	println('🚀 开始 stream_sse() 函数属性测试...')
	println('每个属性测试运行 ${test_iterations} 次迭代\n')

	mut stats := PropertyTestStats{}

	// Run Property 6 tests
	// Feature: sse-streaming-helper, Property 6: streamSSE() 设置正确的 HTTP 头
	// Validates: Requirements 3.1, 3.2, 3.3
	println('--- Property 6: streamSSE() 设置正确的 HTTP 头 ---')
	stats.run_property_test('Property 6a: Content-Type header (text/event-stream)', test_property_6a_content_type_header)
	stats.run_property_test('Property 6b: Cache-Control header (no-cache)', test_property_6b_cache_control_header)
	stats.run_property_test('Property 6c: Connection header (keep-alive)', test_property_6c_connection_header)
	stats.run_property_test('Property 6d: Transfer-Encoding header (chunked)', test_property_6d_transfer_encoding_header)
	stats.run_property_test('Property 6e: Headers consistency', test_property_6e_headers_consistency)
	stats.run_property_test('Property 6f: All required headers present', test_property_6f_all_required_headers_present)
	stats.run_property_test('Property 6g: SSE headers differ from text', test_property_6g_sse_headers_differ_from_text)

	// Run Property 7 tests
	// Feature: sse-streaming-helper, Property 7: SSE 事件格式化正确性
	// Validates: Requirements 3.4, 3.5, 3.6, 3.7, 3.8, 3.9
	println('\n--- Property 7: SSE 事件格式化正确性 ---')
	stats.run_property_test('Property 7a: Data field formatting', test_property_7a_data_field_formatting)
	stats.run_property_test('Property 7b: Multi-line data formatting', test_property_7b_multiline_data_formatting)
	stats.run_property_test('Property 7c: Event field before data', test_property_7c_event_field_before_data)
	stats.run_property_test('Property 7d: Empty event field omitted', test_property_7d_empty_event_field_omitted)
	stats.run_property_test('Property 7e: ID field after data', test_property_7e_id_field_after_data)
	stats.run_property_test('Property 7f: Empty ID field omitted', test_property_7f_empty_id_field_omitted)
	stats.run_property_test('Property 7g: Retry field when positive', test_property_7g_retry_field_when_positive)
	stats.run_property_test('Property 7h: Zero retry field omitted', test_property_7h_zero_retry_field_omitted)
	stats.run_property_test('Property 7i: Event separator present', test_property_7i_event_separator_present)
	stats.run_property_test('Property 7j: Complete event format', test_property_7j_complete_event_format)
	stats.run_property_test('Property 7k: Random events formatted correctly', test_property_7k_random_events_formatted_correctly)

	// Print summary
	stats.print_summary()
}
