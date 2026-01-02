// picoev 优化集成测试 (Go 版本)
// 测试 picoev 服务器的完整功能，确保优化没有引入新问题
//
// 使用方法:
// 1. 先启动测试服务器: v -enable-globals run v-hono/tests/test_picoev_server.v
// 2. 运行测试: go run v-hono/tests/test_picoev_integration.go

package main

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

const baseURL = "http://127.0.0.1:9999"

type TestStats struct {
	total  int
	passed int
	failed int
	errors []string
}

func (s *TestStats) run(name string, testFn func() bool) {
	s.total++
	fmt.Printf("  🧪 %s... ", name)

	if testFn() {
		s.passed++
		fmt.Println("✅")
	} else {
		s.failed++
		s.errors = append(s.errors, name)
		fmt.Println("❌")
	}
}

func (s *TestStats) summary() {
	fmt.Println()
	fmt.Println("═══════════════════════════════════════════════════════════════")
	fmt.Printf("📊 测试结果: %d/%d 通过\n", s.passed, s.total)

	if s.failed > 0 {
		fmt.Println("❌ 失败的测试:")
		for _, err := range s.errors {
			fmt.Printf("   - %s\n", err)
		}
	} else {
		fmt.Println("🎉 所有测试通过！picoev 优化验证成功！")
	}
	fmt.Println("═══════════════════════════════════════════════════════════════")
}

func main() {
	fmt.Println("╔═══════════════════════════════════════════════════════════════╗")
	fmt.Println("║           picoev 优化集成测试 (Go)                            ║")
	fmt.Println("╚═══════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// 验证服务器是否运行
	fmt.Println("🔍 检查测试服务器...")
	if !checkServerReady() {
		fmt.Println("❌ 服务器未运行")
		fmt.Println("   请先启动: v -enable-globals run v-hono/tests/test_picoev_server.v")
		return
	}
	fmt.Println("✅ 服务器已就绪")
	fmt.Println()

	stats := &TestStats{}

	// 1. 基本 GET 路由测试
	fmt.Println("📦 1. 基本 GET 路由测试")
	stats.run("GET 根路径", testGetRoot)
	stats.run("GET 健康检查", testGetHealth)
	stats.run("GET 静态路由", testGetStatic)
	fmt.Println()

	// 2. 动态路由测试
	fmt.Println("📦 2. 动态路由测试")
	stats.run("单参数路由", testSingleParam)
	stats.run("多参数路由", testMultiParams)
	stats.run("嵌套参数路由", testNestedParams)
	fmt.Println()

	// 3. 查询参数测试
	fmt.Println("📦 3. 查询参数测试")
	stats.run("单个查询参数", testSingleQuery)
	stats.run("多个查询参数", testMultiQuery)
	fmt.Println()

	// 4. 响应格式测试
	fmt.Println("📦 4. 响应格式测试")
	stats.run("JSON 响应", testJSONResponse)
	stats.run("HTML 响应", testHTMLResponse)
	stats.run("自定义状态码 201", testCustomStatus)
	fmt.Println()

	// 5. 中间件测试
	fmt.Println("📦 5. 中间件测试")
	stats.run("全局中间件响应头", testMiddlewareHeader)
	fmt.Println()

	// 6. 404 处理测试
	fmt.Println("📦 6. 错误处理测试")
	stats.run("404 未找到", testNotFound)
	fmt.Println()

	// 7. Keep-Alive 测试
	fmt.Println("📦 7. Keep-Alive 连接测试")
	stats.run("连接复用", testKeepAlive)
	fmt.Println()

	// 8. 性能测试
	fmt.Println("📦 8. 性能测试")
	stats.run("响应时间 < 50ms", testResponseTime)
	stats.run("吞吐量测试", testThroughput)
	fmt.Println()

	// 9. 高并发基准测试
	fmt.Println("📦 9. Keep-Alive 基准测试")
	testBenchmark()
	fmt.Println()

	// 输出总结
	stats.summary()
}

// 检查服务器是否就绪
func checkServerReady() bool {
	client := &http.Client{Timeout: 2 * time.Second}
	for i := 0; i < 5; i++ {
		resp, err := client.Get(baseURL + "/health")
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			return true
		}
		time.Sleep(200 * time.Millisecond)
	}
	return false
}

// ==================== 基本 GET 路由测试 ====================

func testGetRoot() bool {
	resp, body := doGet("/")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "Hello")
}

func testGetHealth() bool {
	resp, body := doGet("/health")
	return resp != nil && resp.StatusCode == 200 && body == "OK"
}

func testGetStatic() bool {
	resp, body := doGet("/api/health")
	return resp != nil && resp.StatusCode == 200 && body == "OK"
}

// ==================== 动态路由测试 ====================

func testSingleParam() bool {
	resp, body := doGet("/api/users/456")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "456")
}

func testMultiParams() bool {
	resp, body := doGet("/api/users/123/posts/789")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "123") && strings.Contains(body, "789")
}

func testNestedParams() bool {
	resp, body := doGet("/api/categories/tech/items/laptop")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "tech") && strings.Contains(body, "laptop")
}

// ==================== 查询参数测试 ====================

func testSingleQuery() bool {
	resp, body := doGet("/api/search?q=test")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "test")
}

func testMultiQuery() bool {
	resp, body := doGet("/api/search?q=hello&limit=10&page=1")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "hello")
}

// ==================== 响应格式测试 ====================

func testJSONResponse() bool {
	resp, _ := doGet("/api/json")
	if resp == nil {
		return false
	}
	contentType := resp.Header.Get("Content-Type")
	return resp.StatusCode == 200 && strings.Contains(contentType, "application/json")
}

func testHTMLResponse() bool {
	resp, _ := doGet("/api/html")
	if resp == nil {
		return false
	}
	contentType := resp.Header.Get("Content-Type")
	return resp.StatusCode == 200 && strings.Contains(contentType, "text/html")
}

func testCustomStatus() bool {
	resp, _ := doGet("/api/created")
	return resp != nil && resp.StatusCode == 201
}

// ==================== 中间件测试 ====================

func testMiddlewareHeader() bool {
	resp, body := doGet("/api/health")
	// 检查中间件添加的响应头
	if resp == nil {
		return false
	}
	middlewareHeader := resp.Header.Get("X-Middleware")
	return resp.StatusCode == 200 && body == "OK" && middlewareHeader == "applied"
}

// ==================== 错误处理测试 ====================

func testNotFound() bool {
	resp, _ := doGet("/nonexistent/path/here")
	return resp != nil && resp.StatusCode == 404
}

// ==================== Keep-Alive 测试 ====================

func testKeepAlive() bool {
	// 使用同一个 transport 发送多个请求
	transport := &http.Transport{
		MaxIdleConns:        10,
		IdleConnTimeout:     30 * time.Second,
		DisableKeepAlives:   false,
	}
	client := &http.Client{Transport: transport, Timeout: 5 * time.Second}

	for i := 0; i < 5; i++ {
		resp, err := client.Get(baseURL + "/api/health")
		if err != nil || resp.StatusCode != 200 {
			return false
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}
	return true
}

// ==================== 性能测试 ====================

func testResponseTime() bool {
	client := &http.Client{Timeout: 5 * time.Second}
	start := time.Now()

	for i := 0; i < 10; i++ {
		resp, err := client.Get(baseURL + "/api/health")
		if err != nil {
			return false
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}

	elapsed := time.Since(start)
	avgMs := float64(elapsed.Milliseconds()) / 10.0

	// 平均响应时间应小于 50ms
	return avgMs < 50.0
}

func testThroughput() bool {
	client := &http.Client{Timeout: 5 * time.Second}
	requests := 50
	success := 0

	start := time.Now()
	for i := 0; i < requests; i++ {
		resp, err := client.Get(baseURL + "/api/health")
		if err == nil && resp.StatusCode == 200 {
			success++
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
		}
	}
	elapsed := time.Since(start)

	rps := float64(success) * 1000.0 / float64(elapsed.Milliseconds())
	fmt.Printf("(%.0f req/s) ", rps)

	// 吞吐量应大于 20 req/s，成功率 > 90%
	return rps > 20.0 && success >= requests*9/10
}

// Keep-Alive 基准测试
func testBenchmark() {
	requests := 5000

	conn, err := net.Dial("tcp", "127.0.0.1:9999")
	if err != nil {
		fmt.Println("  ❌ 连接失败:", err)
		return
	}
	defer conn.Close()

	// 预热
	for i := 0; i < 100; i++ {
		fmt.Fprintf(conn, "GET /health HTTP/1.1\r\nHost: 127.0.0.1:9999\r\nConnection: keep-alive\r\n\r\n")
		buf := make([]byte, 256)
		conn.Read(buf)
	}

	// 正式测试
	start := time.Now()
	success := 0

	for i := 0; i < requests; i++ {
		_, err := fmt.Fprintf(conn, "GET /health HTTP/1.1\r\nHost: 127.0.0.1:9999\r\nConnection: keep-alive\r\n\r\n")
		if err != nil {
			continue
		}
		buf := make([]byte, 256)
		_, err = conn.Read(buf)
		if err != nil {
			continue
		}
		success++
	}

	elapsed := time.Since(start)
	elapsedMs := float64(elapsed.Milliseconds())
	rps := float64(success) * 1000.0 / elapsedMs
	avgUs := elapsedMs * 1000.0 / float64(success)

	fmt.Printf("  成功请求: %d/%d\n", success, requests)
	fmt.Printf("  吞吐量: %.0f req/s\n", rps)
	fmt.Printf("  平均延迟: %.2fμs\n", avgUs)
}

// 辅助函数
func doGet(path string) (*http.Response, string) {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(baseURL + path)
	if err != nil {
		return nil, ""
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	return resp, string(body)
}
