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
# macOS / Linux
v -enable-globals -prod -o app your_app.v
./app

# Windows (must use gcc, tcc does not support .a static library format)
v -enable-globals -cc gcc -ldflags "-ldbghelp" -o app.exe your_app.v
.\app.exe
```

**Required flags:**
- `-enable-globals` - Required for uSockets global state
- `-cc gcc` - Use GCC compiler (MinGW-w64 on Windows, required because V's default compiler tcc does not support MinGW `.a` static library format)
- `-ldflags "-ldbghelp"` - Required on Windows for libuv linking

## Pre-compiled Libraries

The uSockets library and libuv are pre-compiled and included in the `lib/{platform}/` directory:

- `lib/windows/` - Windows x64
- `lib/linux/` - Linux x64
- `lib/macos-arm64/` - macOS Apple Silicon
- `lib/macos-x64/` - macOS Intel

## Directory Structure

```
usockets/
├── include/           # Header files
│   ├── libusockets.h  # uSockets API
│   ├── uv.h           # libuv API
│   └── uv/            # libuv headers
├── lib/               # Pre-compiled libraries
│   ├── windows/       # Windows x64
│   ├── linux/         # Linux x64
│   ├── macos-arm64/   # macOS Apple Silicon
│   └── macos-x64/     # macOS Intel
├── src/               # Modified source files
│   └── bsd.c          # Modified with backlog=16384
├── build.sh           # Build script
├── usockets.v         # V bindings
└── README.md          # This file
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

## Building uSockets Library from Source

If you need to rebuild the uSockets library (e.g., for a different platform or custom modifications), use the provided build script.

### Build Prerequisites

- **Git** - For cloning source repositories
- **GCC** - C compiler
- **CMake** - For building libuv
- **ar** - Archive tool (included with GCC)

#### Installing Prerequisites

**macOS:**
```bash
xcode-select --install
brew install cmake
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install build-essential cmake git
```

**Linux (CentOS/RHEL):**
```bash
sudo yum groupinstall "Development Tools"
sudo yum install cmake git
```

**Windows (Git Bash/MSYS2):**
```powershell
# Install via Scoop
scoop install mingw cmake git

# Or via Chocolatey
choco install mingw cmake git
```

### Running the Build Script

```bash
cd usockets
chmod +x build.sh
./build.sh
```

The script will:
1. Clone uSockets and libuv repositories to `/tmp/`
2. Apply the backlog=16384 modification for high concurrency
3. Compile libuv as a static library
4. Compile uSockets with libuv support
5. Merge both libraries into `libusockets_full.a`
6. Output to the appropriate `lib/{platform}/` directory

### Build Script Details

The build script (`build.sh`) automatically:
- Detects your operating system (Windows/macOS/Linux)
- Detects CPU architecture (x64/arm64 on macOS)
- Applies the backlog modification from `src/bsd.c`
- Compiles with optimizations (`-O3`)
- Creates a merged static library containing both uSockets and libuv

### Custom Modifications

To customize the build:

1. **Change backlog size**: Edit `src/bsd.c` and modify the `listen()` call
2. **Enable SSL**: Remove `-DLIBUS_NO_SSL` from the build script and link OpenSSL
3. **Use different event loop**: Modify `-DLIBUS_USE_LIBUV` flag

### Troubleshooting Build Issues

**CMake not found:**
```bash
# macOS
brew install cmake

# Linux
sudo apt install cmake  # or sudo yum install cmake

# Windows
scoop install cmake
```

**GCC not found (Windows):**
```powershell
scoop install mingw
# Make sure MinGW bin directory is in PATH
```

**Permission denied:**
```bash
chmod +x build.sh
```

## Notes

- On Windows, uSockets and picoev have similar performance
- On Linux, uSockets may have greater advantages due to epoll optimization
- uSockets excels under high concurrency (200+ connections)
