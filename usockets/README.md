# uSockets Backend for V-Hono

High-performance server backend using [uSockets](https://github.com/uNetworking/uSockets) library.

## High Concurrency Performance

The included `libusockets_full.a` has been optimized with **backlog=16384** to support high concurrency:

| Concurrent | RPS | Success Rate |
|------------|-----|--------------|
| 4,000 | 112,614 | 100% |
| 6,000 | 56,728 | 100% |
| 8,000 | 33,255 | 100% |
| 10,000 | 25,964 | 100% |

### System Requirements

For 10,000+ concurrent connections:

```bash
# macOS
sudo sysctl -w kern.ipc.somaxconn=8192
ulimit -n 65535

# Linux
sudo sysctl -w net.core.somaxconn=8192
ulimit -n 65535
```

## Performance

Based on benchmark tests (200 connections, 100K requests):

| Backend | RPS | Avg Latency | P95 | P99 |
|---------|-----|-------------|-----|-----|
| uSockets | ~22,000 | 8.75ms | 16.66ms | 25.73ms |
| picoev | ~15,000 | 13.36ms | 18.89ms | 31.66ms |

**uSockets provides ~50% higher throughput under high concurrency.**

## Usage

```v
import meiseayoung.hono

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
app.listen_usockets_with_config(meiseayoung.hono.UsocketsConfig{
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
