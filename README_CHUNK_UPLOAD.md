# V-Hono 大文件分片上传系统

## 概述

V-Hono 大文件分片上传系统是一个基于 V 语言和 Hono 框架构建的高性能文件上传解决方案。支持大文件分片上传、断点续传、秒传、自动合并等功能。

## 主要特性

- ✅ **分片上传**：支持大文件分片上传，默认分片大小 2MB
- ✅ **断点续传**：支持上传中断后继续上传
- ✅ **秒传功能**：基于文件哈希的秒传检测
- ✅ **自动合并**：所有分片上传完成后自动合并文件
- ✅ **文件去重**：基于文件哈希的去重机制
- ✅ **数据库存储**：使用 SQLite 存储文件元数据
- ✅ **RESTful API**：完整的 REST API 接口
- ✅ **Web 界面**：提供友好的 Web 上传界面

## 系统架构

```
前端 (Web/移动端)
    ↓
V-Hono 服务器
    ↓
分片存储 (./uploads/chunks/)
    ↓
文件合并 (./uploads/files/)
    ↓
数据库 (SQLite)
```

## 安装和运行

### 1. 环境要求

- V 语言 0.4.x 或更高版本
- Windows/Linux/macOS

### 2. 启动服务器

```bash
# 克隆项目
git clone <repository-url>
cd v-hono

# 启动分片上传服务器
v run chunk_upload_example.v
```

服务器将在 `http://localhost:8080` 启动。

### 3. 访问 Web 界面

打开浏览器访问 `http://localhost:8080` 即可使用 Web 上传界面。

## API 接口文档

### 1. 分片上传接口

**接口地址：** `POST /upload/chunk`

**请求参数：**
- `file_hash` (string): 文件哈希值
- `chunk_index` (int): 分片索引，从 0 开始
- `filename` (string): 原始文件名
- `file_size` (int): 文件总大小（字节）
- `chunk_size` (int): 分片大小（字节）
- `chunk_hash` (string): 分片哈希值
- `chunk` (file): 分片文件数据

**响应格式：**

上传完成（自动合并）：
```json
{
    "success": true,
    "all_chunk_uploaded": true,
    "file_path": ".\\uploads\\files\\xxx.zip",
    "file_uuid": "xxx-xxx-xxx",
    "message": "File merged successfully"
}
```

上传中：
```json
{
    "success": true,
    "chunk_index": 1,
    "all_chunk_uploaded": false,
    "message": "Chunk uploaded successfully"
}
```

### 2. 分片存在检查接口

**接口地址：** `GET /upload/chunk_exists`

**请求参数：**
- `file_hash` (string): 文件哈希值
- `chunk_index` (int): 分片索引
- `chunk_hash` (string): 分片哈希值
- `file_size` (int): 文件总大小
- `trunk_size` (int): 分片大小

**响应格式：**
```json
{
    "exists": true,
    "all_chunk_uploaded": false
}
```

### 3. 上传状态查询接口

**接口地址：** `GET /upload/status`

**请求参数：**
- `file_hash` (string): 文件哈希值

**响应格式：**
```json
{
    "file_hash": "xxx",
    "filename": "example.zip",
    "total_chunks": 0,
    "file_size": 1048576,
    "chunk_size": 2097152,
    "uploaded_chunks": [0, 1, 2],
    "status": "uploading",
    "created_at": 1640995200,
    "updated_at": 1640995300
}
```

### 4. 已上传分片查询接口

**接口地址：** `GET /upload/chunks`

**请求参数：**
- `file_hash` (string): 文件哈希值

**响应格式：**
```json
{
    "uploaded_chunks": [0, 1, 2],
    "total_chunks": 5,
    "completed": false
}
```

### 5. 文件管理接口

#### 获取所有文件
**接口地址：** `GET /api/files`

#### 根据 UUID 获取文件
**接口地址：** `GET /api/files/{uuid}`

#### 根据哈希获取文件
**接口地址：** `GET /api/files/hash/{hash}`

#### 删除文件
**接口地址：** `DELETE /api/files/{uuid}`

## 配置说明

### ChunkUploadConfig 配置项

```v
pub struct ChunkUploadConfig {
    chunk_size: int = 1024 * 1024  // 默认分片大小 1MB
    max_file_size: int = 1024 * 1024 * 1024  // 最大文件大小 1GB
    temp_dir: string = './uploads/chunks'  // 临时分片目录
    upload_dir: string = './uploads/files'  // 最终文件目录
    cleanup_delay: int = 3600  // 清理延迟时间（秒）
    clear_chunks_on_complete: bool = false  // 完成后是否清理分片
    db_path: string = './uploads/files.db'  // 数据库文件路径
}
```

## 文件存储结构

```
uploads/
├── chunks/                    # 分片文件目录
│   └── {file_hash}/          # 按文件哈希分组
│       └── {chunk_size}/     # 按分片大小分组
│           ├── chunk_0.part  # 分片文件
│           ├── chunk_1.part
│           └── ...
├── files/                    # 最终文件目录
│   ├── {file_hash}.{ext}    # 合并后的文件
│   └── ...
└── files.db                 # SQLite 数据库文件
```

## 使用示例

### 1. 前端 JavaScript 示例

```javascript
// 计算文件哈希
async function calculateFileHash(file) {
    return new Promise(resolve => {
        const spark = new SparkMD5.ArrayBuffer();
        const reader = new FileReader();
        reader.onload = e => {
            spark.append(e.target.result);
            resolve(spark.end());
        };
        reader.readAsArrayBuffer(file);
    });
}

// 上传分片
async function uploadChunk(file, chunk, { fileHash, chunkIndex, chunkHash }) {
    const form = new FormData();
    form.append('file_hash', fileHash);
    form.append('chunk_index', chunkIndex);
    form.append('filename', file.name);
    form.append('file_size', file.size);
    form.append('chunk_size', CHUNK_SIZE);
    form.append('chunk_hash', chunkHash);
    form.append('chunk', chunk);

    const response = await fetch('/upload/chunk', { 
        method: 'POST', 
        body: form 
    });
    
    const result = await response.json();
    
    if (result.all_chunk_uploaded) {
        console.log('上传完成，文件已合并:', result.file_path);
        return true; // 上传完成
    }
    
    return false; // 继续上传
}

// 分片上传主函数
async function uploadFile(file) {
    const fileHash = await calculateFileHash(file);
    const chunkSize = 2 * 1024 * 1024; // 2MB
    const totalChunks = Math.ceil(file.size / chunkSize);
    
    for (let i = 0; i < totalChunks; i++) {
        const chunk = file.slice(i * chunkSize, (i + 1) * chunkSize);
        const chunkHash = await calculateFileHash(chunk);
        
        const completed = await uploadChunk(file, chunk, {
            fileHash,
            chunkIndex: i,
            chunkHash
        });
        
        if (completed) {
            break; // 上传完成
        }
    }
}
```

### 2. cURL 示例

```bash
# 上传分片
curl -X POST http://localhost:8080/upload/chunk \
  -F "file_hash=abc123" \
  -F "chunk_index=0" \
  -F "filename=large_file.zip" \
  -F "file_size=10485760" \
  -F "chunk_size=2097152" \
  -F "chunk_hash=def456" \
  -F "chunk=@chunk_0.part"

# 检查分片是否存在
curl "http://localhost:8080/upload/chunk_exists?file_hash=abc123&chunk_index=0&chunk_hash=def456&file_size=10485760&trunk_size=2097152"
```

## 核心算法

### 1. 分片合并判断

系统使用以下逻辑判断是否所有分片都已上传：

```v
// 计算理论上需要的分片数量
expected_chunks := (expected_file_size + u64(chunk_size) - 1) / u64(chunk_size)

// 只有当分片数量达到预期且总大小 >= 文件大小时，才认为上传完成
if chunk_count >= int(expected_chunks) && total_chunk_size >= expected_file_size {
    all_chunk_uploaded = true
}
```

### 2. 文件去重机制

- 基于文件哈希进行去重
- 相同哈希的文件只存储一份
- 支持同一文件的不同文件名

### 3. 秒传检测

- 前端计算文件哈希
- 后端检查文件是否已存在
- 如果存在则直接返回文件信息，无需上传

## 性能优化

### 1. 内存管理

- 分片文件存储在磁盘，不占用大量内存
- 上传状态使用内存缓存，提高查询速度
- 支持配置清理策略，自动清理临时文件

### 2. 并发处理

- 支持多用户同时上传
- 分片级别的并发控制
- 文件级别的锁机制

### 3. 错误处理

- 网络异常自动重试
- 分片损坏自动重新上传
- 完整的错误日志记录

## 监控和日志

### 1. 调试日志

系统提供详细的调试日志，包括：
- 分片上传状态
- 文件合并过程
- 错误信息追踪

### 2. 性能监控

- 上传速度统计
- 分片成功率
- 系统资源使用情况

## 故障排除

### 1. 常见问题

**Q: 上传大文件时出现内存不足**
A: 检查分片大小配置，建议设置为 1-5MB

**Q: 分片上传后文件合并失败**
A: 检查磁盘空间和文件权限

**Q: 秒传功能不工作**
A: 确认前端哈希算法与后端一致

### 2. 日志分析

查看服务器日志获取详细错误信息：
```bash
# 启动时查看详细日志
v run chunk_upload_example.v
```

## 扩展功能

### 1. 云存储集成

可以扩展支持：
- AWS S3
- 阿里云 OSS
- 腾讯云 COS

### 2. 文件处理

可以添加：
- 图片压缩
- 视频转码
- 文档预览

### 3. 权限控制

可以集成：
- 用户认证
- 文件权限
- 访问控制

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 许可证

本项目采用 MIT 许可证。 