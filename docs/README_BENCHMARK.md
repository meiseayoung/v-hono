# veb vs v-hono 性能对比测试

## 测试文件说明

| 文件 | 说明 |
|------|------|
| `benchmark_veb_vs_hono.v` | 路由匹配性能测试（纯路由，不启动服务器） |
| `server_veb.v` | veb HTTP 服务器示例（端口 8080）- V 语言官方新版 web 框架 |
| `server_vweb.v` | vweb HTTP 服务器示例（端口 8080）- 旧版兼容 |
| `server_hono.v` | v-hono HTTP 服务器示例（端口 8081） |
| `http_benchmark.v` | HTTP 压测工具（自动对比两个服务器） |
| `run_benchmark.ps1` | Windows PowerShell 一键测试脚本 |

## 快速开始

### Windows 用户（推荐）

```powershell
cd examples
.\run_benchmark.ps1
```

### 1. 路由匹配性能测试

```bash
cd examples
v run benchmark_veb_vs_hono.v
```

### 2. HTTP 服务器压测

#### 方式一：使用内置压测工具

终端 1 - 启动 veb 服务器：
```bash
v run server_veb.v
```

终端 2 - 启动 v-hono 服务器：
```bash
v run server_hono.v
```

终端 3 - 运行压测：
```bash
v run http_benchmark.v
```

#### 方式二：使用 wrk 或 ab

```bash
# 测试 veb
wrk -t4 -c100 -d10s http://localhost:8080/
wrk -t4 -c100 -d10s http://localhost:8080/api/users/123

# 测试 v-hono
wrk -t4 -c100 -d10s http://localhost:8081/
wrk -t4 -c100 -d10s http://localhost:8081/api/users/123
```

或使用 Apache Bench：
```bash
ab -n 10000 -c 100 http://localhost:8080/
ab -n 10000 -c 100 http://localhost:8081/
```

### 3. 编译优化版本（推荐用于正式压测）

```bash
cd examples
v -prod server_veb.v -o server_veb.exe
v -prod server_hono.v -o server_hono.exe
v -prod http_benchmark.v -o http_benchmark.exe
```

## 测试结果分析

### 路由匹配性能

| 路由类型 | 简单路由器 (模拟 vweb) | v-hono FastRouter |
|----------|------------------------|-------------------|
| 静态路由 | ~1000 ns/op | ~9500 ns/op |
| 动态路由 | ~15000-25000 ns/op | ~9500 ns/op |

**结论：**
- 静态路由：简单路由器更快（直接 map 查找）
- 动态路由：v-hono 更快且更稳定（使用缓存和优化的正则匹配）
- v-hono 的优势在于动态路由性能一致，不随路由复杂度增加而显著下降

## 测试端点

| 端点 | 类型 | 说明 |
|------|------|------|
| `GET /` | 静态 | Hello World |
| `GET /api/health` | 静态 | 健康检查 |
| `GET /api/users` | 静态 | 获取用户列表 |
| `POST /api/users` | 静态 | 创建用户 |
| `GET /api/users/:id` | 动态 | 获取单个用户 |
| `GET /api/users/:id/posts` | 动态 | 获取用户的帖子 |
| `GET /api/users/:user_id/posts/:post_id` | 动态 | 获取特定帖子 |
| `GET /api/categories/:cat/items/:item` | 动态 | 获取分类商品 |


## 测试结果分析

### 路由匹配性能

| 路由类型 | SimpleRouter (模拟 veb) | v-hono FastRouter |
|----------|-------------------------|-------------------|
| 静态路由 | ~1000 ns/op | ~9500 ns/op |
| 动态路由 | ~15000-25000 ns/op | ~9500 ns/op |

### HTTP 吞吐量（参考值）

| 端点类型 | veb | v-hono | 说明 |
|----------|-----|--------|------|
| 静态路由 | ~15000 req/s | ~12000 req/s | veb 略快 |
| 动态路由 | ~8000 req/s | ~10000 req/s | v-hono 更稳定 |

> 注：实际性能取决于硬件配置和系统负载

## 结论

- **静态路由**：veb/SimpleRouter 使用 map 直接查找，通常更快
- **动态路由**：v-hono 使用 Trie + 缓存，性能更稳定
- **v-hono 优势**：动态路由性能一致，不随路由复杂度增加而显著下降
- **veb 优势**：官方支持，与 V 语言生态集成更好

## 测试端点

| 端点 | 类型 | 说明 |
|------|------|------|
| `GET /` | 静态 | Hello World |
| `GET /api/health` | 静态 | 健康检查 |
| `GET /api/users` | 静态 | 获取用户列表 |
| `POST /api/users` | 静态 | 创建用户 |
| `GET /api/users/:id` | 动态 | 获取单个用户 |
| `GET /api/users/:id/posts` | 动态 | 获取用户的帖子 |
| `GET /api/users/:user_id/posts/:post_id` | 动态 | 获取特定帖子 |
| `GET /api/categories/:cat/items/:item` | 动态 | 获取分类商品 |

## 注意事项

1. **veb vs vweb**：veb 是 V 语言官方的新版 web 框架，替代了旧的 vweb
2. **编译优化**：正式压测时请使用 `-prod` 编译优化版本
3. **预热**：测试前建议先发送一些请求预热服务器
4. **环境隔离**：压测时关闭其他占用 CPU 的程序
