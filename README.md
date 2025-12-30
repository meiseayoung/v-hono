# v-hono

A high-performance V language web framework inspired by [Hono.js](https://hono.dev/).

## Features

- 🚀 **High Performance** - Hybrid routing with LRU cache for optimal speed
- 🎯 **Simple API** - Clean and intuitive API design inspired by Hono.js
- 🔧 **Middleware Support** - Flexible middleware system with onion model
- 📁 **Static File Serving** - Built-in static file server with caching
- 🔐 **Security** - Path validation and security utilities
- 📤 **File Upload** - Chunked file upload support
- 🗄️ **Database** - SQLite integration for data persistence
- 🔑 **Authentication** - Built-in auth system with JWT-like tokens

## Installation

### From VPM

```bash
v install meiseayoung.hono
```

### From GitHub

```bash
v install --git https://github.com/meiseayoung/v-hono
```

### Local Development

Clone the repository and the module will be available for import:

```bash
git clone https://github.com/meiseayoung/v-hono.git
cd v-hono
```

## Quick Start

```v
import net.http
import hono

fn main() {
    mut app := hono.Hono.new()

    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello, World!')
    })

    app.get('/json', fn (mut c hono.Context) http.Response {
        return c.json('{"message": "Hello, JSON!"}')
    })

    app.get('/users/:id', fn (mut c hono.Context) http.Response {
        user_id := c.params['id'] or { 'unknown' }
        return c.json('{"user_id": "${user_id}"}')
    })

    app.listen(':3000')
}
```

## Middleware

```v
import net.http
import time
import hono

fn main() {
    mut app := hono.Hono.new()

    // Logger middleware
    app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
        start := time.now()
        response := next(mut c)
        duration := time.since(start)
        println('[${c.req.method}] ${c.path} - ${duration}')
        return response
    })

    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello with middleware!')
    })

    app.listen(':3000')
}
```

## Route Grouping

```v
import net.http
import hono

fn main() {
    mut app := hono.Hono.new()

    // Create API sub-application
    mut api := hono.Hono.new()
    
    api.get('/users', fn (mut c hono.Context) http.Response {
        return c.json('[{"id": 1, "name": "Alice"}]')
    })

    api.get('/users/:id', fn (mut c hono.Context) http.Response {
        user_id := c.params['id'] or { 'unknown' }
        return c.json('{"id": ${user_id}}')
    })

    // Mount API routes under /api prefix
    app.route('/api', mut api)

    app.listen(':3000')
}
```

## Static File Serving

```v
import net.http
import hono

fn main() {
    mut app := hono.Hono.new()

    // Serve static files from ./public directory
    app.use(hono.serve_static(hono.StaticOptions{
        root: './public'
        path: '/static'
    }))

    app.listen(':3000')
}
```

## API Reference

### Hono

- `Hono.new()` - Create a new Hono application
- `app.get(path, handler)` - Register GET route
- `app.post(path, handler)` - Register POST route
- `app.put(path, handler)` - Register PUT route
- `app.delete(path, handler)` - Register DELETE route
- `app.patch(path, handler)` - Register PATCH route
- `app.all(path, handler)` - Register route for all methods
- `app.use(middleware)` - Add middleware
- `app.route(prefix, subapp)` - Mount sub-application
- `app.listen(port)` - Start server

### Context

- `c.text(data)` - Return text response
- `c.json(data)` - Return JSON response
- `c.html(data)` - Return HTML response
- `c.file(path)` - Return file response
- `c.status(code)` - Set response status code
- `c.params` - Route parameters
- `c.query` - Query parameters
- `c.body` - Request body
- `c.headers` - Response headers

## Project Structure

```
v-hono/
├── app.v              # Main application and routing
├── router.v           # Hybrid router implementation
├── fast_router.v      # Fast router with precompiled regex
├── trie_router.v      # Trie-based router
├── cache.v            # LRU cache implementation
├── request.v          # Request context
├── response.v         # Response utilities
├── static.v           # Static file serving
├── security.v         # Security utilities
├── config.v           # Configuration management
├── logger.v           # Logging system
├── multipart.v        # Multipart form parsing
├── upload.v           # File upload handling
├── database.v         # Database integration
├── auth.v             # Authentication system
├── auth_routes.v      # Auth route handlers
├── error_handler.v    # Error handling
├── v.mod              # Module definition
├── README.md          # Documentation
├── examples/          # Example applications
├── tests/             # Test files
└── docs/              # Additional documentation
```

## Examples

See the `examples/` directory for more examples:

- `examples/basic/` - Basic usage
- `examples/middleware/` - Middleware usage
- `examples/route_grouping/` - Route grouping

## License

MIT License
