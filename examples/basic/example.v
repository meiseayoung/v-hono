// Basic example of using v-hono web framework
// Run with: v run examples/basic/example.v
// Or after installing: v install your-username.hono
module main

import net.http
import hono

fn main() {
	mut app := hono.Hono.new()

	// Basic GET route
	app.get('/', fn (mut c hono.Context) http.Response {
		return c.text('Hello, World!')
	})

	// JSON response
	app.get('/json', fn (mut c hono.Context) http.Response {
		return c.json('{"message": "Hello, JSON!"}')
	})

	// HTML response
	app.get('/html', fn (mut c hono.Context) http.Response {
		return c.html('<h1>Hello, HTML!</h1>')
	})

	// Route with parameters
	app.get('/users/:id', fn (mut c hono.Context) http.Response {
		user_id := c.params['id'] or { 'unknown' }
		return c.json('{"user_id": "${user_id}"}')
	})

	// Query parameters
	app.get('/search', fn (mut c hono.Context) http.Response {
		query := c.query['q'] or { '' }
		return c.json('{"query": "${query}"}')
	})

	// POST route
	app.post('/api/data', fn (mut c hono.Context) http.Response {
		body := c.body
		return c.json('{"received": "${body}"}')
	})

	println('Server starting on http://127.0.0.1:3000')
	app.listen(':3000')
}
