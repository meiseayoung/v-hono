# veb vs v-hono 性能对比测试脚本
# 运行: .\run_benchmark.ps1

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         veb vs v-hono 性能对比测试                            ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 检查 V 编译器
if (-not (Get-Command v -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 未找到 V 编译器，请先安装 V 语言" -ForegroundColor Red
    exit 1
}

Write-Host "✅ V 编译器已安装" -ForegroundColor Green
Write-Host ""

# 菜单
Write-Host "请选择测试类型:" -ForegroundColor Yellow
Write-Host "  1. 路由匹配性能测试 (不需要启动服务器)"
Write-Host "  2. HTTP 压测 (需要先启动服务器)"
Write-Host "  3. 启动 veb 服务器 (端口 8080)"
Write-Host "  4. 启动 v-hono 服务器 (端口 8081)"
Write-Host "  5. 编译所有测试文件"
Write-Host "  6. 退出"
Write-Host ""

$choice = Read-Host "请输入选项 (1-6)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "运行路由匹配性能测试..." -ForegroundColor Cyan
        v run benchmark_veb_vs_hono.v
    }
    "2" {
        Write-Host ""
        Write-Host "运行 HTTP 压测..." -ForegroundColor Cyan
        Write-Host "请确保已在其他终端启动服务器:" -ForegroundColor Yellow
        Write-Host "  - veb:    v run server_veb.v   (端口 8080)"
        Write-Host "  - v-hono: v run server_hono.v  (端口 8081)"
        Write-Host ""
        v run http_benchmark.v
    }
    "3" {
        Write-Host ""
        Write-Host "启动 veb 服务器 (端口 8080)..." -ForegroundColor Cyan
        v run server_veb.v
    }
    "4" {
        Write-Host ""
        Write-Host "启动 v-hono 服务器 (端口 8081)..." -ForegroundColor Cyan
        v run server_hono.v
    }
    "5" {
        Write-Host ""
        Write-Host "编译所有测试文件..." -ForegroundColor Cyan
        
        Write-Host "编译 benchmark_veb_vs_hono.v..."
        v -prod benchmark_veb_vs_hono.v -o benchmark_veb_vs_hono.exe
        
        Write-Host "编译 server_veb.v..."
        v -prod server_veb.v -o server_veb.exe
        
        Write-Host "编译 server_hono.v..."
        v -prod server_hono.v -o server_hono.exe
        
        Write-Host "编译 http_benchmark.v..."
        v -prod http_benchmark.v -o http_benchmark.exe
        
        Write-Host ""
        Write-Host "✅ 编译完成!" -ForegroundColor Green
    }
    "6" {
        Write-Host "退出" -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "无效选项" -ForegroundColor Red
    }
}
