# V-Hono 双请求池系统

## 概述

双请求池系统是 V-Hono 框架中用于管理并发请求的核心组件，特别针对大文件分片上传场景进行了优化。该系统通过智能的并发控制机制，确保系统在高负载下的稳定性和性能。

## 系统架构

### 核心组件

```
双请求池系统
├── 活跃请求池 (Active Pool)
│   ├── 数据结构: Map<requestId, Promise>
│   ├── 容量: 可配置 (默认6个并发)
│   └── 功能: 存储正在执行的请求
└── 待请求池 (Pending Pool)
    ├── 数据结构: Array<Request>
    ├── 容量: 无限制
    └── 功能: 存储等待执行的请求
```

### 工作流程

1. **请求到达**：新请求到达时，系统生成唯一请求ID
2. **池状态检查**：检查活跃池是否已满
3. **智能分配**：
   - 如果活跃池未满：直接加入活跃池并执行
   - 如果活跃池已满：加入待请求池等待
4. **自动调度**：活跃池中的请求完成后，自动从待请求池取出下一个请求执行
5. **状态更新**：实时更新池状态，提供监控信息

## 核心特性

### 1. 智能并发控制
- **可配置并发数**：根据服务器性能和网络环境调整
- **自动负载均衡**：避免服务器过载
- **资源优化**：合理利用网络带宽和服务器资源

### 2. 请求生命周期管理
- **唯一标识**：每个请求都有唯一的requestId
- **状态追踪**：实时追踪请求的执行状态
- **自动清理**：请求完成后自动清理资源

### 3. 错误处理和隔离
- **错误隔离**：单个请求失败不影响其他请求
- **自动重试**：支持配置重试机制
- **错误传播**：错误信息准确传递给调用方

### 4. 实时监控
- **状态查询**：实时获取池状态信息
- **性能指标**：提供详细的性能监控数据
- **日志记录**：完整的操作日志记录

## 实现代码

### RequestPool 类

```javascript
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
```

## 使用示例

### 基本使用

```javascript
// 创建请求池实例
const requestPool = new RequestPool(6);

// 添加请求
const promise = requestPool.addRequest(async () => {
    // 执行具体的任务
    return await someAsyncTask();
});

// 获取状态
const status = requestPool.getStatus();
console.log(`活跃: ${status.activeCount}/${status.maxConcurrent}, 等待: ${status.pendingCount}`);
```

### 分片上传场景

```javascript
async function uploadFileWithPool(file) {
    const fileHash = await calculateFileHash(file);
    const chunkSize = 2 * 1024 * 1024; // 2MB
    const totalChunks = Math.ceil(file.size / chunkSize);
    
    // 创建请求池实例
    const requestPool = new RequestPool(6);
    
    // 创建所有分片的上传任务
    const uploadPromises = [];
    for (let i = 0; i < totalChunks; i++) {
        const chunkIndex = i;
        const promise = requestPool.addRequest(async () => {
            const chunk = file.slice(chunkIndex * chunkSize, (chunkIndex + 1) * chunkSize);
            const chunkHash = await calculateChunkHash(chunk);
            
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
```

### 实时监控

```javascript
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

## 配置建议

### 并发数配置

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

### 性能优化配置

```javascript
// 高性能配置
const highPerformanceConfig = {
    maxConcurrent: 8,
    enableLogging: false,
    autoRetry: true,
    retryCount: 3,
    retryDelay: 1000
};

// 稳定性配置
const stabilityConfig = {
    maxConcurrent: 4,
    enableLogging: true,
    autoRetry: true,
    retryCount: 5,
    retryDelay: 2000
};
```

## 扩展功能

### 1. 错误重试机制

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

### 2. 性能监控

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

### 3. 优先级队列

```javascript
class PriorityRequestPool extends RequestPool {
    constructor(maxConcurrent = 6) {
        super(maxConcurrent);
        this.priorityQueue = [];
    }

    addPriorityRequest(task, priority = 0) {
        const requestId = this.generateRequestId();
        
        return new Promise((resolve, reject) => {
            const request = {
                requestId,
                task,
                resolve,
                reject,
                priority
            };

            if (this.activePool.size < this.maxConcurrent) {
                this.executeRequest(request);
            } else {
                // 按优先级插入待请求池
                this.insertPriorityRequest(request);
            }
        });
    }

    insertPriorityRequest(request) {
        let insertIndex = this.pendingPool.length;
        for (let i = 0; i < this.pendingPool.length; i++) {
            if (request.priority > this.pendingPool[i].priority) {
                insertIndex = i;
                break;
            }
        }
        this.pendingPool.splice(insertIndex, 0, request);
    }
}
```

## 最佳实践

### 1. 合理设置并发数
- 根据服务器性能调整并发数
- 考虑网络带宽限制
- 监控系统资源使用情况

### 2. 错误处理
- 实现适当的重试机制
- 记录详细的错误日志
- 提供用户友好的错误信息

### 3. 性能监控
- 实时监控请求池状态
- 收集性能指标数据
- 根据监控数据优化配置

### 4. 资源管理
- 及时清理完成的请求
- 避免内存泄漏
- 定期检查资源使用情况

## 故障排除

### 常见问题

1. **请求堆积**
   - 检查并发数设置是否合理
   - 监控网络连接状态
   - 检查服务器性能

2. **内存泄漏**
   - 确保请求完成后正确清理
   - 检查是否有循环引用
   - 定期重启服务

3. **性能下降**
   - 调整并发数配置
   - 检查网络带宽
   - 优化请求处理逻辑

### 调试技巧

```javascript
// 启用详细日志
const debugPool = new RequestPool(6);
debugPool.enableDebugLogging = true;

// 监控关键指标
setInterval(() => {
    const status = debugPool.getStatus();
    const metrics = debugPool.getMetrics();
    console.log('状态:', status);
    console.log('指标:', metrics);
}, 5000);
```

## 总结

双请求池系统是 V-Hono 框架中重要的性能优化组件，通过智能的并发控制和资源管理，为大文件上传等场景提供了稳定、高效的解决方案。通过合理配置和最佳实践，可以充分发挥系统的性能优势。 