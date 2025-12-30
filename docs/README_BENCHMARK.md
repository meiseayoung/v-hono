# vweb vs v-hono 性能对比测试

## 测试文件说明

| 文件 | 说明 |
|------|------|
| `benchmark_vweb_vs_hono.v` | 路由匹配性能测试（纯路由，不启动服务器） |
| `server_vweb.v` | vweb HTTP 服务器示例（端口 8080） |
| `server_hono.v` | v-hono HTTP 服务器示例（端口 8081） |

## 快速开始

### 1. 路由匹配性能测试

```bash
v run benchmark_vweb_vs_hono.v
```

### 2. HTTP 服务器压测

启动 vweb 服务器：
```bash
v run server_vweb.v
```

启动 v-hono 服务器（另一个终端）：
```bash
v run server_hono.v
```

使用 wrk 或 ab 进行压测：
```bash
# 测试 vweb
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
