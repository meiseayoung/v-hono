// Route grouping example for v-hono web framework
module main

import net.http
import hono

fn main() {
	mut app := hono.Hono.new()

	// Create API sub-application
	mut api := hono.Hono.new()
	
	api.get('/users', fn (mut c hono.Context) http.Response {
		return c.json('[{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]')
	})

	api.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id'] or { 'unknown' }
		return c.json('{"id": ${user_id}, "name": "User ${user_id}"}')
	})

	api.post('/users', fn (mut c hono.Context) http.Response {
		return c.json('{"message": "User created"}')
	})

	// Mount API routes under /api prefix
	app.route('/api', mut api)

	// Root route
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.html('<h1>Welcome to v-hono!</h1><p>API available at /api</p>')
	})

	println('Server starting on http://localhost:3000')
	println('Routes:')
	println('  GET  /           - Welcome page')
	println('  GET  /api/users  - List users')
	println('  GET  /api/users/:id - Get user by ID')
	println('  POST /api/users  - Create user')
	app.listen(':3000')
}
