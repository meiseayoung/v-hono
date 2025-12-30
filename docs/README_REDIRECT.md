# Redirect 功能文档

v-hono 现在支持 HTTP 重定向功能，与 Hono.js 的 `c.redirect()` API 兼容。

## 基本用法

### 基本重定向 (302 Found)

```v
app.get('/old-page', fn (mut c hono.Context) hono.Response {
    return c.redirect('https://example.com/new-page')
})
```

### 带状态码的重定向

```v
// 301 Moved Permanently - 永久重定向
app.get('/old-url', fn (mut c hono.Context) hono.Response {
    return c.redirect('https://example.com/new-url', 301)
})

// 303 See Other - 通常用于 POST 后重定向
app.post('/form-submit', fn (mut c hono.Context) hono.Response {
    // 处理表单数据...
    return c.redirect('/success', 303)
})

// 307 Temporary Redirect - 临时重定向，保持请求方法
app.get('/temp-redirect', fn (mut c hono.Context) hono.Response {
    return c.redirect('/new-location', 307)
})

// 308 Permanent Redirect - 永久重定向，保持请求方法
app.get('/perm-redirect', fn (mut c hono.Context) hono.Response {
    return c.redirect('/new-location', 308)
})
```

## API 参考

### `c.redirect(url, status_code...)`

**参数:**
- `url` (string): 重定向的目标 URL，可以是绝对 URL 或相对路径
- `status_code` (int, 可选): HTTP 状态码，默认为 302

**返回值:**
- `http.Response`: 包含适当状态码和 Location 头的 HTTP 响应

**支持的状态码:**
- `301` - Moved Permanently (永久重定向)
- `302` - Found (临时重定向，默认)
- `303` - See Other (查看其他位置)
- `307` - Temporary Redirect (临时重定向，保持方法)
- `308` - Permanent Redirect (永久重定向，保持方法)

## 使用场景

### 1. 基本页面重定向

```v
app.get('/home', fn (mut c hono.Context) hono.Response {
    return c.redirect('/')
})
```

### 2. 条件重定向

```v
app.get('/mobile-check', fn (mut c hono.Context) hono.Response {
    user_agent := c.req.header.get_custom('User-Agent') or { '' }
    
    if user_agent.contains('Mobile') {
        return c.redirect('/mobile')
    } else {
        return c.redirect('/desktop')
    }
})
```

### 3. 表单提交后重定向 (PRG 模式)

```v
app.post('/login', fn (mut c hono.Context) hono.Response {
    // 验证用户凭据...
    if login_successful {
        return c.redirect('/dashboard', 303)
    } else {
        return c.redirect('/login?error=1', 303)
    }
})
```

### 4. URL 规范化

```v
app.get('/UPPERCASE', fn (mut c hono.Context) hono.Response {
    return c.redirect('/lowercase', 301)
})

app.get('/trailing-slash/', fn (mut c hono.Context) hono.Response {
    return c.redirect('/trailing-slash', 301)
})
```

### 5. 外部重定向

```v
app.get('/external', fn (mut c hono.Context) hono.Response {
    return c.redirect('https://external-site.com')
})
```

## 重定向状态码说明

| 状态码 | 名称 | 说明 | 浏览器行为 |
|--------|------|------|------------|
| 301 | Moved Permanently | 永久重定向，搜索引擎会更新索引 | 缓存重定向，保持原方法 |
| 302 | Found | 临时重定向，默认状态码 | 不缓存，可能改变方法为 GET |
| 303 | See Other | 查看其他位置，常用于 POST 后重定向 | 总是使用 GET 方法 |
| 307 | Temporary Redirect | 临时重定向，保持原请求方法 | 不缓存，保持原方法 |
| 308 | Permanent Redirect | 永久重定向，保持原请求方法 | 缓存重定向，保持原方法 |

## 最佳实践

1. **使用适当的状态码**: 根据重定向的性质选择正确的状态码
2. **避免重定向循环**: 确保重定向不会形成无限循环
3. **使用绝对 URL**: 对于外部重定向，使用完整的 URL
4. **SEO 考虑**: 对于永久性的 URL 变更使用 301 状态码
5. **POST 后重定向**: 使用 303 状态码避免重复提交

## 示例应用

查看 `examples/redirect_demo.v` 获取完整的使用示例。

## 与 Hono.js 的兼容性

v-hono 的 `c.redirect()` 方法与 Hono.js 的 API 完全兼容：

```javascript
// Hono.js
c.redirect('https://example.com')
c.redirect('https://example.com', 301)
```

```v
// v-hono
c.redirect('https://example.com')
c.redirect('https://example.com', 301)
```