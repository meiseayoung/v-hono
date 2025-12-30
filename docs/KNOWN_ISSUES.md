# 已知问题

## 1. HTTP Keep-Alive 连接复用优化

**状态**: 已优化 (2025-12-30)

**问题描述**: 
在超高并发（5000 req, 200 concurrent）的 URL Params 测试中出现稳定性问题（成功率仅 0.24%）。

**根本原因**:
1. picoev 的 `max_fds = 1024` 限制了并发连接数
2. 虽然设置了 `Connection: keep-alive` 头，但连接管理不够优化
3. 高并发下客户端端口耗尽（TCP TIME_WAIT 状态累积）
4. 缺少 `Content-Length` 头导致客户端无法正确解析响应边界

**已实施的优化**:

### 1. 增强 Keep-Alive 支持
- 添加 `Keep-Alive` 响应头，包含 `timeout` 和 `max` 参数
- 检测客户端 Keep-Alive 请求头
- 根据客户端请求决定是否保持连接

### 2. 响应头优化
- 始终设置 `Content-Length` 头，帮助客户端正确解析响应边界
- 优化 `Content-Type` 默认值

### 3. 高并发配置
新增 `HighConcurrencyConfig` 和 `listen_high_concurrency()` 方法：
```v
// 使用高并发优化配置启动
app.listen_high_concurrency(8081)

// 或使用自定义配置
config := hono.HighConcurrencyConfig{
    port: 8081
    timeout_secs: 5           // 较短超时
    keepalive_timeout: 3      // Keep-Alive 超时
    max_keepalive_req: 500    // 单连接最大请求数
}
app.listen_high_concurrency_with_config(config)
```

### 4. 服务器配置优化
- 降低默认超时时间（8秒 -> 5秒）以更快释放连接
- 增大写缓冲区（8KB -> 64KB）
- 添加 TCP_NODELAY 配置选项

**使用建议**:
1. 高并发场景使用 `--high-concurrency` 或 `-hc` 参数启动服务器
2. 在服务器前部署支持 Keep-Alive 的反向代理（如 nginx）
3. 使用压力测试工具验证: `v run examples/stress_test.v`

**picoev 底层限制**:
- `max_fds = 1024` 是 picoev 的硬编码限制
- 真正的连接复用需要 picoev 底层支持
- 建议关注 V 语言官方对 picoev 的更新

**跟踪**:
- V 语言 GitHub: https://github.com/vlang/v
- 相关文件: `vlib/picoev/picoev.v`

**更新日期**: 2025-12-30
