module main

import hono
import net.http

fn main() {
	mut app := hono.Hono.new()
	
	// Basic redirect (302 Found)
	app.get('/redirect-basic', fn (mut c hono.Context) http.Response {
		return c.redirect('https://example.com')
	})
	
	// Redirect with custom status code (301 Moved Permanently)
	app.get('/redirect-permanent', fn (mut c hono.Context) http.Response {
		return c.redirect('https://example.com', 301)
	})
	
	// Redirect with 303 See Other
	app.post('/form-submit', fn (mut c hono.Context) http.Response {
		// Process form data here...
		// Then redirect to success page
		return c.redirect('/success', 303)
	})
	
	// Redirect with 307 Temporary Redirect (preserves method)
	app.get('/redirect-preserve-method', fn (mut c hono.Context) http.Response {
		return c.redirect('/new-location', 307)
	})
	
	// Redirect with 308 Permanent Redirect (preserves method)
	app.get('/redirect-permanent-preserve', fn (mut c hono.Context) http.Response {
		return c.redirect('/new-permanent-location', 308)
	})
	
	// Conditional redirect
	app.get('/conditional-redirect', fn (mut c hono.Context) http.Response {
		user_agent := c.req.header.get_custom('User-Agent') or { '' }
		
		if user_agent.contains('Mobile') {
			return c.redirect('/mobile-version')
		} else {
			return c.redirect('/desktop-version')
		}
	})
	
	// Redirect to relative path
	app.get('/relative-redirect', fn (mut c hono.Context) http.Response {
		return c.redirect('../other-page')
	})
	
	// Success page for demonstration
	app.get('/success', fn (mut c hono.Context) http.Response {
		return c.html('<h1>Success!</h1><p>Form submitted successfully.</p>')
	})
	
	app.get('/mobile-version', fn (mut c hono.Context) http.Response {
		return c.html('<h1>Mobile Version</h1>')
	})
	
	app.get('/desktop-version', fn (mut c hono.Context) http.Response {
		return c.html('<h1>Desktop Version</h1>')
	})
	
	println('Server running on http://127.0.0.1:8080')
	println('Try these endpoints:')
	println('  GET  /redirect-basic           - Basic redirect (302)')
	println('  GET  /redirect-permanent       - Permanent redirect (301)')
	println('  POST /form-submit              - Form redirect (303)')
	println('  GET  /redirect-preserve-method - Temporary redirect preserving method (307)')
	println('  GET  /conditional-redirect     - Conditional redirect based on User-Agent')
	println('  GET  /relative-redirect        - Relative path redirect')
	
	app.listen(':8080')
}