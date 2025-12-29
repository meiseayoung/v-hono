# V 语言 HTTP Keep-Alive 问题最小复现

## 问题描述

V 语言标准库 `net.http.Server` 不支持 HTTP Keep-Alive 连接复用。
每次请求处理完成后，服务器会立即关闭 TCP 连接。

## 运行方式

### 1. 启动服务器
```bash
v run server.v
```

### 2. 运行客户端测试（新终端）
```bash
v run client.v
```

## 预期 vs 实际

| 请求 | 预期 (Keep-Alive 正常) | 实际 (V 当前行为) |
|------|------------------------|-------------------|
| #1   | ~300ms (新连接)        | ~300ms            |
| #2   | ~1-10ms (复用)         | ~300ms            |
| #3   | ~1-10ms (复用)         | ~300ms            |
| #4   | ~1-10ms (复用)         | ~300ms            |
| #5   | ~1-10ms (复用)         | ~300ms            |

## 根本原因

`vlib/net/http/server.v` 中的 `handle_conn` 函数：

```v
fn (mut w HandlerWorker) handle_conn(mut conn net.TcpConn) {
    defer {
        conn.close() or { ... }  // <-- 每次请求后关闭连接
    }
    // 只处理单个请求，然后关闭
}
```

## 临时解决方案

在 V 服务器前部署 nginx 等反向代理来处理 Keep-Alive。
