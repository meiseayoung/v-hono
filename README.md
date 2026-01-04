# v-hono

A high-performance V language web framework inspired by [Hono.js](https://hono.dev/).

## Features

- 🚀 **High Performance** - Hybrid routing with LRU cache for optimal speed
- 🎯 **Simple API** - Clean and intuitive API design inspired by Hono.js
- 🔧 **Middleware Support** - Flexible middleware system with onion model
- 🌐 **CORS** - Built-in CORS middleware with full configuration
- 🍪 **Cookie Helper** - Easy cookie management with signed cookie support
- 🔐 **JWT Authentication** - JWT middleware with HS256/384/512 support
- 🎫 **Bearer Auth** - Simple Bearer token authentication
- 📦 **Compression** - Gzip and deflate response compression
- ⏱️ **Rate Limiting** - Request rate limiting with customizable stores
- ✅ **Validation** - Schema-based request validation
- 📁 **Static File Serving** - Built-in static file server with caching
- 🛡️ **Security** - Path validation and security utilities
- 📤 **File Upload** - Chunked file upload support
- 🗄️ **Database** - SQLite integration for data persistence
- 🔌 **WebSocket** - RFC 6455 compliant WebSocket support with event-based API

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

## Built-in Middleware

v-hono provides 7 built-in middleware components inspired by Hono.js:

### 1. CORS Middleware

Cross-Origin Resource Sharing middleware for handling CORS requests.

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Allow all origins
    app.use(hono.cors())

    // Custom configuration
    app.use(hono.cors(hono.CorsOptions{
        origin: 'https://example.com'
        credentials: true
        max_age: 600
        allow_methods: ['GET', 'POST', 'PUT', 'DELETE']
        allow_headers: ['Content-Type', 'Authorization']
    }))

    app.listen(':3000')
}
```

### 2. Cookie Helper

Utilities for managing HTTP cookies, including signed cookies.

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    app.get('/cookie/set', fn (mut c hono.Context) http.Response {
        // Set a cookie
        hono.set_cookie(mut c, 'session_id', 'abc123', hono.CookieOptions{
            http_only: true
            secure: true
            max_age: 3600
            path: '/'
        })
        return c.json('{"message": "Cookie set"}')
    })

    app.get('/cookie/get', fn (mut c hono.Context) http.Response {
        // Get a cookie
        if session := hono.get_cookie(c, 'session_id') {
            return c.json('{"session": "${session}"}')
        }
        return c.json('{"error": "Cookie not found"}')
    })

    app.get('/cookie/delete', fn (mut c hono.Context) http.Response {
        hono.delete_cookie(mut c, 'session_id')
        return c.json('{"message": "Cookie deleted"}')
    })

    // Signed cookies (tamper-proof)
    app.get('/signed/set', fn (mut c hono.Context) http.Response {
        secret := 'my-secret-key'
        hono.set_signed_cookie(mut c, 'user_data', 'user123', secret) or {
            return c.json('{"error": "Failed to set signed cookie"}')
        }
        return c.json('{"message": "Signed cookie set"}')
    })

    app.get('/signed/get', fn (mut c hono.Context) http.Response {
        secret := 'my-secret-key'
        user_data := hono.get_signed_cookie(c, 'user_data', secret) or {
            return c.json('{"error": "Invalid or missing signed cookie"}')
        }
        return c.json('{"user_data": "${user_data}"}')
    })

    app.listen(':3000')
}
```

### 3. JWT Middleware

JSON Web Token authentication middleware.

```v
import meiseayoung.hono
import time

fn main() {
    mut app := hono.Hono.new()
    secret := 'my-jwt-secret-key'

    // Generate JWT token
    app.post('/auth/login', fn [secret] (mut c hono.Context) http.Response {
        payload := hono.JwtPayload{
            sub: 'user123'
            iss: 'my-app'
            exp: time.now().unix() + 3600  // 1 hour
            iat: time.now().unix()
            claims: {
                'role': 'admin'
                'name': 'John Doe'
            }
        }

        token := hono.sign_jwt(payload, secret, .hs256) or {
            c.status(500)
            return c.json('{"error": "Failed to generate token"}')
        }

        return c.json('{"token": "${token}"}')
    })

    // Protect routes with JWT middleware
    app.use('/api/*', hono.jwt_middleware(hono.JwtOptions{
        secret: secret
        alg: .hs256
    }))

    app.get('/api/profile', fn (mut c hono.Context) http.Response {
        // Access JWT payload from context
        if payload := hono.get_jwt_payload(c) {
            return c.json('{"user": "${payload.sub}"}')
        }
        return c.json('{"error": "No payload"}')
    })

    app.listen(':3000')
}
```

### 4. Bearer Auth Middleware

Simple Bearer token authentication.

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Single token authentication
    app.use('/api/*', hono.bearer_auth(hono.BearerAuthOptions{
        token: 'my-api-token'
        realm: 'Protected API'
    }))

    // Multiple tokens
    app.use('/admin/*', hono.bearer_auth(hono.BearerAuthOptions{
        token: hono.BearerToken(['token1', 'token2', 'token3'])
    }))

    // Custom verification
    app.use('/custom/*', hono.bearer_auth(hono.BearerAuthOptions{
        verify_token: fn (token string, c hono.Context) bool {
            // Custom validation logic
            return token.len > 10 && token.starts_with('valid_')
        }
    }))

    app.get('/api/data', fn (mut c hono.Context) http.Response {
        token := hono.get_bearer_token(c) or { 'unknown' }
        return c.json('{"message": "Protected data", "token": "${token}"}')
    })

    app.listen(':3000')
}
```

### 5. Compression Middleware

Response compression with gzip and deflate support.

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Auto-select best encoding based on Accept-Encoding header
    app.use(hono.compress())

    // Force gzip compression
    app.use(hono.gzip())

    // Custom configuration
    app.use(hono.compress(hono.CompressOptions{
        encoding: .gzip
        threshold: 2048  // Only compress responses > 2KB
        level: 6         // Compression level (1-9)
    }))

    app.get('/large-data', fn (mut c hono.Context) http.Response {
        // Large response will be automatically compressed
        return c.json('{"data": "...large content..."}')
    })

    app.listen(':3000')
}
```

### 6. Rate Limiting Middleware

Request rate limiting to protect against abuse.

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Create memory store for rate limiting
    store := hono.MemoryStore.new()

    // Default: 100 requests per minute
    app.use(hono.rate_limit(hono.RateLimitOptions{
        store: store
        window_ms: 60000   // 1 minute
        limit: 100         // Max 100 requests
        headers: true      // Add X-RateLimit-* headers
    }))

    // Custom key generator (e.g., by user ID)
    app.use('/api/*', hono.rate_limit(hono.RateLimitOptions{
        store: store
        window_ms: 60000
        limit: 50
        key_generator: fn (c hono.Context) string {
            if user_id := c.get('user_id') {
                return user_id
            }
            return c.get_client_ip()
        }
    }))

    // Skip rate limiting for certain requests
    app.use(hono.rate_limit(hono.RateLimitOptions{
        store: store
        limit: 100
        skip: fn (c hono.Context) bool {
            // Skip for health check endpoints
            return c.path == '/health'
        }
    }))

    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello!')
    })

    app.listen(':3000')
}
```

### 7. Request Validator

Schema-based request validation for JSON body, query parameters, path parameters, and headers.

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Validate JSON body
    app.post('/users',
        hono.validate_json(hono.v_object({
            'name':  hono.v_string().required().min(2).max(50)
            'email': hono.v_string().required().pattern(r'^[\w\.-]+@[\w\.-]+\.\w+$')
            'age':   hono.v_int().min(0).max(150)
        })),
        fn (mut c hono.Context) http.Response {
            data := hono.get_validated_data(c)
            name := data['name'] or { '' }
            email := data['email'] or { '' }
            return c.json('{"message": "User created", "name": "${name}", "email": "${email}"}')
        }
    )

    // Validate query parameters
    app.get('/search',
        hono.validate_query(hono.v_object({
            'q':    hono.v_string().required().min(1)
            'page': hono.v_int().min(1)
            'size': hono.v_int().min(1).max(100)
        })),
        fn (mut c hono.Context) http.Response {
            q := hono.get_validated_field(c, 'q') or { '' }
            page := hono.get_validated_field(c, 'page') or { '1' }
            return c.json('{"query": "${q}", "page": ${page}}')
        }
    )

    // Validate path parameters
    app.get('/users/:id',
        hono.validate_params(hono.v_object({
            'id': hono.v_int().required().min(1)
        })),
        fn (mut c hono.Context) http.Response {
            id := hono.get_validated_field(c, 'id') or { '0' }
            return c.json('{"user_id": ${id}}')
        }
    )

    // Validate headers
    app.use('/api/*', hono.validate_headers(hono.v_object({
        'X-API-Key': hono.v_string().required()
    })))

    app.listen(':3000')
}
```

#### Schema Builder API

```v
// String schema
hono.v_string()
    .required()           // Field is required
    .min(2)               // Minimum length
    .max(100)             // Maximum length
    .pattern(r'^\w+$')    // Regex pattern
    .enum_of(['a', 'b'])  // Allowed values

// Integer schema
hono.v_int()
    .required()
    .min(0)
    .max(100)

// Float schema
hono.v_float()
    .required()
    .min(0.0)
    .max(100.0)

// Boolean schema
hono.v_bool()
    .required()

// Array schema
hono.v_array(hono.v_string())
    .min_items(1)
    .max_items(10)

// Nested object schema
hono.v_object({
    'address': hono.v_object({
        'street': hono.v_string().required()
        'city':   hono.v_string().required()
    })
})
```

### Utility Middleware

Additional utility middleware included:

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Security headers (X-Content-Type-Options, X-Frame-Options, etc.)
    app.use(hono.secure_headers())

    // Request ID generation
    app.use(hono.request_id())

    // Request timing (adds X-Response-Time header)
    app.use(hono.timing())

    // Combine multiple middleware
    combined := hono.combine_middlewares([
        hono.cors(),
        hono.secure_headers(),
        hono.timing(),
    ])
    app.use(combined)

    app.listen(':3000')
}
```

### Context Store

Store and retrieve data within request context:

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Auth middleware stores user info
    app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
        c.set('user_id', '12345')
        c.set('role', 'admin')
        return next(mut c)
    })

    app.get('/profile', fn (mut c hono.Context) http.Response {
        user_id := c.get('user_id') or { 'unknown' }
        role := c.get('role') or { 'guest' }
        client_ip := c.get_client_ip()
        return c.json('{"user_id": "${user_id}", "role": "${role}", "ip": "${client_ip}"}')
    })

    app.listen(':3000')
}
```

### 8. WebSocket Helper

RFC 6455 compliant WebSocket support for real-time bidirectional communication.

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // Basic WebSocket endpoint
    app.get('/ws', hono.upgrade_websocket(fn (c hono.Context) hono.WSEvents {
        return hono.WSEvents{
            on_open: fn (mut ws hono.WSContext) {
                println('Client connected')
                ws.send('Welcome to the WebSocket server!') or {}
            }
            on_message: fn (event hono.WSMessageEvent, mut ws hono.WSContext) {
                println('Received: ${event.data}')
                // Echo the message back
                ws.send('Echo: ${event.data}') or {}
            }
            on_close: fn (event hono.WSCloseEvent, mut ws hono.WSContext) {
                println('Client disconnected: ${event.code} - ${event.reason}')
            }
            on_error: fn (error string, mut ws hono.WSContext) {
                println('WebSocket error: ${error}')
            }
        }
    }))

    app.listen(':3000')
}
```

#### WebSocket with Configuration Options

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // WebSocket with custom options
    app.get('/ws/chat', hono.upgrade_websocket(
        fn (c hono.Context) hono.WSEvents {
            return hono.WSEvents{
                on_message: fn (event hono.WSMessageEvent, mut ws hono.WSContext) {
                    ws.send('Received: ${event.data}') or {}
                }
            }
        },
        hono.WebSocketOptions{
            ping_interval: 30000      // Send ping every 30 seconds
            max_message_size: 1048576 // Max 1MB message size
            timeout: 60000            // 60 second timeout
            protocols: ['chat', 'json'] // Supported subprotocols
        }
    ))

    app.listen(':3000')
}
```

#### WebSocket with Route Parameters

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    // WebSocket with route parameters
    app.get('/ws/room/:room_id', hono.upgrade_websocket(fn (c hono.Context) hono.WSEvents {
        // Access route parameters from HTTP context
        room_id := c.params['room_id'] or { 'default' }
        
        return hono.WSEvents{
            on_open: fn [room_id] (mut ws hono.WSContext) {
                ws.send('Joined room: ${room_id}') or {}
            }
            on_message: fn [room_id] (event hono.WSMessageEvent, mut ws hono.WSContext) {
                ws.send('[${room_id}] ${event.data}') or {}
            }
        }
    }))

    app.listen(':3000')
}
```

#### Sending Different Message Types

```v
import meiseayoung.hono

fn main() {
    mut app := hono.Hono.new()

    app.get('/ws', hono.upgrade_websocket(fn (c hono.Context) hono.WSEvents {
        return hono.WSEvents{
            on_message: fn (event hono.WSMessageEvent, mut ws hono.WSContext) {
                // Send text message
                ws.send('Hello, World!') or {}
                
                // Send binary data
                ws.send_bytes([u8(0x01), 0x02, 0x03]) or {}
                
                // Send JSON data
                ws.send_json('{"type": "message", "content": "Hello"}') or {}
                
                // Close connection gracefully
                // ws.close(1000, 'Normal closure') or {}
            }
        }
    }))

    app.listen(':3000')
}
```

#### WebSocket Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ping_interval` | `int` | `30000` | Ping interval in milliseconds (0 to disable) |
| `max_message_size` | `int` | `1048576` | Maximum message size in bytes (1MB) |
| `timeout` | `int` | `60000` | Connection timeout in milliseconds |
| `protocols` | `[]string` | `[]` | Supported WebSocket subprotocols |

#### WSContext Methods

| Method | Description |
|--------|-------------|
| `send(data string)` | Send text message |
| `send_bytes(data []u8)` | Send binary message |
| `send_json(data string)` | Send JSON data as text frame |
| `close(code int, reason string)` | Initiate graceful close |
| `get_context()` | Get original HTTP context |

#### WSContext Properties

| Property | Type | Description |
|----------|------|-------------|
| `ready_state` | `WSReadyState` | Connection state (connecting, open, closing, closed) |
| `protocol` | `string` | Negotiated subprotocol |
| `params` | `map[string]string` | Route parameters |
| `query` | `map[string]string` | Query parameters |
| `store` | `map[string]string` | Middleware store values |

#### WebSocket Close Codes

| Code | Constant | Description |
|------|----------|-------------|
| 1000 | `ws_close_normal` | Normal closure |
| 1001 | `ws_close_going_away` | Server shutting down |
| 1002 | `ws_close_protocol_error` | Protocol error |
| 1003 | `ws_close_unsupported_data` | Unsupported data type |
| 1007 | `ws_close_invalid_payload` | Invalid payload data |
| 1008 | `ws_close_policy_violation` | Policy violation |
| 1009 | `ws_close_message_too_big` | Message too big |
| 1011 | `ws_close_internal_error` | Internal server error |

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
├── middleware.v       # Middleware exports and utilities
├── cors.v             # CORS middleware
├── cookie.v           # Cookie helper
├── jwt.v              # JWT middleware
├── bearer_auth.v      # Bearer auth middleware
├── compress.v         # Compression middleware
├── rate_limit.v       # Rate limiting middleware
├── validator.v        # Request validation
├── websocket.v        # WebSocket helper (RFC 6455)
├── picoev_server.v    # Picoev backend with WebSocket support
├── usockets_server.v  # uSockets backend with WebSocket support
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
- `examples/middleware_demo.v` - Built-in middleware demonstration
- `examples/route_grouping/` - Route grouping
- `examples/redirect_demo.v` - Redirect functionality examples

## License

MIT License


