# 已知问题

## 1. HTTP Keep-Alive 连接复用不支持

**状态**: 等待 V 语言官方修复

**问题描述**: 
每次 HTTP 请求响应时间约 300ms，其中大部分时间消耗在 TCP 连接建立上。即使响应头中包含 `Connection: keep-alive`，连接也无法复用。

**现象**:
- 快速连续发送请求：每次都慢（~300ms）
- 慢速发送请求：快慢交替（复用时快，超时后重建连接时慢）

**根本原因**:
V 语言标准库 `net.http.Server` 的 `handle_conn` 函数在每次请求处理完成后都会立即关闭连接：

```v
// F:\v\vlib\net\http\server.v
fn (mut w HandlerWorker) handle_conn(mut conn net.TcpConn) {
    defer {
        conn.close() or { eprintln('close() failed: ${err}') }  // 每次请求后关闭连接
    }
    // ... 处理单个请求 ...
}
```

**影响**:
- 无法实现 HTTP/1.1 Keep-Alive 连接复用
- 每次请求都需要重新建立 TCP 连接（三次握手）
- 高并发场景下性能受限

**临时解决方案**:
- 在服务器前部署支持 Keep-Alive 的反向代理（如 nginx）
- 或等待 V 语言官方修复此问题

**跟踪**:
- V 语言 GitHub: https://github.com/vlang/v
- 相关文件: `vlib/net/http/server.v`

**发现日期**: 2025-12-26
