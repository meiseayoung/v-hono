// test_websocket_subprotocol.v - Property test for WebSocket subprotocol negotiation
// Feature: websocket-helper, Property 9: Subprotocol Negotiation
// Validates: Requirements 4.4
//
// *For any* WebSocket handshake where the client requests subprotocols via
// Sec-WebSocket-Protocol header and the server has matching protocols configured,
// the response SHALL include exactly one matching protocol in the
// Sec-WebSocket-Protocol response header.
module main

import rand
import time
import net.http

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
	println('\n=== WebSocket Subprotocol Negotiation Property Test Summary ===')
	println('Total tests: ${stats.total_tests}')
	println('Passed: ${stats.passed_tests}')
	println('Failed: ${stats.failed_tests}')

	if stats.failed_tests == 0 {
		println('🎉 All property tests passed!')
	} else {
		println('⚠️  ${stats.failed_tests} property test(s) failed')
	}
}


// ============================================================================
// Subprotocol Negotiation Functions (copied from websocket.v for testing)
// ============================================================================

// negotiate_subprotocol_from_header - Negotiate subprotocol from client header value
// This is a simplified version that takes the header value directly
fn negotiate_subprotocol_from_header(client_protocols_header string, supported_protocols []string) string {
	if supported_protocols.len == 0 {
		return ''
	}
	
	if client_protocols_header.len == 0 {
		return ''
	}
	
	// Parse comma-separated list
	requested := client_protocols_header.split(',').map(it.trim_space())
	
	// Find first matching protocol
	for proto in requested {
		if proto in supported_protocols {
			return proto
		}
	}
	
	return ''
}

// create_handshake_response - Create WebSocket handshake response
fn create_handshake_response(key string, protocol string) http.Response {
	mut headers := http.new_header()
	headers.add_custom('Upgrade', 'websocket') or {}
	headers.add_custom('Connection', 'Upgrade') or {}
	headers.add_custom('Sec-WebSocket-Accept', key) or {}
	
	if protocol.len > 0 {
		headers.add_custom('Sec-WebSocket-Protocol', protocol) or {}
	}
	
	return http.Response{
		status_code: 101
		header: headers
		body: ''
	}
}

// ============================================================================
// Random Data Generators
// ============================================================================

fn generate_random_protocol_name() string {
	// Generate protocol names like: chat, graphql-ws, mqtt, soap, wamp, etc.
	prefixes := ['chat', 'graphql', 'mqtt', 'soap', 'wamp', 'stomp', 'xmpp', 'json', 'binary', 'proto']
	suffixes := ['', '-ws', '-v1', '-v2', '.subprotocol', '-rpc', '-stream']
	
	prefix := prefixes[rand.int_in_range(0, prefixes.len) or { 0 }]
	suffix := suffixes[rand.int_in_range(0, suffixes.len) or { 0 }]
	
	return prefix + suffix
}

fn generate_random_protocol_list(count int) []string {
	mut protocols := []string{cap: count}
	for _ in 0 .. count {
		proto := generate_random_protocol_name()
		if proto !in protocols {
			protocols << proto
		}
	}
	return protocols
}

fn protocols_to_header(protocols []string) string {
	return protocols.join(', ')
}


// ============================================================================
// Property 9: Subprotocol Negotiation
// Feature: websocket-helper, Property 9: Subprotocol Negotiation
// Validates: Requirements 4.4
//
// *For any* WebSocket handshake where the client requests subprotocols via
// Sec-WebSocket-Protocol header and the server has matching protocols configured,
// the response SHALL include exactly one matching protocol in the
// Sec-WebSocket-Protocol response header.
// ============================================================================

fn test_property_9_matching_protocol_selected() bool {
	rand.seed([u32(time.now().unix()), u32(12345)])
	
	for i in 0 .. test_iterations {
		// Generate server's supported protocols (1-5 protocols)
		server_count := rand.int_in_range(1, 6) or { 2 }
		server_protocols := generate_random_protocol_list(server_count)
		
		// Generate client's requested protocols (1-5 protocols)
		client_count := rand.int_in_range(1, 6) or { 2 }
		mut client_protocols := generate_random_protocol_list(client_count)
		
		// Ensure at least one matching protocol by adding one from server list
		matching_idx := rand.int_in_range(0, server_protocols.len) or { 0 }
		matching_protocol := server_protocols[matching_idx]
		
		// Insert matching protocol at random position in client list
		insert_pos := rand.int_in_range(0, client_protocols.len + 1) or { 0 }
		client_protocols.insert(insert_pos, matching_protocol)
		
		// Create header string
		client_header := protocols_to_header(client_protocols)
		
		// Negotiate
		result := negotiate_subprotocol_from_header(client_header, server_protocols)
		
		// Verify exactly one protocol is returned
		if result.len == 0 {
			println('  Iteration ${i}: Expected a matching protocol to be selected')
			println('    Server protocols: ${server_protocols}')
			println('    Client protocols: ${client_protocols}')
			return false
		}
		
		// Verify the selected protocol is in both lists
		if result !in server_protocols {
			println('  Iteration ${i}: Selected protocol not in server list')
			println('    Selected: ${result}')
			println('    Server protocols: ${server_protocols}')
			return false
		}
		
		if result !in client_protocols {
			println('  Iteration ${i}: Selected protocol not in client list')
			println('    Selected: ${result}')
			println('    Client protocols: ${client_protocols}')
			return false
		}
	}
	
	return true
}

fn test_property_9_no_match_returns_empty() bool {
	rand.seed([u32(time.now().unix()), u32(54321)])
	
	for i in 0 .. test_iterations {
		// Generate completely different protocol lists
		server_protocols := ['server-proto-a', 'server-proto-b', 'server-proto-c']
		client_protocols := ['client-proto-x', 'client-proto-y', 'client-proto-z']
		
		client_header := protocols_to_header(client_protocols)
		
		// Negotiate
		result := negotiate_subprotocol_from_header(client_header, server_protocols)
		
		// Verify no protocol is selected when there's no match
		if result.len > 0 {
			println('  Iteration ${i}: Expected empty result when no match')
			println('    Server protocols: ${server_protocols}')
			println('    Client protocols: ${client_protocols}')
			println('    Got: ${result}')
			return false
		}
	}
	
	return true
}

fn test_property_9_first_match_selected() bool {
	rand.seed([u32(time.now().unix()), u32(99999)])
	
	for i in 0 .. test_iterations {
		// Server supports multiple protocols
		server_protocols := ['proto-a', 'proto-b', 'proto-c', 'proto-d']
		
		// Client requests protocols in specific order with multiple matches
		// The first matching protocol in client's list should be selected
		client_protocols := ['proto-c', 'proto-a', 'proto-d']
		
		client_header := protocols_to_header(client_protocols)
		
		// Negotiate
		result := negotiate_subprotocol_from_header(client_header, server_protocols)
		
		// Verify the first matching protocol (proto-c) is selected
		if result != 'proto-c' {
			println('  Iteration ${i}: Expected first matching protocol to be selected')
			println('    Expected: proto-c')
			println('    Got: ${result}')
			return false
		}
	}
	
	return true
}


fn test_property_9_response_includes_protocol() bool {
	rand.seed([u32(time.now().unix()), u32(77777)])
	
	for i in 0 .. test_iterations {
		// Generate a random protocol
		protocol := generate_random_protocol_name()
		
		// Create handshake response with protocol
		response := create_handshake_response('dummy-accept-key', protocol)
		
		// Verify response includes the protocol header
		proto_header := response.header.get_custom('Sec-WebSocket-Protocol') or { '' }
		
		if proto_header != protocol {
			println('  Iteration ${i}: Response should include Sec-WebSocket-Protocol header')
			println('    Expected: ${protocol}')
			println('    Got: ${proto_header}')
			return false
		}
		
		// Verify status code is 101
		if response.status_code != 101 {
			println('  Iteration ${i}: Response status should be 101')
			println('    Got: ${response.status_code}')
			return false
		}
	}
	
	return true
}

fn test_property_9_empty_protocol_not_in_response() bool {
	rand.seed([u32(time.now().unix()), u32(11111)])
	
	for _ in 0 .. test_iterations {
		// Create handshake response without protocol
		response := create_handshake_response('dummy-accept-key', '')
		
		// Verify response does NOT include the protocol header
		proto_header := response.header.get_custom('Sec-WebSocket-Protocol') or { '' }
		
		if proto_header.len > 0 {
			println('  Response should not include Sec-WebSocket-Protocol when empty')
			println('    Got: ${proto_header}')
			return false
		}
	}
	
	return true
}

fn test_property_9_empty_server_protocols() bool {
	rand.seed([u32(time.now().unix()), u32(22222)])
	
	for i in 0 .. test_iterations {
		// Client requests protocols but server has none configured
		client_protocols := generate_random_protocol_list(3)
		client_header := protocols_to_header(client_protocols)
		
		// Empty server protocols
		server_protocols := []string{}
		
		// Negotiate
		result := negotiate_subprotocol_from_header(client_header, server_protocols)
		
		// Should return empty when server has no protocols
		if result.len > 0 {
			println('  Iteration ${i}: Expected empty when server has no protocols')
			println('    Got: ${result}')
			return false
		}
	}
	
	return true
}

fn test_property_9_empty_client_header() bool {
	rand.seed([u32(time.now().unix()), u32(33333)])
	
	for i in 0 .. test_iterations {
		// Server has protocols but client sends empty header
		server_protocols := generate_random_protocol_list(3)
		
		// Negotiate with empty client header
		result := negotiate_subprotocol_from_header('', server_protocols)
		
		// Should return empty when client sends no protocols
		if result.len > 0 {
			println('  Iteration ${i}: Expected empty when client sends no protocols')
			println('    Got: ${result}')
			return false
		}
	}
	
	return true
}

fn test_property_9_whitespace_handling() bool {
	// Test that whitespace around protocol names is handled correctly
	server_protocols := ['chat', 'graphql-ws', 'mqtt']
	
	// Various whitespace formats
	test_cases := [
		'chat, graphql-ws, mqtt',      // Standard spacing
		'chat,graphql-ws,mqtt',        // No spaces
		'  chat  ,  graphql-ws  ,  mqtt  ', // Extra spaces
		'chat ,graphql-ws, mqtt',      // Mixed spacing
	]
	
	for i, client_header in test_cases {
		result := negotiate_subprotocol_from_header(client_header, server_protocols)
		
		// Should find 'chat' as first match regardless of whitespace
		if result != 'chat' {
			println('  Test case ${i}: Whitespace handling failed')
			println('    Header: "${client_header}"')
			println('    Expected: chat')
			println('    Got: ${result}')
			return false
		}
	}
	
	return true
}

fn main() {
	println('🚀 Starting WebSocket Subprotocol Negotiation Property Tests...')
	println('Each property test runs ${test_iterations} iterations\n')

	mut stats := PropertyTestStats{}

	// Run property tests
	// Feature: websocket-helper, Property 9: Subprotocol Negotiation
	// Validates: Requirements 4.4
	stats.run_property_test('Property 9: Matching Protocol Selected', test_property_9_matching_protocol_selected)
	stats.run_property_test('Property 9: No Match Returns Empty', test_property_9_no_match_returns_empty)
	stats.run_property_test('Property 9: First Match Selected', test_property_9_first_match_selected)
	stats.run_property_test('Property 9: Response Includes Protocol', test_property_9_response_includes_protocol)
	stats.run_property_test('Property 9: Empty Protocol Not In Response', test_property_9_empty_protocol_not_in_response)
	stats.run_property_test('Property 9: Empty Server Protocols', test_property_9_empty_server_protocols)
	stats.run_property_test('Property 9: Empty Client Header', test_property_9_empty_client_header)
	stats.run_property_test('Property 9: Whitespace Handling', test_property_9_whitespace_handling)

	// Print test summary
	stats.print_summary()
}
