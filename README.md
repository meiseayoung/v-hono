# V-Hono

一个用 V 语言编写的高性能 Web 框架，灵感来自 [Hono.js](https://hono.dev/)。

## 特性

- 🚀 高性能路由系统（FastRouter + LRU 缓存 + 预编译正则）
- 🎯 类似 Hono.js 的 Context API
- 🔧 洋葱模型中间件支持
- 📦 内置 LRU 缓存系统
- 🛠️ 动态路由参数（`:param`）和通配符路由（`*`、`**`）
- 🔄 支持所有 HTTP 方法（GET、POST、PUT、DELETE、PATCH、HEAD、OPTIONS）
- 🏗️ 路由分组与子应用中间件继承
- 📁 静态文件服务中间件
- 🛡️ 内置安全防护（路径遍历攻击防护、点文件访问控制）
- 💾 智能缓存支持（ETag、Last-Modified、Cache-Control）
- 📤 大文件分片上传（断点续传、秒传、自动合并）
- 🔐 用户认证系统（JWT、角色权限、菜单管理）
- 📊 配置管理系统
- 🗄️ SQLite 数据库集成

## 性能测试

基于 100,000 次迭代的路由匹配性能测试：

| 框架 | 平均延迟 | 吞吐量 |
|------|---------|--------|
| v-hono | 5,621 ns/op | **177,904 ops/sec** |
| 简单路由器 | 9,265 ns/op | 107,933 ops/sec |

v-hono 在动态路由场景下优势明显，得益于 LRU 缓存和预编译正则表达式。

## 安装

```bash
git clone https://github.com/meiseayoung/v-hono.git
cd v-hono
v run example.v
```

## 快速开始

```v
import hono
import net.http

fn main() {
    mut app := hono.Hono.new()
    
    // 基本路由
    app.get('/', fn (mut c hono.Context) http.Response {
        return c.html('<h1>Hello V-Hono!</h1>')
    })
    
    // 动态路由
    app.get('/users/:id', fn (mut c hono.Context) http.Response {
        user_id := c.params['id']
        return c.json('{"id": "${user_id}"}')
    })
    
    // 中间件
    app.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
        println('[LOG] ${c.path}')
        return next(mut c)
    })
    
    app.listen(':3000')
}
```

## 路由分组

支持子应用路由分组，中间件自动继承：

```v
// 创建子应用
mut api := hono.Hono.new()

// 子应用中间件（只对 /api/* 生效）
api.use(fn (mut c hono.Context, next fn (mut hono.Context) http.Response) http.Response {
    c.headers['X-API-Version'] = '1.0'
    return next(mut c)
})

api.get('/users', fn (mut c hono.Context) http.Response {
    return c.json('{"users": []}')
})

// 挂载到主应用
app.route('/api', mut api)
```

## all() 方法

一次性为所有 HTTP 方法注册处理器：

```v
app.all('/echo', fn (mut c hono.Context) http.Response {
    return c.json('{"method": "${c.req.method}"}')
})
```

## 自定义错误处理

```v
// 自定义 404 处理器
app.not_found(fn (mut c hono.Context) http.Response {
    c.status(404)
    return c.json('{"error": "Not Found", "path": "${c.path}"}')
})

// 自定义错误处理器
app.on_error(fn (error_msg string, status_code int, mut c hono.Context) http.Response {
    c.status(status_code)
    return c.json('{"error": "${error_msg}"}')
})
```

## 静态文件服务

```v
// 默认配置（./public 目录）
app.use(hono.serve_static_default())

// 指定路径前缀和根目录
app.use(hono.serve_static_path('/assets', './static'))

// 自定义配置
options := hono.StaticOptions{
    root: './public'
    path: '/static'
    index: 'index.html'
    etag: true
    last_modified: true
    max_age: 3600
}
app.use(hono.serve_static(options))
```

## 响应方法

```v
// JSON 响应
return c.json('{"message": "Hello"}')

// 文本响应
return c.text('Hello World')

// HTML 响应
return c.html('<h1>Hello</h1>')

// 文件响应
return c.file('path/to/file.pdf')

// 设置状态码
c.status(201)
return c.json('{"created": true}')

// 错误响应
return c.not_found('Resource not found')
return c.unauthorized('Token required')
return c.forbidden('Access denied')
```


## 大文件分片上传

支持大文件分片上传、断点续传、秒传功能：

```v
mut upload_manager := hono.new_chunk_upload_manager(hono.ChunkUploadConfig{
    chunk_size: 1024 * 1024      // 1MB 分片
    max_file_size: 1024 * 1024 * 1024  // 最大 1GB
    temp_dir: './uploads/chunks'
    upload_dir: './uploads/files'
})

// 分片上传接口
app.post('/upload/chunk', fn [mut upload_manager] (mut c hono.Context) http.Response {
    return upload_manager.handle_chunk_upload(mut c)
})

// 上传状态查询
app.get('/upload/status', fn [mut upload_manager] (mut c hono.Context) http.Response {
    return upload_manager.get_upload_status(mut c)
})
```

### 前端示例

```javascript
// 请求池管理（控制并发）
const requestPool = new RequestPool(6);

// 分片上传
async function uploadChunk(file, chunk, { fileHash, chunkIndex, chunkHash }) {
    const form = new FormData();
    form.append('file_hash', fileHash);
    form.append('chunk_index', chunkIndex);
    form.append('chunk', chunk);
    
    const response = await fetch('/upload/chunk', { method: 'POST', body: form });
    return response.json();
}
```

详细文档：[README_CHUNK_UPLOAD.md](README_CHUNK_UPLOAD.md)

## 用户认证系统

内置完整的用户认证和权限管理：

```v
// 初始化认证管理器
mut db := hono.new_database_manager('./auth.db')
mut auth := hono.new_auth_manager(db)
auth.init_tables()!

// 创建用户
user := auth.create_user('admin', 'admin@example.com', 'password', .admin)!

// 用户登录
session := auth.login('admin', 'password')!

// 验证令牌
user := auth.verify_token(session.token)!

// 权限检查
if auth.check_permission(user, 'write') {
    // 允许操作
}
```

### 用户角色

- `admin` - 管理员（所有权限）
- `manager` - 管理者（read、write、manage）
- `user` - 普通用户（read、write）
- `guest` - 访客（read）

详细文档：[README_AUTH_SYSTEM.md](README_AUTH_SYSTEM.md)

## 配置管理

```v
// 加载配置
config := hono.load_config('config.json')!

// 获取配置值
db_path := config.get_string('database.path')
port := config.get_int('server.port')
debug := config.get_bool('debug')
```

## 项目结构

```
v-hono/
├── hono/                    # 核心模块
│   ├── app.v               # 主应用
│   ├── fast_router.v       # 快速路由器
│   ├── cache.v             # LRU 缓存
│   ├── auth.v              # 认证系统
│   ├── database.v          # 数据库管理
│   ├── upload.v            # 分片上传
│   ├── static.v            # 静态文件服务
│   ├── response.v          # 响应方法
│   ├── error_handler.v     # 错误处理
│   ├── security.v          # 安全模块
│   └── ...
├── public/                  # 静态文件目录
├── uploads/                 # 上传文件目录
├── example.v               # 完整示例
├── route_grouping_example_v2.v  # 路由分组示例
└── benchmark_vweb_vs_hono.v    # 性能测试
```

## API 参考

### Context

```v
pub struct Context {
pub:
    req    http.Request       // 原始请求
    params map[string]string  // 路径参数
    query  map[string]string  // 查询参数
    url    string            // 请求 URL
    path   string            // 请求路径
pub mut:
    status_code int = 200    // 响应状态码
    headers     map[string]string  // 响应头
    body        string       // 请求体
}
```

### 路由方法

```v
app.get(path, handler)      // GET 请求
app.post(path, handler)     // POST 请求
app.put(path, handler)      // PUT 请求
app.delete(path, handler)   // DELETE 请求
app.patch(path, handler)    // PATCH 请求
app.head(path, handler)     // HEAD 请求
app.options(path, handler)  // OPTIONS 请求
app.all(path, handler)      // 所有方法
```

### 动态路由

```v
// 单参数
app.get('/users/:id', handler)

// 多参数
app.get('/users/:id/posts/:post_id', handler)

// 通配符
app.get('/files/*path', handler)
```

### 中间件

```v
// 全局中间件
app.use(middleware)

// 子应用中间件（只对特定前缀生效）
mut api := hono.Hono.new()
api.use(api_middleware)
app.route('/api', mut api)
```

## 运行示例

```bash
# 完整示例
v run example.v

# 路由分组示例
v run route_grouping_example_v2.v

# 性能测试
v run benchmark_vweb_vs_hono.v
```

## 测试命令

```bash
# 基本测试
curl http://localhost:8080/
curl http://localhost:8080/api/health
curl http://localhost:8080/users/123

# POST 请求
curl -X POST http://localhost:8080/api/users -d '{"name":"John"}'

# 静态文件
curl http://localhost:8080/test.txt

# 分片上传
curl -X POST http://localhost:8080/upload/chunk \
  -F "file_hash=abc123" \
  -F "chunk_index=0" \
  -F "chunk=@file.part"
```

## 相关文档

- [分片上传系统](README_CHUNK_UPLOAD.md)
- [请求池系统](README_REQUEST_POOL.md)
- [认证系统](README_AUTH_SYSTEM.md)
- [数据库模块](README_DATABASE.md)
- [性能测试](README_BENCHMARK.md)

## 许可证

MIT License
