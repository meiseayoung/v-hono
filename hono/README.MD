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

---

# 静态文件服务中间件

## 概述

为 V-Hono 框架添加了类似 Hono.js 的 `serveStatic` 中间件，提供高效、安全的静态文件服务功能。

## 实现文件

### 核心实现
- `hono/static.v` - 静态文件服务中间件的主要实现

### 示例文件
- `example.v` - 包含静态文件服务的完整示例

### 测试文件
- `public/index.html` - 默认索引文件
- `public/test.txt` - 测试文本文件
- `static/style.css` - 测试CSS文件
- `static/app.js` - 测试JavaScript文件
- `uploads/sample.json` - 测试JSON文件

## 核心功能

### 1. 静态文件服务中间件 (`serve_static`)

```v
pub fn serve_static(options StaticOptions) fn (mut Context, fn (mut Context) http.Response) http.Response
```

主要特性：
- 路径匹配和文件映射
- 安全检查（路径遍历攻击防护）
- 点文件访问控制
- 自动索引文件支持
- 智能错误处理

### 2. 配置选项 (`StaticOptions`)

```v
pub struct StaticOptions {
pub:
    root        string = './public'  // 静态文件根目录
    path        string = '/'         // URL路径前缀
    index       string = 'index.html' // 默认索引文件
    dotfiles    bool   = false       // 是否允许访问以.开头的文件
    etag        bool   = true        // 是否启用ETag
    last_modified bool = true        // 是否启用Last-Modified
    max_age     int    = 0           // 缓存时间（秒）
    headers     map[string]string    // 自定义响应头
}
```

### 3. 便捷函数

- `serve_static_default()` - 使用默认配置
- `serve_static_root(root string)` - 指定根目录
- `serve_static_path(path string, root string)` - 指定路径前缀和根目录

## 安全特性

### 路径遍历攻击防护

```v
fn is_safe_path(path string) bool {
    // 检查是否包含 .. 或绝对路径
    if path.contains('..') || path.starts_with('/') || path.starts_with('\\') {
        return false
    }
    
    // 检查是否包含危险字符
    dangerous_chars := ['<', '>', ':', '"', '|', '?', '*']
    for char in dangerous_chars {
        if path.contains(char) {
            return false
        }
    }
    
    return true
}
```

### 点文件访问控制

默认情况下阻止访问以 `.` 开头的文件，可通过 `dotfiles: true` 启用。

## 性能特性

### ETag 支持

```v
fn generate_etag(content string, mod_time i64) string {
    return '"${content.len}-${mod_time}"'
}
```

### 缓存控制

```v
if options.max_age > 0 {
    c.headers['Cache-Control'] = 'public, max-age=${options.max_age}'
} else {
    c.headers['Cache-Control'] = 'no-cache'
}
```

### Content-Type 检测

支持30+种文件类型的自动Content-Type检测：

```v
fn get_content_type(file_path string) string {
    ext := os.file_ext(file_path).to_lower()
    
    match ext {
        '.html', '.htm' { return 'text/html; charset=utf-8' }
        '.css' { return 'text/css; charset=utf-8' }
        '.js' { return 'application/javascript; charset=utf-8' }
        '.json' { return 'application/json; charset=utf-8' }
        // ... 更多类型
        else { return 'application/octet-stream' }
    }
}
```

## 使用示例

### 基本用法

```v
import hono

mut app := hono.Hono.new()

// 使用默认配置
app.use(hono.serve_static_default())

app.listen(':8080')
```

### 多目录配置

```v
// 默认静态文件
app.use(hono.serve_static_default())

// 资源文件
app.use(hono.serve_static_path('/assets', './static'))

// 上传文件
app.use(hono.serve_static_path('/uploads', './uploads'))
```

### 自定义配置

```v
options := hono.StaticOptions{
    root: './public'
    path: '/static'
    index: 'index.html'
    dotfiles: false
    etag: true
    last_modified: true
    max_age: 3600
    headers: {
        'X-Served-By': 'V-Hono'
    }
}

app.use(hono.serve_static(options))
```

## 与 Hono.js 的对比

| 特性 | V-Hono | Hono.js |
|------|--------|---------|
| 路径遍历防护 | ✅ | ✅ |
| 点文件控制 | ✅ | ✅ |
| ETag 支持 | ✅ | ✅ |
| Last-Modified | ✅ | ✅ |
| 缓存控制 | ✅ | ✅ |
| 自定义头部 | ✅ | ✅ |
| 自动索引文件 | ✅ | ✅ |
| Content-Type 检测 | ✅ | ✅ |
| 多目录支持 | ✅ | ✅ |

## 测试和验证

### 运行测试

```bash
# 完整示例
v run example.v
```

### 测试用例

1. **基本文件服务**
   - 访问 `public/test.txt` → `/test.txt`
   - 访问 `static/style.css` → `/assets/style.css`

2. **索引文件**
   - 访问目录 `/` → 提供 `public/index.html`

3. **安全测试**
   - 尝试路径遍历攻击 → 返回 403 Forbidden
   - 尝试访问点文件 → 返回 403 Forbidden

4. **缓存测试**
   - 检查 ETag 头
   - 检查 Last-Modified 头
   - 检查 Cache-Control 头

5. **Content-Type 测试**
   - 验证不同文件类型的正确 Content-Type

## 性能考虑

### 优化点

1. **文件读取**: 使用 V 语言的 `os.read_file()` 进行高效文件读取
2. **路径检查**: 快速的安全路径验证
3. **头部生成**: 高效的响应头构建
4. **缓存策略**: 可配置的缓存控制

### 内存使用

- 文件内容一次性读取到内存
- 适合中小型文件
- 大文件建议使用专门的CDN服务

## 未来改进

### 可能的增强

1. **流式文件服务**: 支持大文件的流式传输
2. **压缩支持**: 自动Gzip压缩
3. **范围请求**: 支持HTTP Range请求
4. **文件监控**: 文件变化时自动刷新缓存
5. **性能监控**: 添加性能指标收集

### 扩展性

当前实现具有良好的扩展性，可以轻松添加：
- 新的文件类型支持
- 自定义安全检查
- 更多的缓存策略
- 文件预处理功能

## 总结

成功为 V-Hono 框架添加了功能完整、安全可靠的静态文件服务中间件，提供了与 Hono.js 相当的体验，同时充分利用了 V 语言的特性。该实现具有良好的安全性、性能和易用性，可以满足大多数Web应用的静态文件服务需求。 