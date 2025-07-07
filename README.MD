# V-Hono

一个用 V 语言编写的轻量级 Web 框架，灵感来自 Hono.js。

## 特性

- 🚀 高性能路由系统（混合路由算法）
- 🎯 类似 Hono.js 的 Context API
- 🔧 洋葱模型中间件支持
- 📦 内置 LRU 缓存系统
- 🛠️ 支持动态路由参数（`:param`）
- ⚡ 支持通配符路由（`*` 和 `**`）
- 🔄 支持所有 HTTP 方法（GET、POST、PUT、DELETE、PATCH、HEAD、OPTIONS）
- 🏗️ 构造函数风格的 API 设计

## 安装

```bash
# 克隆仓库
git clone https://github.com/your-username/v-hono.git
cd v-hono

# 运行示例
v run example.v
```

## 快速开始

```v
module main

import hono
import net.http

fn main() {
    mut app := hono.new_hono()
    
    // 基本路由
    app.get('/', fn (mut c hono.Context) http.Response {
        return c.html('<h1>Hello V-Hono!</h1>')
    })
    
    app.get('/api/users/:id', fn (mut c hono.Context) http.Response {
        user_id := c.params['id']
        return c.json('{"id": "${user_id}", "name": "John Doe"}')
    })
    
    app.post('/api/users', fn (mut c hono.Context) http.Response {
        c.status(201)
        return c.json('{"message": "User created", "data": "${c.body}"}')
    })
    
    // 中间件
    app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
        println('[LOG] ${c.url}')
        return next(mut c)
    })
    
    app.listen(':3000')
}
```

## API 参考

### Context

Context 是请求的核心对象，包含所有请求和响应信息：

```v
pub struct Context {
pub:
    req    http.Request      // 原始 HTTP 请求
    params map[string]string // 路径参数
    query  map[string]string // 查询参数
    url    string           // 请求 URL
pub mut:
    status_code int = 200   // 响应状态码
    headers     map[string]string // 响应头
    body        string      // 响应体
}
```

### 构造函数

所有对象都使用构造函数风格创建：

```v
// 创建 Context
ctx := hono.Context.new(req, params, query, body)

// 创建路由器
router := hono.ContextHybridRouter.new()
trie_router := hono.ContextTrieRouter.new()

// 创建缓存
cache := hono.ContextLRUCache.new(1000)
```

### 路由方法

支持所有 HTTP 方法：

```v
// GET 请求
app.get('/path', fn (mut c hono.Context) http.Response {
    return c.json('{"message": "GET response"}')
})

// POST 请求
app.post('/path', fn (mut c hono.Context) http.Response {
    return c.json('{"message": "POST response"}')
})

// PUT 请求
app.put('/path', fn (mut c hono.Context) http.Response {
    return c.json('{"message": "PUT response"}')
})

// DELETE 请求
app.delete('/path', fn (mut c hono.Context) http.Response {
    c.status(204)
    return c.text('')
})

// PATCH 请求
app.patch('/path', fn (mut c hono.Context) http.Response {
    return c.json('{"message": "PATCH response"}')
})

// HEAD 请求
app.head('/path', fn (mut c hono.Context) http.Response {
    return c.text('')
})

// OPTIONS 请求
app.options('/path', fn (mut c hono.Context) http.Response {
    return c.text('')
})
```

### 动态路由

支持路径参数和通配符：

```v
// 单参数
app.get('/users/:id', fn (mut c hono.Context) http.Response {
    user_id := c.params['id']
    return c.json('{"id": "${user_id}"}')
})

// 多参数
app.get('/posts/:id/comments/:comment_id', fn (mut c hono.Context) http.Response {
    post_id := c.params['id']
    comment_id := c.params['comment_id']
    return c.json('{"post_id": "${post_id}", "comment_id": "${comment_id}"}')
})

// 嵌套参数
app.get('/api/users/:user_id/posts/:post_id', fn (mut c hono.Context) http.Response {
    user_id := c.params['user_id']
    post_id := c.params['post_id']
    return c.json('{"user_id": "${user_id}", "post_id": "${post_id}"}')
})

// 通配符
app.get('/files/*', fn (mut c hono.Context) http.Response {
    file_path := c.params['*']
    return c.text('File: ${file_path}')
})

// 多级通配符
app.get('/api/**/search', fn (mut c hono.Context) http.Response {
    return c.json('{"search": "wildcard"}')
})
```

### 响应方法

所有响应方法直接返回 `http.Response`：

```v
// JSON 响应
return c.json('{"message": "Hello"}')

// 文本响应
return c.text('Hello World')

// HTML 响应
return c.html('<h1>Hello</h1>')

// 设置状态码
c.status(404)
return c.json('{"error": "Not Found"}')
```

### 中间件

支持洋葱模型中间件：

```v
// 日志中间件
app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
    println('[${time.now()}] ${c.req.method} ${c.url}')
    return next(mut c)
})

// 认证中间件
app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
    token := c.query['token']
    if token == '' {
        c.status(401)
        return c.json('{"error": "Unauthorized"}')
    }
    return next(mut c)
})

// 性能监控中间件
app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
    start := time.now()
    response := next(mut c)
    duration := time.now() - start
    println('请求处理时间: ${duration.milliseconds()}ms')
    return response
})
```

### 查询参数和请求体

```v
// 获取查询参数
app.get('/search', fn (mut c hono.Context) http.Response {
    query := c.query['q']
    page := c.query['page']
    return c.json('{"query": "${query}", "page": "${page}"}')
})

// 获取请求体
app.post('/api/data', fn (mut c hono.Context) http.Response {
    println('请求体: ${c.body}')
    return c.json('{"received": "${c.body}"}')
})
```

### 路由统计和缓存

```v
// 获取路由统计信息
static_count, dynamic_count, cache_size, cache_capacity := app.get_router_stats()
println('静态路由: ${static_count}, 动态路由: ${dynamic_count}')
println('缓存: ${cache_size}/${cache_capacity}')

// 清理缓存
app.clear_cache()
```

## 示例

运行完整示例：

```bash
v run example.v
```

示例包含：
- 静态路由
- 动态路由（单参数、多参数、嵌套参数）
- 所有 HTTP 方法
- 中间件功能
- 参数提取和查询参数处理

## 性能特性

- **混合路由算法**：静态路由 O(1) 查找，动态路由正则匹配
- **LRU 缓存**：自动缓存路由匹配结果
- **Trie 路由树**：支持复杂路径匹配
- **内存优化**：使用指针和堆分配优化性能

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

