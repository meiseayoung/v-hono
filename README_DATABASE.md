# V-Hono 文件上传系统 - 数据库集成

## 概述

V-Hono 文件上传系统现在集成了 SQLite 数据库来管理文件信息，支持文件去重、版本管理和元数据存储。

## 新功能

### 1. 文件路径格式更新

合并后的文件现在使用新的命名格式：
```
./uploads/files/{filehash}.{filetype}
```

例如：
- `./uploads/files/a1b2c3d4e5f6.txt`
- `./uploads/files/1234567890abcdef.jpg`

### 2. 数据库表结构

```sql
CREATE TABLE file_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_uuid TEXT UNIQUE NOT NULL,      -- 文件唯一标识符
    file_hash TEXT NOT NULL,             -- 文件哈希值
    file_name TEXT NOT NULL,             -- 原始文件名
    file_size INTEGER NOT NULL,          -- 文件大小
    file_type TEXT NOT NULL,             -- 文件扩展名
    created_at INTEGER NOT NULL,         -- 创建时间
    updated_at INTEGER NOT NULL          -- 更新时间
);
```

### 3. 文件去重逻辑

- **相同 hash + 相同文件名**：更新现有记录
- **相同 hash + 不同文件名**：创建新记录（支持同一文件的不同名称）
- **不同 hash**：创建新记录

### 4. 新增 API 端点

#### 获取所有文件信息
```http
GET /api/files
```

#### 根据文件UUID获取文件信息
```http
GET /api/files/{uuid}
```

#### 根据文件hash获取文件信息
```http
GET /api/files/hash/{hash}
```

#### 删除文件信息
```http
DELETE /api/files/{uuid}
```

## 配置

在 `ChunkUploadConfig` 中添加了数据库配置：

```v
pub struct ChunkUploadConfig {
    // ... 其他配置
    db_path string = './uploads/files.db'  // 数据库文件路径
}
```

## 使用示例

### 1. 启动服务器

```bash
v run chunk_upload_example.v
```

### 2. 测试数据库功能

```bash
v run test_database.v
```

### 3. 上传文件

文件上传完成后，系统会：
1. 将文件保存为 `{filehash}.{filetype}` 格式
2. 在数据库中记录文件信息
3. 返回文件UUID

### 4. 查询文件信息

```bash
# 获取所有文件
curl http://localhost:8080/api/files

# 根据UUID获取文件信息
curl http://localhost:8080/api/files/{uuid}

# 根据hash获取文件信息
curl http://localhost:8080/api/files/hash/{hash}
```

## 数据库操作

### 插入或更新文件信息

```v
file_info := db.insert_or_update_file(file_hash, file_name, file_size, file_type)
```

### 查询文件信息

```v
// 根据hash查询
file_info := db.get_file_by_hash(file_hash)

// 根据UUID查询
file_info := db.get_file_by_uuid(file_uuid)

// 获取所有文件
files := db.get_all_files()
```

### 删除文件信息

```v
db.delete_file(file_uuid)
```

## 依赖

项目现在依赖 `vlang/sqlite` 模块：

```v
// v.mod
dependencies: ['vlang/sqlite']
```

## 文件结构

```
v-hono/
├── hono/
│   ├── database.v          # 数据库管理模块
│   ├── upload.v            # 上传模块（已更新）
│   └── ...
├── chunk_upload_example.v  # 示例应用（已更新）
├── test_database.v         # 数据库测试
└── uploads/
    ├── files/              # 最终文件目录
    ├── chunks/             # 分片文件目录
    └── files.db            # SQLite数据库文件
```

## 注意事项

1. 数据库文件会自动创建在 `uploads/` 目录下
2. 文件去重基于文件hash，支持同一文件的不同名称
3. 每个文件都有唯一的UUID，用于API访问
4. 文件路径使用hash命名，避免文件名冲突
5. 数据库操作失败不会影响文件上传功能 