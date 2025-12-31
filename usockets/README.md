# uSockets Backend for V-Hono

High-performance server backend using [uSockets](https://github.com/uNetworking/uSockets) library.

## Performance

Based on benchmark tests (200 connections, 100K requests):

| Backend | RPS | Avg Latency | P95 | P99 |
|---------|-----|-------------|-----|-----|
| uSockets | ~22,000 | 8.75ms | 16.66ms | 25.73ms |
| picoev | ~15,000 | 13.36ms | 18.89ms | 31.66ms |

**uSockets provides ~50% higher throughput under high concurrency.**

## Usage

```v
import hono

fn main() {
    mut app := hono.Hono.new()
    
    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello from uSockets!')
    })
    
    // Use uSockets backend
    app.listen_usockets(3000)
}
```

## Build Command

```bash
v -enable-globals -cc gcc -ldflags "-ldbghelp" your_app.v -o app.exe
```

**Required flags:**
- `-enable-globals` - Required for uSockets global state
- `-cc gcc` - Use GCC compiler (MinGW-w64 on Windows)
- `-ldflags "-ldbghelp"` - Fix Windows linking (Windows only)

## Prerequisites (Windows)

1. **GCC (MinGW-w64)**
   ```powershell
   scoop install mingw
   # or
   choco install mingw
   ```

2. **V Compiler** (0.4.x or later)
   ```powershell
   scoop install vlang
   ```

## Directory Structure

```
usockets/
├── include/           # Header files
│   ├── libusockets.h  # uSockets API
│   ├── uv.h           # libuv API
│   └── uv/            # libuv headers
├── lib/               # Pre-compiled libraries
│   ├── libusockets_full.a  # uSockets + libuv (main)
│   ├── libuv.a             # libuv static lib
│   └── ...
└── usockets.v         # V bindings
```

## Configuration

```v
// Custom configuration
app.listen_usockets_with_config(hono.UsocketsConfig{
    port: 8080
    host: '0.0.0.0'
    keepalive_timeout: 30
    max_keepalive_req: 10000
})
```

## Notes

- On Windows, uSockets and picoev have similar performance
- On Linux, uSockets may have greater advantages due to epoll optimization
- uSockets excels under high concurrency (200+ connections)
