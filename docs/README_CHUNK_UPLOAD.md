# V-Hono 大文件分片上传系统

## 概述

V-Hono 大文件分片上传系统是一个基于 V 语言和 Hono 框架构建的高性能文件上传解决方案。支持大文件分片上传、断点续传、秒传、自动合并等功能。

## 主要特性

- ✅ **分片上传**：支持大文件分片上传，可配置分片大小
- ✅ **断点续传**：支持上传中断后继续上传
- ✅ **秒传功能**：基于文件哈希的秒传检测
- ✅ **自动合并**：所有分片上传完成后自动合并文件
- ✅ **文件去重**：基于文件哈希的去重机制
- ✅ **数据库存储**：使用 SQLite 存储文件元数据
- ✅ **RESTful API**：完整的 REST API 接口
- ✅ **Web 界面**：提供友好的 Web 上传界面
- ✅ **可配置参数**：支持自定义分片大小、文件大小限制等
- ✅ **双请求池系统**：活跃请求池 + 待请求池，智能并发控制
- ✅ **实时状态监控**：实时显示上传进度和请求池状态

## 系统架构

```
前端 (Web/移动端)
    ↓
双请求池系统 (活跃池 + 待请求池)
    ↓
V-Hono 服务器
    ↓
分片存储 (./uploads/chunks/)
    ↓
文件合并 (./uploads/files/)
    ↓
数据库 (SQLite)
```

### 双请求池系统架构

```
请求池管理器
├── 活跃请求池 (Map<requestId, Promise>)
│   ├── 请求1 (正在执行)
│   ├── 请求2 (正在执行)
│   └── ... (最多6个并发)
└── 待请求池 (Array<Request>)
    ├── 请求7 (等待执行)
    ├── 请求8 (等待执行)
    └── ... (无限制)
```

**工作原理：**
1. 新请求到达时，检查活跃池是否已满
2. 如果未满，直接加入活跃池并执行
3. 如果已满，加入待请求池等待
4. 活跃池中的请求完成后，自动从待请求池取出下一个请求执行
5. 实时更新状态显示，提供完整的监控信息

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
    max_chunk_size: int = 10 * 1024 * 1024  // 最大分片大小 10MB
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
│           ├── ...
│           └── total_size.record  # 分片大小记录文件（优化性能）
├── files/                    # 最终文件目录
│   ├── {file_hash}.{ext}    # 合并后的文件
│   └── ...
└── files.db                 # SQLite 数据库文件
```

## 配置示例

### 1. 使用默认配置

```v
// 使用默认配置创建分片上传管理器
mut upload_manager := hono.new_chunk_upload_manager(hono.ChunkUploadConfig{})
```

### 2. 使用自定义配置

```v
// 创建自定义配置
custom_config := hono.ChunkUploadConfig{
    chunk_size: 5 * 1024 * 1024  // 5MB 默认分片大小
    max_file_size: 5 * 1024 * 1024 * 1024  // 5GB 最大文件大小
    max_chunk_size: 20 * 1024 * 1024  // 20MB 最大分片大小
    temp_dir: './uploads/chunks'
    upload_dir: './uploads/files'
    cleanup_delay: 7200  // 2小时后清理临时文件
    clear_chunks_on_complete: true  // 上传完成后清理分片
    db_path: './uploads/files.db'
}

// 使用自定义配置创建分片上传管理器
mut upload_manager := hono.new_chunk_upload_manager(custom_config)
```

### 3. 获取配置信息

前端可以通过 `/api/upload-config` 接口获取后端配置：

```javascript
// 获取后端配置信息
async function getUploadConfig() {
    const response = await fetch('/api/upload-config');
    const config = await response.json();
    console.log('最大分片大小:', config.max_chunk_size);
    return config;
}
```

## 双请求池系统详解

### 概述

双请求池系统是 V-Hono 分片上传系统的核心性能优化组件，通过智能的并发控制机制，确保大文件上传的高效性和稳定性。

### 核心组件

#### 1. 活跃请求池 (Active Pool)
- **数据结构**：`Map<requestId, Promise>`
- **功能**：存储正在执行的请求
- **容量**：可配置，默认最大6个并发
- **特点**：实时执行，状态可追踪

#### 2. 待请求池 (Pending Pool)
- **数据结构**：`Array<Request>`
- **功能**：存储等待执行的请求
- **容量**：无限制，按需扩展
- **特点**：FIFO队列，自动调度

#### 3. 请求管理器
- **请求ID生成**：自动递增的唯一标识
- **智能调度**：根据活跃池状态自动分配
- **状态监控**：实时提供池状态信息
- **错误处理**：请求级别的错误隔离

### 配置参数

```javascript
// 创建请求池实例
const requestPool = new RequestPool(6); // 最大并发6个

// 可配置参数
const config = {
    maxConcurrent: 6,        // 最大并发数
    enableLogging: true,     // 启用日志
    autoRetry: true,         // 自动重试
    retryCount: 3           // 重试次数
};
```

### 状态监控

```javascript
// 获取实时状态
const status = requestPool.getStatus();
console.log({
    activeCount: status.activeCount,      // 活跃请求数
    pendingCount: status.pendingCount,    // 等待请求数
    maxConcurrent: status.maxConcurrent,  // 最大并发数
    utilization: (status.activeCount / status.maxConcurrent * 100).toFixed(1) + '%' // 利用率
});
```

### 性能优势

1. **并发控制**：避免服务器过载，保护系统稳定性
2. **资源优化**：合理利用网络带宽和服务器资源
3. **用户体验**：提供实时进度反馈和状态显示
4. **错误隔离**：单个请求失败不影响其他请求
5. **自动恢复**：支持断点续传和失败重试

## 使用示例

### 1. 前端 JavaScript 示例

```javascript
// 请求池管理类
class RequestPool {
    constructor(maxConcurrent = 6) {
        this.maxConcurrent = maxConcurrent;
        this.activePool = new Map(); // 活跃请求池 {requestId: Promise}
        this.pendingPool = []; // 待请求池 [{requestId, task, resolve, reject}]
        this.requestIdCounter = 0;
    }

    // 生成请求ID
    generateRequestId() {
        return ++this.requestIdCounter;
    }

    // 添加请求到池中
    async addRequest(task) {
        const requestId = this.generateRequestId();
        
        return new Promise((resolve, reject) => {
            const request = {
                requestId,
                task,
                resolve,
                reject
            };

            // 如果活跃池未满，直接执行
            if (this.activePool.size < this.maxConcurrent) {
                this.executeRequest(request);
            } else {
                // 否则加入待请求池
                this.pendingPool.push(request);
                console.log(`请求 ${requestId} 加入待请求池，当前待请求数: ${this.pendingPool.length}`);
            }
        });
    }

    // 执行请求
    async executeRequest(request) {
        const { requestId, task, resolve, reject } = request;
        
        console.log(`开始执行请求 ${requestId}，当前活跃请求数: ${this.activePool.size + 1}`);
        
        // 将请求添加到活跃池
        const promise = task()
            .then(result => {
                console.log(`请求 ${requestId} 执行成功`);
                resolve(result);
                return result;
            })
            .catch(error => {
                console.log(`请求 ${requestId} 执行失败:`, error);
                reject(error);
                throw error;
            })
            .finally(() => {
                // 请求完成后从活跃池移除
                this.activePool.delete(requestId);
                console.log(`请求 ${requestId} 完成，从活跃池移除，当前活跃请求数: ${this.activePool.size}`);
                
                // 检查待请求池，如果有待请求则执行
                this.processPendingRequests();
            });

        this.activePool.set(requestId, promise);
    }

    // 处理待请求池中的请求
    processPendingRequests() {
        while (this.pendingPool.length > 0 && this.activePool.size < this.maxConcurrent) {
            const request = this.pendingPool.shift();
            this.executeRequest(request);
            console.log(`从待请求池取出请求 ${request.requestId} 执行，剩余待请求数: ${this.pendingPool.length}`);
        }
    }

    // 获取池状态
    getStatus() {
        return {
            activeCount: this.activePool.size,
            pendingCount: this.pendingPool.length,
            maxConcurrent: this.maxConcurrent
        };
    }

    // 清空所有池
    clear() {
        this.activePool.clear();
        this.pendingPool = [];
        console.log('请求池已清空');
    }
}

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

// 使用请求池的分片上传主函数
async function uploadFileWithPool(file) {
    const fileHash = await calculateFileHash(file);
    const chunkSize = 2 * 1024 * 1024; // 2MB
    const totalChunks = Math.ceil(file.size / chunkSize);
    
    // 创建请求池实例
    const requestPool = new RequestPool(6);
    
    // 创建所有分片的上传任务并添加到请求池
    const uploadPromises = [];
    for (let i = 0; i < totalChunks; i++) {
        const chunkIndex = i;
        const promise = requestPool.addRequest(async () => {
            const chunk = file.slice(chunkIndex * chunkSize, (chunkIndex + 1) * chunkSize);
            const chunkHash = await calculateFileHash(chunk);
            
            return await uploadChunk(file, chunk, {
                fileHash,
                chunkIndex,
                chunkHash
            });
        });
        
        uploadPromises.push(promise);
    }

    // 等待所有上传任务完成
    const results = await Promise.all(uploadPromises);
    
    // 清空请求池
    requestPool.clear();
    
    return results;
}

// 实时监控请求池状态
function monitorRequestPool(requestPool) {
    setInterval(() => {
        const status = requestPool.getStatus();
        console.log(`请求池状态: ${status.activeCount}/${status.maxConcurrent} 活跃, ${status.pendingCount} 等待中`);
        
        // 更新UI显示
        updatePoolStatusDisplay(status);
    }, 1000);
}

// 更新UI显示
function updatePoolStatusDisplay(status) {
    const statusElement = document.getElementById('poolStatus');
    if (statusElement) {
        if (status.activeCount === 0 && status.pendingCount === 0) {
            statusElement.textContent = '请求池状态: 所有请求已完成';
        } else {
            statusElement.textContent = `请求池状态: ${status.activeCount}/${status.maxConcurrent} 活跃, ${status.pendingCount} 等待中`;
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

## 请求池最佳实践

### 1. 并发数配置建议

```javascript
// 根据网络环境调整并发数
const networkConfig = {
    'fast': 8,      // 高速网络：8个并发
    'normal': 6,    // 普通网络：6个并发
    'slow': 4,      // 慢速网络：4个并发
    'mobile': 3     // 移动网络：3个并发
};

// 根据文件大小调整并发数
const fileSizeConfig = {
    'small': 8,     // 小文件(<10MB)：8个并发
    'medium': 6,    // 中等文件(10MB-100MB)：6个并发
    'large': 4,     // 大文件(>100MB)：4个并发
};
```

### 2. 错误处理和重试机制

```javascript
class RobustRequestPool extends RequestPool {
    constructor(maxConcurrent = 6, maxRetries = 3) {
        super(maxConcurrent);
        this.maxRetries = maxRetries;
    }

    async addRequestWithRetry(task) {
        return this.addRequest(async () => {
            let lastError;
            for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
                try {
                    return await task();
                } catch (error) {
                    lastError = error;
                    console.log(`请求失败，第${attempt}次重试:`, error.message);
                    
                    if (attempt < this.maxRetries) {
                        // 指数退避
                        await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
                    }
                }
            }
            throw lastError;
        });
    }
}
```

### 3. 性能监控和优化

```javascript
class MonitoredRequestPool extends RequestPool {
    constructor(maxConcurrent = 6) {
        super(maxConcurrent);
        this.metrics = {
            totalRequests: 0,
            successfulRequests: 0,
            failedRequests: 0,
            averageResponseTime: 0,
            startTime: Date.now()
        };
    }

    async executeRequest(request) {
        const startTime = Date.now();
        this.metrics.totalRequests++;
        
        try {
            const result = await super.executeRequest(request);
            this.metrics.successfulRequests++;
            this.updateMetrics(Date.now() - startTime);
            return result;
        } catch (error) {
            this.metrics.failedRequests++;
            throw error;
        }
    }

    updateMetrics(responseTime) {
        const { totalRequests, averageResponseTime } = this.metrics;
        this.metrics.averageResponseTime = 
            (averageResponseTime * (totalRequests - 1) + responseTime) / totalRequests;
    }

    getMetrics() {
        const uptime = Date.now() - this.metrics.startTime;
        return {
            ...this.metrics,
            uptime,
            successRate: (this.metrics.successfulRequests / this.metrics.totalRequests * 100).toFixed(2) + '%',
            requestsPerSecond: (this.metrics.totalRequests / (uptime / 1000)).toFixed(2)
        };
    }
}
```

### 4. 内存管理和清理

```javascript
class ManagedRequestPool extends RequestPool {
    constructor(maxConcurrent = 6, maxMemoryMB = 100) {
        super(maxConcurrent);
        this.maxMemory = maxMemoryMB * 1024 * 1024; // 转换为字节
        this.memoryUsage = 0;
    }

    async addRequest(task) {
        // 检查内存使用情况
        if (this.memoryUsage > this.maxMemory) {
            console.warn('内存使用过高，等待清理...');
            await this.waitForMemory();
        }

        return super.addRequest(task);
    }

    async waitForMemory() {
        return new Promise(resolve => {
            const checkMemory = () => {
                if (this.memoryUsage < this.maxMemory * 0.8) {
                    resolve();
                } else {
                    setTimeout(checkMemory, 1000);
                }
            };
            checkMemory();
        });
    }

    // 定期清理
    startCleanup() {
        setInterval(() => {
            this.cleanup();
        }, 30000); // 每30秒清理一次
    }

    cleanup() {
        // 清理过期的请求记录
        const now = Date.now();
        // 实现清理逻辑...
    }
}
```

## 核心算法

### 1. 分片合并判断（优化版）

系统使用分片大小记录文件来避免遍历分片文件计算总大小，提高性能：

```v
// 更新分片大小记录
fn (mut manager ChunkUploadManager) update_chunk_size_record(file_hash string, chunk_size int, current_chunk_size int) {
    chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
    size_record_path := os.join_path(chunk_dir, 'total_size.record')
    
    // 读取现有的总大小记录
    mut total_size := u64(0)
    if os.exists(size_record_path) {
        size_data := os.read_file(size_record_path) or { '0' }
        total_size = size_data.u64() or { u64(0) }
    }
    
    // 更新总大小
    total_size += u64(current_chunk_size)
    
    // 写入更新后的总大小
    os.write_file(size_record_path, total_size.str()) or {
        println('[DEBUG] Failed to write size record: $err')
    }
}

// 获取分片大小记录
fn (manager ChunkUploadManager) get_chunk_size_record(file_hash string, chunk_size int) u64 {
    chunk_dir := os.join_path(manager.config.temp_dir, file_hash.trim_space(), chunk_size.str())
    size_record_path := os.join_path(chunk_dir, 'total_size.record')
    
    if os.exists(size_record_path) {
        size_data := os.read_file(size_record_path) or { '0' }
        return size_data.u64() or { u64(0) }
    }
    
    return u64(0)
}
```

**性能优化说明：**
- **传统方法**：每次需要遍历所有分片文件，计算总大小（O(n)复杂度）
- **优化方法**：维护一个记录文件，实时更新总大小（O(1)复杂度）
- **性能提升**：对于大文件（数百个分片），性能提升显著
- **存储结构**：`./uploads/chunks/{file_hash}/{chunk_size}/total_size.record`

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
- **分片大小记录文件**：避免遍历分片文件计算总大小，提高合并判断性能

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