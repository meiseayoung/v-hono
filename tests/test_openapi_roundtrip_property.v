// test_openapi_roundtrip_property.v - Property-Based Test for OpenAPI Round-Trip Serialization
// **Feature: swagger-ui, Property 1: OpenAPI Document Round-Trip Serialization**
// **Validates: Requirements 3.2**
//
// Property: For any valid OpenAPI document, serializing to JSON and then 
// deserializing back SHALL produce an equivalent document.
module main

import hono
import rand
import time

const property_test_iterations = 100

struct PropertyTestStats {
mut:
	total_tests  int
	passed_tests int
	failed_tests int
	failed_examples []string
}

fn (mut stats PropertyTestStats) record_pass() {
	stats.total_tests++
	stats.passed_tests++
}

fn (mut stats PropertyTestStats) record_fail(example string) {
	stats.total_tests++
	stats.failed_tests++
	stats.failed_examples << example
}

fn (stats PropertyTestStats) print_summary() {
	println('\n=== Property Test Summary ===')
	println('Total iterations: ${stats.total_tests}')
	println('Passed: ${stats.passed_tests}')
	println('Failed: ${stats.failed_tests}')
	
	if stats.failed_tests == 0 {
		println('🎉 Property test PASSED!')
	} else {
		println('❌ Property test FAILED!')
		println('\nFailing examples:')
		for i, example in stats.failed_examples {
			if i >= 3 {
				println('... and ${stats.failed_examples.len - 3} more')
				break
			}
			println('  ${example}')
		}
	}
}

// Random string generator
fn random_string(min_len int, max_len int) string {
	chars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
	len := rand.int_in_range(min_len, max_len + 1) or { min_len }
	mut result := ''
	for _ in 0 .. len {
		idx := rand.int_in_range(0, chars.len) or { 0 }
		result += chars[idx..idx + 1]
	}
	return result
}

// Random URL generator
fn random_url() string {
	protocols := ['http', 'https']
	protocol := protocols[rand.int_in_range(0, 2) or { 0 }]
	domain := random_string(3, 10)
	tld := ['com', 'org', 'net', 'io'][rand.int_in_range(0, 4) or { 0 }]
	return '${protocol}://${domain}.${tld}'
}

// Random email generator
fn random_email() string {
	return '${random_string(3, 8)}@${random_string(3, 6)}.com'
}

// Random path generator
fn random_path() string {
	segments := rand.int_in_range(1, 4) or { 1 }
	mut path := ''
	for _ in 0 .. segments {
		path += '/' + random_string(3, 10)
	}
	return path
}

// Random OpenAPI version
fn random_openapi_version() string {
	versions := ['3.0.0', '3.0.1', '3.0.2', '3.0.3', '3.1.0']
	return versions[rand.int_in_range(0, versions.len) or { 0 }]
}

// Random HTTP method
fn random_http_method() string {
	methods := ['get', 'post', 'put', 'delete', 'patch']
	return methods[rand.int_in_range(0, methods.len) or { 0 }]
}

// Random parameter location
fn random_param_location() string {
	locations := ['path', 'query', 'header', 'cookie']
	return locations[rand.int_in_range(0, locations.len) or { 0 }]
}

// Random schema type
fn random_schema_type() string {
	types := ['string', 'integer', 'number', 'boolean', 'array', 'object']
	return types[rand.int_in_range(0, types.len) or { 0 }]
}

// Generate random OpenAPIContact
fn generate_random_contact() hono.OpenAPIContact {
	return hono.OpenAPIContact{
		name: random_string(3, 15)
		url: random_url()
		email: random_email()
	}
}

// Generate random OpenAPILicense
fn generate_random_license() hono.OpenAPILicense {
	licenses := ['MIT', 'Apache-2.0', 'GPL-3.0', 'BSD-3-Clause']
	return hono.OpenAPILicense{
		name: licenses[rand.int_in_range(0, licenses.len) or { 0 }]
		url: random_url()
	}
}

// Generate random OpenAPIInfo
fn generate_random_info() hono.OpenAPIInfo {
	return hono.OpenAPIInfo{
		title: random_string(5, 20)
		version: '${rand.int_in_range(1, 10) or { 1 }}.${rand.int_in_range(0, 10) or { 0 }}.${rand.int_in_range(0, 10) or { 0 }}'
		description: random_string(10, 50)
		terms_of_service: random_url()
		contact: generate_random_contact()
		license: generate_random_license()
	}
}

// Generate random OpenAPIServer
fn generate_random_server() hono.OpenAPIServer {
	return hono.OpenAPIServer{
		url: random_url()
		description: random_string(5, 20)
	}
}

// Generate random OpenAPISchema (simple, non-recursive)
fn generate_random_schema() hono.OpenAPISchema {
	schema_type := random_schema_type()
	return hono.OpenAPISchema{
		schema_type: schema_type
		format: if schema_type == 'integer' { 'int64' } else if schema_type == 'number' { 'double' } else { '' }
		description: random_string(5, 20)
		example: random_string(3, 10)
	}
}

// Generate random OpenAPIParameter
fn generate_random_parameter() hono.OpenAPIParameter {
	location := random_param_location()
	return hono.OpenAPIParameter{
		name: random_string(3, 10)
		in_location: location
		description: random_string(5, 20)
		required: location == 'path' || rand.int_in_range(0, 2) or { 0 } == 1
		deprecated: rand.int_in_range(0, 10) or { 0 } == 0  // 10% chance
		schema: generate_random_schema()
	}
}

// Generate random OpenAPIResponse
fn generate_random_response() hono.OpenAPIResponse {
	return hono.OpenAPIResponse{
		description: random_string(5, 30)
		content: {
			'application/json': hono.OpenAPIMediaType{
				schema: generate_random_schema()
			}
		}
	}
}

// Generate random OpenAPIOperation
fn generate_random_operation() hono.OpenAPIOperation {
	num_params := rand.int_in_range(0, 3) or { 0 }
	mut params := []hono.OpenAPIParameter{}
	for _ in 0 .. num_params {
		params << generate_random_parameter()
	}
	
	num_tags := rand.int_in_range(0, 3) or { 0 }
	mut tags := []string{}
	for _ in 0 .. num_tags {
		tags << random_string(3, 10)
	}
	
	return hono.OpenAPIOperation{
		summary: random_string(5, 30)
		description: random_string(10, 50)
		operation_id: random_string(5, 15)
		tags: tags
		parameters: params
		responses: {
			'200': generate_random_response()
			'400': hono.OpenAPIResponse{description: 'Bad Request'}
			'500': hono.OpenAPIResponse{description: 'Internal Server Error'}
		}
		deprecated: rand.int_in_range(0, 10) or { 0 } == 0  // 10% chance
	}
}

// Generate random OpenAPIPathItem
fn generate_random_path_item() hono.OpenAPIPathItem {
	mut path_item := hono.OpenAPIPathItem{
		summary: random_string(5, 20)
		description: random_string(10, 30)
	}
	
	// Randomly add HTTP methods
	if rand.int_in_range(0, 2) or { 0 } == 1 {
		path_item.get = generate_random_operation()
	}
	if rand.int_in_range(0, 2) or { 0 } == 1 {
		path_item.post = generate_random_operation()
	}
	if rand.int_in_range(0, 3) or { 0 } == 0 {
		path_item.put = generate_random_operation()
	}
	if rand.int_in_range(0, 3) or { 0 } == 0 {
		path_item.delete = generate_random_operation()
	}
	
	// Ensure at least one method is set
	if path_item.get.responses.len == 0 && path_item.post.responses.len == 0 && 
	   path_item.put.responses.len == 0 && path_item.delete.responses.len == 0 {
		path_item.get = generate_random_operation()
	}
	
	return path_item
}

// Generate random OpenAPITag
fn generate_random_tag() hono.OpenAPITag {
	return hono.OpenAPITag{
		name: random_string(3, 10)
		description: random_string(10, 30)
	}
}

// Generate random OpenAPIDocument
fn generate_random_document() hono.OpenAPIDocument {
	// Generate random number of paths (1-5)
	num_paths := rand.int_in_range(1, 6) or { 1 }
	mut paths := map[string]hono.OpenAPIPathItem{}
	for _ in 0 .. num_paths {
		paths[random_path()] = generate_random_path_item()
	}
	
	// Generate random number of servers (0-3)
	num_servers := rand.int_in_range(0, 4) or { 0 }
	mut servers := []hono.OpenAPIServer{}
	for _ in 0 .. num_servers {
		servers << generate_random_server()
	}
	
	// Generate random number of tags (0-5)
	num_tags := rand.int_in_range(0, 6) or { 0 }
	mut tags := []hono.OpenAPITag{}
	for _ in 0 .. num_tags {
		tags << generate_random_tag()
	}
	
	return hono.OpenAPIDocument{
		openapi: random_openapi_version()
		info: generate_random_info()
		servers: servers
		paths: paths
		tags: tags
	}
}

// Compare two OpenAPIInfo objects
fn compare_info(a hono.OpenAPIInfo, b hono.OpenAPIInfo) bool {
	return a.title == b.title &&
		a.version == b.version &&
		a.description == b.description &&
		a.terms_of_service == b.terms_of_service &&
		a.contact.name == b.contact.name &&
		a.contact.url == b.contact.url &&
		a.contact.email == b.contact.email &&
		a.license.name == b.license.name &&
		a.license.url == b.license.url
}

// Compare two OpenAPISchema objects
fn compare_schema(a hono.OpenAPISchema, b hono.OpenAPISchema) bool {
	return a.schema_type == b.schema_type &&
		a.format == b.format &&
		a.description == b.description &&
		a.example == b.example
}

// Compare two OpenAPIParameter objects
fn compare_parameter(a hono.OpenAPIParameter, b hono.OpenAPIParameter) bool {
	return a.name == b.name &&
		a.in_location == b.in_location &&
		a.description == b.description &&
		a.required == b.required &&
		a.deprecated == b.deprecated &&
		compare_schema(a.schema, b.schema)
}

// Compare two OpenAPIOperation objects
fn compare_operation(a hono.OpenAPIOperation, b hono.OpenAPIOperation) bool {
	if a.summary != b.summary || a.description != b.description ||
	   a.operation_id != b.operation_id || a.deprecated != b.deprecated {
		return false
	}
	
	if a.tags.len != b.tags.len {
		return false
	}
	for i, tag in a.tags {
		if tag != b.tags[i] {
			return false
		}
	}
	
	if a.parameters.len != b.parameters.len {
		return false
	}
	for i, param in a.parameters {
		if !compare_parameter(param, b.parameters[i]) {
			return false
		}
	}
	
	if a.responses.len != b.responses.len {
		return false
	}
	
	return true
}

// Compare two OpenAPIPathItem objects
fn compare_path_item(a hono.OpenAPIPathItem, b hono.OpenAPIPathItem) bool {
	if a.summary != b.summary || a.description != b.description {
		return false
	}
	
	// Compare operations (only if they have responses, meaning they're set)
	if a.get.responses.len > 0 || b.get.responses.len > 0 {
		if !compare_operation(a.get, b.get) {
			return false
		}
	}
	if a.post.responses.len > 0 || b.post.responses.len > 0 {
		if !compare_operation(a.post, b.post) {
			return false
		}
	}
	if a.put.responses.len > 0 || b.put.responses.len > 0 {
		if !compare_operation(a.put, b.put) {
			return false
		}
	}
	if a.delete.responses.len > 0 || b.delete.responses.len > 0 {
		if !compare_operation(a.delete, b.delete) {
			return false
		}
	}
	
	return true
}

// Compare two OpenAPIDocument objects
fn compare_documents(original hono.OpenAPIDocument, restored hono.OpenAPIDocument) bool {
	// Compare basic fields
	if original.openapi != restored.openapi {
		return false
	}
	
	// Compare info
	if !compare_info(original.info, restored.info) {
		return false
	}
	
	// Compare servers
	if original.servers.len != restored.servers.len {
		return false
	}
	for i, server in original.servers {
		if server.url != restored.servers[i].url ||
		   server.description != restored.servers[i].description {
			return false
		}
	}
	
	// Compare paths
	if original.paths.len != restored.paths.len {
		return false
	}
	for path, path_item in original.paths {
		if path !in restored.paths {
			return false
		}
		restored_item := restored.paths[path] or { return false }
		if !compare_path_item(path_item, restored_item) {
			return false
		}
	}
	
	// Compare tags
	if original.tags.len != restored.tags.len {
		return false
	}
	for i, tag in original.tags {
		if tag.name != restored.tags[i].name ||
		   tag.description != restored.tags[i].description {
			return false
		}
	}
	
	return true
}

// Property test: Round-trip serialization
fn test_round_trip_property() PropertyTestStats {
	mut stats := PropertyTestStats{}
	
	println('Running Property 1: OpenAPI Document Round-Trip Serialization')
	println('Iterations: ${property_test_iterations}')
	println('')
	
	for i in 0 .. property_test_iterations {
		// Generate random document
		original := generate_random_document()
		
		// Serialize to JSON
		json_str := original.to_json_str()
		
		// Deserialize back
		restored := hono.OpenAPIDocument.from_json_str(json_str) or {
			stats.record_fail('Iteration ${i}: Deserialization failed - ${err}')
			continue
		}
		
		// Compare
		if compare_documents(original, restored) {
			stats.record_pass()
		} else {
			stats.record_fail('Iteration ${i}: Documents not equal after round-trip. OpenAPI version: ${original.openapi}, Paths: ${original.paths.len}')
		}
		
		// Progress indicator
		if (i + 1) % 20 == 0 {
			print('.')
		}
	}
	println('')
	
	return stats
}

fn main() {
	println('🧪 Property-Based Test: OpenAPI Round-Trip Serialization')
	println('=========================================================')
	println('')
	
	// Seed random number generator
	rand.seed([u32(time.now().unix()), u32(time.now().unix() >> 32)])
	
	stats := test_round_trip_property()
	stats.print_summary()
	
	// Exit with appropriate code
	if stats.failed_tests > 0 {
		exit(1)
	}
}
