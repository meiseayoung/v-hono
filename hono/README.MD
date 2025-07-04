## Trie 路由树（高性能路由）

### 简介
Trie 路由树是一种高性能的路由匹配结构，广泛应用于现代 Web 框架。相比传统的正则遍历路由，Trie 路由树在大规模路由和高并发场景下具有更高的查找效率。

### 特性
- 支持静态路由、命名参数（如 `/user/:id`）、通配符（如 `/static/*filepath`）
- 支持正则路由（如 `/user/(?P<id>[^/]+)`），正则路由单独分流
- 路由树根节点按 HTTP 方法（GET/POST/PUT/DELETE）分流，进一步提升查找效率
- 内置 LRU 路由缓存，热点路由命中极快
- 性能测试显示 Trie 路由树在大规模动态路由下性能优于传统正则遍历

### 用法
注册路由时，框架会自动将路由注册到 Trie 路由树和 HybridRouter：

```v
app.get('/api/users/:id', fn (req hono.Request) http.Response {
    return hono.Response.json('{"user_id": "${req.param["id"]}"}')
})
```

### 性能优势
- 静态路由、参数路由、通配符路由查找均为 O(n)（n为路径层级），极快
- 路由缓存命中时，查找仅需一次 map 查询，QPS 可达 20~30 万
- 支持上千条动态路由、百万级请求高并发场景

### 缓存说明
- Trie 路由树内置 LRU 缓存（默认容量1000），缓存 key 为 `method:path`，value 为 `RouteMatch`
- 命中缓存时性能极高，未命中时自动查找并写入缓存
- 可根据实际需求调整缓存容量

### 与 HybridRouter 对比
- HybridRouter 采用静态路由 map + 动态正则遍历，适合路由数量较少或兼容性需求高的场景
- TrieRouter 适合大规模路由、高并发、极致性能场景
- 两者可并存，便于灵活切换和对比测试 