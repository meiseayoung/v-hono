# V-Hono Benchmark

Performance benchmarks for V-Hono web framework.

## Framework Comparison (500 connections, 100K requests)

| Framework | RPS | Errors | Avg Latency | P50 | P95 | P99 |
|-----------|-----|--------|-------------|-----|-----|-----|
| **v-hono (uSockets)** | **20,231** | **0** | **24.62ms** | **23.65ms** | **33.82ms** | **57.29ms** |
| v-hono (picoev) | 16,177 | 0 | 30.75ms | 26.25ms | 35.37ms | 111.38ms |
| veb (V官方) | 7,278 | 772 | 68.06ms | 55.79ms | 71.62ms | 98.90ms |

### Performance Summary

- **v-hono (uSockets) vs veb**: **2.78x faster**, zero errors
- **v-hono (uSockets) vs picoev**: **25% faster**, better P99 latency
- **v-hono (picoev) vs veb**: **2.22x faster**, zero errors

## Running Benchmarks

### 1. Start Test Server

**uSockets backend:**
```bash
v -enable-globals -cc gcc -ldflags "-ldbghelp" benchmark/usockets_server.v -o server.exe
./server.exe
```

**Picoev backend:**
```bash
v -enable-globals examples/picoev_example.v -o server.exe
./server.exe
```

### 2. Run Integration Tests

```bash
go run benchmark/usockets_verify.go
```

### 3. Run Performance Tests

```bash
# 200 connections, 100K requests
go run tests/main.go -url "http://127.0.0.1:9998" -c 200 -n 100000

# 500 connections, 100K requests
go run tests/main.go -url "http://127.0.0.1:9998" -c 500 -n 100000
```

### 4. Quick Concurrent Test (PowerShell)

```powershell
powershell -File benchmark/quick_test.ps1
```

## Test Files

| File | Description |
|------|-------------|
| `usockets_server.v` | uSockets test server with full API |
| `usockets_verify.go` | Go integration test (17 test cases) |
| `quick_test.ps1` | PowerShell concurrent test script |
| `../tests/main.go` | Go performance benchmark tool |

## Test Coverage

The integration test (`usockets_verify.go`) covers:

- ✅ Basic GET routes (root, health, static)
- ✅ Dynamic routes (single/multi/nested params)
- ✅ Query parameters
- ✅ Response formats (JSON, HTML, custom status)
- ✅ HTTP methods (POST, PUT, DELETE)
- ✅ Error handling (404)
- ✅ Keep-Alive connections
- ✅ Throughput performance
