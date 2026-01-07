// Swagger UI Demo for v-hono
// This example demonstrates how to add interactive API documentation to your v-hono application
// Run with: v -enable-globals run examples/swagger_demo.v (from project root)
// Or: cd examples && v -enable-globals run swagger_demo.v
// Then visit: http://127.0.0.1:3000/ui for Swagger UI
//             http://127.0.0.1:3000/doc for OpenAPI JSON
module main

import net.http
import x.json2
import meiseayoung.hono

// Pet 结构体 - 用于演示 API 数据
struct Pet {
	id   int
	name string
	tag  string
}

fn (p Pet) as_map() map[string]string {
	return {
		"name": p.name,
		"tag": p.tag
	}
}
// ErrorResponse - 错误响应结构体
struct ErrorResponse {
	error string
}

// 使用全局变量实现共享状态
// 注意：需要使用 -enable-globals 编译选项
__global (
	g_pets = []Pet{}
	g_next_id = 4
)

fn main() {
	mut app := hono.Hono.new()

	// =========================================================================
	// 1. Basic Usage - Using OpenAPI Builder API
	// =========================================================================
	
	// Build OpenAPI specification using the fluent builder API
	// Note: In V, we need to create a mutable builder first, then chain methods
	mut builder := hono.OpenAPIBuilder.new()
	builder.openapi('3.0.0')
	builder.title('Pet Store API')
	builder.version('1.0.0')
	builder.description('A sample Pet Store API demonstrating Swagger UI integration with v-hono')
	builder.server('http://127.0.0.1:3000', 'Development server')
	builder.tag('pets', 'Pet management operations')
	builder.tag('users', 'User management operations')
	
	// Define GET /pets endpoint
	mut pets_path := builder.path('/pets')
	pets_path.get(hono.OpenAPIOperation{
		summary: 'List all pets'
		description: 'Returns a list of all pets in the store'
		operation_id: 'listPets'
		tags: ['pets']
		parameters: [
			hono.OpenAPIParameter{
				name: 'limit'
				in_location: 'query'
				description: 'Maximum number of pets to return'
				required: false
				schema: hono.OpenAPISchema{
					schema_type: 'integer'
					format: 'int32'
				}
			},
		]
		responses: {
			'200': hono.OpenAPIResponse{
				description: 'A list of pets'
				content: {
					'application/json': hono.OpenAPIMediaType{
						schema: hono.OpenAPISchema{
							schema_type: 'array'
							items: &hono.OpenAPISchema{
								ref: '#/components/schemas/Pet'
							}
						}
					}
				}
			}
		}
	})
	pets_path.post(hono.OpenAPIOperation{
		summary: 'Create a pet'
		description: 'Creates a new pet in the store'
		operation_id: 'createPet'
		tags: ['pets']
		request_body: hono.OpenAPIRequestBody{
			description: 'Pet to add to the store'
			required: true
			content: {
				'application/json': hono.OpenAPIMediaType{
					schema: hono.OpenAPISchema{
						ref: '#/components/schemas/NewPet'
					}
				}
			}
		}
		responses: {
			'201': hono.OpenAPIResponse{
				description: 'Pet created successfully'
				content: {
					'application/json': hono.OpenAPIMediaType{
						schema: hono.OpenAPISchema{
							ref: '#/components/schemas/Pet'
						}
					}
				}
			}
		}
	})
	pets_path.done()
	
	// Define GET/DELETE /pets/{id} endpoint
	mut pet_by_id_path := builder.path('/pets/{id}')
	pet_by_id_path.get(hono.OpenAPIOperation{
		summary: 'Get a pet by ID'
		description: 'Returns a single pet by its ID'
		operation_id: 'getPetById'
		tags: ['pets']
		parameters: [
			hono.OpenAPIParameter{
				name: 'id'
				in_location: 'path'
				description: 'ID of the pet to retrieve'
				required: true
				schema: hono.OpenAPISchema{
					schema_type: 'integer'
					format: 'int64'
				}
			},
		]
		responses: {
			'200': hono.OpenAPIResponse{
				description: 'Pet found'
				content: {
					'application/json': hono.OpenAPIMediaType{
						schema: hono.OpenAPISchema{
							ref: '#/components/schemas/Pet'
						}
					}
				}
			}
			'404': hono.OpenAPIResponse{
				description: 'Pet not found'
			}
		}
	})
	pet_by_id_path.delete(hono.OpenAPIOperation{
		summary: 'Delete a pet'
		description: 'Deletes a pet by its ID'
		operation_id: 'deletePet'
		tags: ['pets']
		parameters: [
			hono.OpenAPIParameter{
				name: 'id'
				in_location: 'path'
				description: 'ID of the pet to delete'
				required: true
				schema: hono.OpenAPISchema{
					schema_type: 'integer'
					format: 'int64'
				}
			},
		]
		responses: {
			'204': hono.OpenAPIResponse{
				description: 'Pet deleted successfully'
			}
			'404': hono.OpenAPIResponse{
				description: 'Pet not found'
			}
		}
	})
	pet_by_id_path.done()
	
	// Add reusable schemas to components
	builder.add_schema('Pet', hono.OpenAPISchema{
		schema_type: 'object'
		required: ['id', 'name']
		properties: {
			'id': hono.OpenAPISchema{
				schema_type: 'integer'
				format: 'int64'
				description: 'Unique identifier for the pet'
			}
			'name': hono.OpenAPISchema{
				schema_type: 'string'
				description: 'Name of the pet'
			}
			'tag': hono.OpenAPISchema{
				schema_type: 'string'
				description: 'Tag for categorizing the pet'
			}
		}
	})
	builder.add_schema('NewPet', hono.OpenAPISchema{
		schema_type: 'object'
		required: ['name']
		properties: {
			'name': hono.OpenAPISchema{
				schema_type: 'string'
				description: 'Name of the pet'
			}
			'tag': hono.OpenAPISchema{
				schema_type: 'string'
				description: 'Tag for categorizing the pet'
			}
		}
	})
	
	spec := builder.build() or {
		eprintln('Failed to build OpenAPI spec: ${err}')
		return
	}

	// Register the OpenAPI JSON endpoint
	app.doc('/doc', spec)

	// =========================================================================
	// 2. Swagger UI with Default Options
	// =========================================================================
	
	// Serve Swagger UI at /ui with default options
	app.get('/ui', hono.swagger_ui(hono.SwaggerUIOptions{
		url: '/doc'
		title: 'Pet Store API Documentation'
	}))

	// =========================================================================
	// 3. Swagger UI with Custom Options
	// =========================================================================
	
	// Serve Swagger UI at /docs with custom options
	app.get('/docs', hono.swagger_ui(hono.SwaggerUIOptions{
		url: '/doc'
		title: 'Pet Store API - Custom Theme'
		deep_linking: true
		display_request_duration: true
		default_models_expand_depth: 2
		doc_expansion: 'full'  // 'list', 'full', or 'none'
		filter: true
		show_extensions: true
		show_common_extensions: true
		try_it_out_enabled: true
		// Custom CSS to change the header color
		custom_css: '.swagger-ui .topbar { background-color: #2c3e50; }'
	}))

	// =========================================================================
	// 4. Actual API Endpoints (for testing with Swagger UI)
	// =========================================================================
	
	// 初始化全局宠物数据
	// 使用全局变量可以在多个 handler 之间共享和修改数据
	g_pets = [
		Pet{id: 1, name: 'Fluffy', tag: 'cat'},
		Pet{id: 2, name: 'Buddy', tag: 'dog'},
		Pet{id: 3, name: 'Goldie', tag: 'fish'},
	]

	// GET /pets - List all pets
	app.get('/pets', fn (mut c hono.Context) http.Response {
		return c.json(json2.encode(g_pets))
	})

	// POST /pets - Create a new pet
	app.post('/pets', fn (mut c hono.Context) http.Response {
		println(c.body)
		pet_dic := json2.decode[Pet](c.body) or {
			panic(err)
		}
		pet := Pet{id: g_next_id, name: pet_dic.name, tag: pet_dic.tag}
		g_pets << pet
		g_next_id++
		c.status(201)
		return c.json(json2.encode(pet))
	})

	// GET /pets/:id - Get a pet by ID
	app.get('/pets/:id', fn (mut c hono.Context) http.Response {
		pet_id := c.params['id'] or { '' }
		for pet in g_pets {
			if pet.id == pet_id.int() {
				return c.json(json2.encode(pet))
			}
		}
		c.status(404)
		return c.json(json2.encode(ErrorResponse{error: 'Pet not found'}))
	})

	// DELETE /pets/:id - Delete a pet
	app.delete('/pets/:id', fn (mut c hono.Context) http.Response {
		pet_id := c.params['id'] or { '' }
		for i, pet in g_pets {
			if pet.id == pet_id.int() {
				g_pets.delete(i)
				return http.Response{
					status_code: 204
					header: http.new_header(key: .content_type, value: 'application/json')
					body: ''
				}
			}
		}
		c.status(404)
		return c.json(json2.encode(ErrorResponse{error: 'Pet not found'}))
	})

	// =========================================================================
	// Start Server
	// =========================================================================
	
	println('=== Swagger UI Demo ===')
	println('Server starting on http://127.0.0.1:3000')
	println('')
	println('Available endpoints:')
	println('  - Swagger UI (default):  http://127.0.0.1:3000/ui')
	println('  - Swagger UI (custom):   http://127.0.0.1:3000/docs')
	println('  - OpenAPI JSON:          http://127.0.0.1:3000/doc')
	println('')
	println('API endpoints:')
	println('  - GET    /pets      - List all pets')
	println('  - POST   /pets      - Create a new pet')
	println('  - GET    /pets/:id  - Get a pet by ID')
	println('  - DELETE /pets/:id  - Delete a pet')
	println('')
	
	app.listen_usockets(3000)
}
