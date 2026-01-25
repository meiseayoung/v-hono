// uSockets 集成测试 (Go 版本)
//
// 使用方法:
// 1. 先启动测试服务器: v run v-hono/tests/test_usockets_server.v
// 2. 运行测试: go run v-hono/tests/test_usockets_integration.go

package main

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

const baseURL = "http://127.0.0.1:9998"

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
		fmt.Println("🎉 所有测试通过！uSockets 后端验证成功！")
	}
	fmt.Println("═══════════════════════════════════════════════════════════════")
}

func main() {
	fmt.Println("╔═══════════════════════════════════════════════════════════════╗")
	fmt.Println("║           uSockets 集成测试 (Go)                              ║")
	fmt.Println("╚═══════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// 验证服务器是否运行
	fmt.Println("🔍 检查 uSockets 测试服务器...")
	if !checkServerReady() {
		fmt.Println("❌ 服务器未运行")
		fmt.Println("   请先启动: v run v-hono/tests/test_usockets_server.v")
		return
	}
	fmt.Println("✅ 服务器已就绪")
	fmt.Println()

	stats := &TestStats{}

	// 1. 基本路由测试
	fmt.Println("📦 1. 基本路由测试")
	stats.run("GET /", testGetRoot)
	stats.run("GET /health", testGetHealth)
	fmt.Println()

	// 2. JSON 响应测试
	fmt.Println("📦 2. JSON 响应测试")
	stats.run("GET /api/json", testJSONResponse)
	fmt.Println()

	// 3. 动态路由测试
	fmt.Println("📦 3. 动态路由测试")
	stats.run("GET /api/users/:id", testSingleParam)
	stats.run("GET /api/users/:user_id/posts/:post_id", testMultiParams)
	fmt.Println()

	// 4. 查询参数测试
	fmt.Println("📦 4. 查询参数测试")
	stats.run("GET /api/search?q=hello", testQueryParam)
	fmt.Println()

	// 5. 404 测试
	fmt.Println("📦 5. 404 测试")
	stats.run("404 Not Found", testNotFound)
	fmt.Println()

	// 6. Keep-Alive 测试
	fmt.Println("📦 6. Keep-Alive 连接测试")
	stats.run("Keep-Alive 连接复用", testKeepAlive)
	fmt.Println()

	// 7. 性能测试
	fmt.Println("📦 7. 性能测试")
	stats.run("吞吐量测试", testThroughput)
	fmt.Println()

	// 8. 高并发基准测试
	fmt.Println("📦 8. Keep-Alive 基准测试")
	testBenchmark()
	fmt.Println()

	// 输出总结
	stats.summary()
}

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

func testGetRoot() bool {
	resp, body := doGet("/")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "Hello from uSockets")
}

func testGetHealth() bool {
	resp, body := doGet("/health")
	return resp != nil && resp.StatusCode == 200 && body == "OK"
}

func testJSONResponse() bool {
	resp, body := doGet("/api/json")
	if resp == nil {
		return false
	}
	contentType := resp.Header.Get("Content-Type")
	return resp.StatusCode == 200 && strings.Contains(contentType, "application/json") && strings.Contains(body, "Hello JSON")
}

func testSingleParam() bool {
	resp, body := doGet("/api/users/123")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "123")
}

func testMultiParams() bool {
	resp, body := doGet("/api/users/100/posts/200")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "100") && strings.Contains(body, "200")
}

func testQueryParam() bool {
	resp, body := doGet("/api/search?q=hello")
	return resp != nil && resp.StatusCode == 200 && strings.Contains(body, "hello")
}

func testNotFound() bool {
	resp, _ := doGet("/nonexistent")
	return resp != nil && resp.StatusCode == 404
}

func testKeepAlive() bool {
	transport := &http.Transport{
		MaxIdleConns:      10,
		IdleConnTimeout:   30 * time.Second,
		DisableKeepAlives: false,
	}
	client := &http.Client{Transport: transport, Timeout: 5 * time.Second}

	for i := 0; i < 5; i++ {
		resp, err := client.Get(baseURL + "/health")
		if err != nil || resp.StatusCode != 200 {
			return false
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}
	return true
}

func testThroughput() bool {
	client := &http.Client{Timeout: 5 * time.Second}
	requests := 100
	success := 0

	start := time.Now()
	for i := 0; i < requests; i++ {
		resp, err := client.Get(baseURL + "/health")
		if err == nil && resp.StatusCode == 200 {
			success++
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
		}
	}
	elapsed := time.Since(start)

	rps := float64(success) * 1000.0 / float64(elapsed.Milliseconds())
	fmt.Printf("(%.0f req/s) ", rps)

	return success >= requests*9/10
}

func testBenchmark() {
	requests := 5000

	conn, err := net.Dial("tcp", "127.0.0.1:9998")
	if err != nil {
		fmt.Println("  ❌ 连接失败:", err)
		return
	}
	defer conn.Close()

	// 预热
	for i := 0; i < 100; i++ {
		fmt.Fprintf(conn, "GET /health HTTP/1.1\r\nHost: 127.0.0.1:9998\r\nConnection: keep-alive\r\n\r\n")
		buf := make([]byte, 256)
		conn.Read(buf)
	}

	// 正式测试
	start := time.Now()
	success := 0

	for i := 0; i < requests; i++ {
		_, err := fmt.Fprintf(conn, "GET /health HTTP/1.1\r\nHost: 127.0.0.1:9998\r\nConnection: keep-alive\r\n\r\n")
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
