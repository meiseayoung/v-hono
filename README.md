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


## Build & Run

### Standard Build (picoev backend)

```bash
v your_app.v -o app.exe
./app.exe
```

### High-Performance Build (uSockets backend)

For maximum performance with uSockets backend:

```bash
v -enable-globals -cc gcc -ldflags "-ldbghelp" your_app.v -o app.exe
./app.exe
```

**Note**: The `-enable-globals` flag is required for uSockets backend. The `-ldflags "-ldbghelp"` fixes Windows linking issues.

#### Windows Prerequisites

To use uSockets backend on Windows, you need:

1. **GCC (MinGW-w64)** - C compiler
   ```powershell
   # Install via Scoop
   scoop install mingw
   
   # Or via Chocolatey
   choco install mingw
   
   # Or download from: https://www.mingw-w64.org/downloads/
   ```

2. **V Compiler** - Version 0.4.x or later
   ```powershell
   # Install via Scoop
   scoop install vlang
   
   # Or download from: https://vlang.io/
   ```

3. **Verify Installation**
   ```powershell
   gcc --version   # Should show MinGW-w64 GCC
   v version       # Should show V 0.4.x
   ```

The uSockets library and libuv are pre-compiled and included in the `usockets/lib/` directory.

### Using uSockets Backend

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()
    
    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello, World!')
    })
    
    // Use uSockets backend (high concurrency optimized)
    app.listen_usockets(3000)
    
    // Or use default picoev backend
    // app.listen(':3000')
}
```

See [benchmark/README.md](benchmark/README.md) for performance benchmarks and [usockets/README.md](usockets/README.md) for uSockets integration details.

## High Concurrency Support

v-hono with uSockets backend supports **10,000+ concurrent connections** out of the box.

### Performance Results

| Concurrent | RPS | Avg Latency | P99 Latency | Success Rate |
|------------|-----|-------------|-------------|--------------|
| 5,000 | 81,524 | 60.77ms | 295.17ms | 100% |
| 6,000 | 56,290 | 98.46ms | 557.47ms | 100% |
| 7,000 | 42,895 | 130.04ms | 824.80ms | 100% |
| 8,000 | 30,537 | 165.27ms | 1058.05ms | 100% |
| 9,000 | 28,693 | 215.86ms | 1422.67ms | 100% |
| 10,000 | 24,198 | 240.90ms | 1602.10ms | 100% |

### System Configuration (macOS)

For optimal high-concurrency performance:

```bash
# Increase socket backlog limit
sudo sysctl -w kern.ipc.somaxconn=8192

# Increase file descriptor limit
ulimit -n 65535
```

See [docs/HIGH_CONCURRENCY.md](docs/HIGH_CONCURRENCY.md) for detailed optimization guide.

## Quick Start

```v
import net.http
import meiseayoung.hono

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

    // Redirect example
    app.get('/old-page', fn (mut c hono.Context) http.Response {
        return c.redirect('/new-page', 301)
    })

    app.listen(':3000')
}
```

## Middleware

```v
import net.http
import time
import meiseayoung.hono

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
import meiseayoung.hono

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
import meiseayoung.hono

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
- `c.redirect(url, status_code...)` - Redirect to URL (default status: 302)
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
- `examples/redirect_demo.v` - Redirect functionality examples

## License

MIT License


