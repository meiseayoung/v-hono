# v-hono 高并发优化指南

## 概述

v-hono 使用 uSockets 作为高性能网络后端，经过优化后可以稳定支持 **10,000+ 并发连接**。

## 性能测试结果

| 并发数 | RPS | 平均延迟 | P99延迟 | 成功率 |
|--------|-----|----------|---------|--------|
| 5,000 | 81,524 | 60.77ms | 295.17ms | 100% |
| 6,000 | 56,290 | 98.46ms | 557.47ms | 100% |
| 7,000 | 42,895 | 130.04ms | 824.80ms | 100% |
| 8,000 | 30,537 | 165.27ms | 1058.05ms | 100% |
| 9,000 | 28,693 | 215.86ms | 1422.67ms | 100% |
| 10,000 | 24,198 | 240.90ms | 1602.10ms | 100% |

测试环境：macOS (Apple Silicon M3 Max)

**重要提示**：每次测试后需等待 60 秒让 TIME_WAIT 连接释放，否则会影响下一次测试结果。

## 关键优化

### 1. uSockets backlog 参数

原始 uSockets 库的 `listen()` backlog 参数硬编码为 512，限制了高并发能力。

**修复位置**：`v-hono/usockets/src/bsd.c` (第 532 行和第 578 行)

```c
// 修改前
listen(listenFd, 512)

// 修改后
listen(listenFd, 16384)
```

修改后的源码保存在 `v-hono/usockets/src/bsd.c`，编译后的库文件在 `v-hono/lib/libusockets_full.a`。

**重新编译**：运行 `v-hono/usockets/build.sh` 脚本。

### 2. 系统参数配置

macOS 需要调整以下系统参数：

```bash
# 查看当前值
sysctl kern.ipc.somaxconn

# 临时修改（重启后失效）
sudo sysctl -w kern.ipc.somaxconn=8192

# 永久修改（添加到 /etc/sysctl.conf）
kern.ipc.somaxconn=8192
```

**注意**：实际 backlog 值会被 `kern.ipc.somaxconn` 截断，所以系统参数也需要相应调整。

## 重新编译 uSockets（可选）

如果需要自定义 backlog 值，可以重新编译 uSockets：

```bash
# 1. 克隆 uSockets
git clone https://github.com/uNetworking/uSockets.git

# 2. 修改 src/bsd.c 中的 listen 调用
# 将 listen(listenFd, 512) 改为 listen(listenFd, 16384)

# 3. 编译（macOS with libuv）
WITH_LIBUV=1 CFLAGS="-I/opt/homebrew/include" make

# 4. 复制到 v-hono
cp uSockets.a /path/to/v-hono/lib/libusockets_full.a

# 5. 重新编译 v-hono 应用
v -enable-globals -prod -o your_app your_app.v
```

## 使用建议

1. **生产环境**：建议使用 uSockets 后端（`app.listen_usockets(port)`）
2. **系统调优**：确保 `kern.ipc.somaxconn` >= 8192
3. **文件描述符**：服务器和客户端都需要设置 `ulimit -n 65535`
4. **启动命令**：`ulimit -n 65535 && ./your_server`

## 高并发测试

运行高并发测试：

```bash
# 启动服务器
ulimit -n 65535 && ./bench_server_usockets

# 运行测试 (5000-10000 并发)
ulimit -n 65535 && go run v-hono/tests/test_high_concurrency.go

# 单独测试某个级别
ulimit -n 65535 && go run v-hono/tests/test_high_concurrency.go 8000
```

## 问题排查

如果高并发测试失败，检查：

1. 服务器是否正常响应：`curl http://localhost:8080/health`
2. 系统参数：`sysctl kern.ipc.somaxconn`
3. 文件描述符限制：`ulimit -n`
4. 测试客户端是否有端口耗尽问题

## 版本信息

- uSockets backlog: 16384
- 测试日期: 2026-01-03
- 测试通过最大并发: 10,000（不使用渐进式启动）
