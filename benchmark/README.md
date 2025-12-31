# V-Hono Benchmark

Performance benchmarks for V-Hono web framework.

## Backend Comparison

### uSockets vs Picoev (200 connections, 100K requests)

| Backend | RPS | Avg Latency | P95 | P99 |
|---------|-----|-------------|-----|-----|
| uSockets | ~22,000 | 8.75ms | 16.66ms | 25.73ms |
| picoev | ~15,000 | 13.36ms | 18.89ms | 31.66ms |

**uSockets provides ~50% higher throughput under high concurrency.**

### High Concurrency Test (500 connections, 100K requests)

| Metric | uSockets |
|--------|----------|
| RPS | ~20,000 |
| Errors | 0 |
| Avg Latency | 25.04ms |
| P50 | 24.32ms |
| P95 | 32.97ms |
| P99 | 64.59ms |

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
