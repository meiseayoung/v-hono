# 用户角色菜单管理系统

基于 v-hono 框架的用户认证和权限管理系统，提供完整的用户角色管理和动态菜单功能。

## 功能特性

### 🔐 用户认证
- 用户注册和登录
- JWT 令牌认证
- 密码加密存储
- 会话管理

### 👥 角色管理
- 多级角色系统（admin、manager、user、guest）
- 基于角色的权限控制
- 灵活的权限分配

### 📋 菜单管理
- 动态菜单系统
- 树形菜单结构
- 基于权限的菜单显示
- 菜单排序和图标支持

### 🛡️ 安全特性
- 密码 SHA256 加密
- 令牌过期机制
- 中间件权限验证
- 防止路径遍历攻击

## 系统架构

```
v-hono/
├── hono/
│   ├── auth.v              # 认证核心模块
│   ├── auth_routes.v       # 认证路由
│   ├── database.v          # 数据库管理
│   ├── request.v           # 请求处理
│   └── app.v              # 应用框架
├── auth_example.v          # 完整示例
└── README_AUTH_SYSTEM.md   # 本文档
```

## 快速开始

### 1. 编译和运行

```bash
# 编译示例应用
v auth_example.v

# 运行应用
./auth_example
```

### 2. 访问系统

打开浏览器访问：`http://localhost:3000`

### 3. 默认用户

系统预创建了以下示例用户：

| 用户名 | 密码 | 角色 | 权限 |
|--------|------|------|------|
| admin | admin123 | admin | 所有权限 |
| manager | manager123 | manager | 读写管理权限 |
| user | user123 | user | 读写权限 |
| guest | guest123 | guest | 只读权限 |

## API 接口

### 认证接口

#### 用户注册
```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "newuser",
  "email": "user@example.com",
  "password": "password123",
  "role": "user"
}
```

#### 用户登录
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}
```

响应：
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": 1640995200
}
```

#### 获取用户信息
```http
GET /api/auth/profile
Authorization: <token>
```

#### 用户注销
```http
POST /api/auth/logout
Authorization: <token>
```

### 菜单接口

#### 获取用户菜单
```http
GET /api/auth/menus
Authorization: <token>
```

#### 获取所有菜单（管理员）
```http
GET /api/auth/menus/all
Authorization: <token>
```

#### 创建菜单项（管理员）
```http
POST /api/auth/menus
Authorization: <token>
Content-Type: application/json

{
  "name": "新菜单",
  "path": "/new-menu",
  "icon": "📄",
  "parent_id": 0,
  "sort_order": 1,
  "permissions": ["read", "write"]
}
```

### 受保护的路由

#### 用户路由
```http
GET /api/protected/user
Authorization: <token>
```

#### 管理员路由
```http
GET /api/protected/admin
Authorization: <token>
```

## 角色权限说明

### Admin（超级管理员）
- 拥有所有权限
- 可以管理所有用户和菜单
- 可以访问所有系统功能

### Manager（管理员）
- 拥有读写和管理权限
- 可以管理用户和菜单
- 可以访问大部分系统功能

### User（普通用户）
- 拥有读写权限
- 可以查看和编辑内容
- 无法管理系统设置

### Guest（访客）
- 只有只读权限
- 只能查看公开内容
- 无法进行任何修改操作

## 菜单权限配置

菜单项通过 `permissions` 字段控制访问权限：

```json
{
  "name": "用户管理",
  "path": "/users",
  "icon": "👥",
  "permissions": ["read", "write", "manage"]
}
```

权限说明：
- `read`: 只读权限
- `write`: 读写权限
- `manage`: 管理权限
- `*`: 所有权限（仅管理员）

## 中间件使用

### 认证中间件
```v
// 添加认证中间件
app.use(hono.auth_middleware(auth_manager))
```

### 权限中间件
```v
// 添加权限检查中间件
app.use(hono.permission_middleware('manage'))
```

## 数据库结构

### users 表
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL,
    status BOOLEAN DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

### menu_items 表
```sql
CREATE TABLE menu_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    path TEXT NOT NULL,
    icon TEXT,
    parent_id INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    permissions TEXT,
    status BOOLEAN DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

### user_sessions 表
```sql
CREATE TABLE user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token TEXT UNIQUE NOT NULL,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id)
);
```

## 开发指南

### 添加新的认证功能

1. 在 `auth.v` 中添加新的方法
2. 在 `auth_routes.v` 中添加对应的路由
3. 更新前端界面

### 自定义权限

1. 修改 `UserRole` 枚举
2. 更新 `check_permission` 方法
3. 调整菜单权限配置

### 扩展菜单功能

1. 添加菜单编辑和删除接口
2. 实现菜单拖拽排序
3. 添加菜单缓存机制

## 安全建议

1. **密码安全**
   - 使用强密码策略
   - 定期更换密码
   - 启用密码复杂度检查

2. **令牌安全**
   - 设置合理的过期时间
   - 实现令牌刷新机制
   - 支持令牌撤销

3. **权限控制**
   - 最小权限原则
   - 定期审查权限
   - 记录权限变更日志

4. **数据安全**
   - 数据库加密
   - 定期备份
   - 访问日志记录

## 故障排除

### 常见问题

1. **数据库连接失败**
   - 检查数据库文件权限
   - 确保 SQLite 支持
   - 验证数据库路径

2. **认证失败**
   - 检查用户名密码
   - 验证令牌格式
   - 确认令牌未过期

3. **权限不足**
   - 检查用户角色
   - 验证菜单权限配置
   - 确认中间件配置

### 调试模式

启用调试输出：
```v
// 在代码中添加调试信息
println('Debug: $debug_info')
```

## 性能优化

1. **数据库优化**
   - 添加适当的索引
   - 使用连接池
   - 优化查询语句

2. **缓存策略**
   - 菜单缓存
   - 用户信息缓存
   - 权限缓存

3. **并发处理**
   - 使用连接池
   - 实现请求队列
   - 优化锁机制

## 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 许可证

MIT License

## 联系方式

如有问题或建议，请提交 Issue 或联系开发团队。 