// uSockets 功能验证测试
// go run benchmark/usockets_verify.go

package main

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const baseURL = "http://127.0.0.1:9998"

func main() {
	fmt.Println("╔═══════════════════════════════════════════════════════════════╗")
	fmt.Println("║           uSockets 集成测试                                   ║")
	fmt.Println("╚═══════════════════════════════════════════════════════════════╝")
	fmt.Println()

	client := &http.Client{Timeout: 5 * time.Second}

	// 检查服务器
	fmt.Print("🔍 检查测试服务器... ")
	if !checkServer(client) {
		fmt.Println("❌ 服务器未运行")
		return
	}
	fmt.Println("✅")
	fmt.Println()

	total, passed, failed := 0, 0, 0
	var errors []string

	// 1. 基本 GET 路由测试
	fmt.Println("📦 1. 基本 GET 路由测试")

	total++
	fmt.Print("  🧪 GET 根路径... ")
	if checkGetRoot(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "GET 根路径")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 GET 健康检查... ")
	if checkGetHealth(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "GET 健康检查")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 GET 静态路由... ")
	if checkGetStatic(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "GET 静态路由")
		fmt.Println("❌")
	}
	fmt.Println()

	// 2. 动态路由测试
	fmt.Println("📦 2. 动态路由测试")

	total++
	fmt.Print("  🧪 单参数路由... ")
	if checkSingleParam(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "单参数路由")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 多参数路由... ")
	if checkMultiParams(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "多参数路由")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 嵌套参数路由... ")
	if checkNestedParams(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "嵌套参数路由")
		fmt.Println("❌")
	}
	fmt.Println()

	// 3. 查询参数测试
	fmt.Println("📦 3. 查询参数测试")

	total++
	fmt.Print("  🧪 单个查询参数... ")
	if checkSingleQuery(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "单个查询参数")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 多个查询参数... ")
	if checkMultiQuery(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "多个查询参数")
		fmt.Println("❌")
	}
	fmt.Println()

	// 4. 响应格式测试
	fmt.Println("📦 4. 响应格式测试")

	total++
	fmt.Print("  🧪 JSON 响应... ")
	if checkJSONResponse(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "JSON 响应")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 HTML 响应... ")
	if checkHTMLResponse(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "HTML 响应")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 自定义状态码 201... ")
	if checkCustomStatus(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "自定义状态码 201")
		fmt.Println("❌")
	}
	fmt.Println()

	// 5. HTTP 方法测试
	fmt.Println("📦 5. HTTP 方法测试")

	total++
	fmt.Print("  🧪 POST 请求... ")
	if checkPOST(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "POST 请求")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 PUT 请求... ")
	if checkPUT(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "PUT 请求")
		fmt.Println("❌")
	}

	total++
	fmt.Print("  🧪 DELETE 请求... ")
	if checkDELETE(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "DELETE 请求")
		fmt.Println("❌")
	}
	fmt.Println()

	// 6. 错误处理测试
	fmt.Println("📦 6. 错误处理测试")

	total++
	fmt.Print("  🧪 404 未找到... ")
	if checkNotFound(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "404 未找到")
		fmt.Println("❌")
	}
	fmt.Println()

	// 7. Keep-Alive 测试
	fmt.Println("📦 7. Keep-Alive 连接测试")

	total++
	fmt.Print("  🧪 连接复用... ")
	if checkKeepAlive(client) {
		passed++
		fmt.Println("✅")
	} else {
		failed++
		errors = append(errors, "连接复用")
		fmt.Println("❌")
	}
	fmt.Println()

	// 8. 性能测试
	fmt.Println("📦 8. 性能测试")

	total++
	fmt.Print("  🧪 吞吐量测试... ")
	rps := checkThroughput(client)
	if rps > 100 {
		passed++
		fmt.Printf("✅ (%.0f req/s)\n", rps)
	} else {
		failed++
		errors = append(errors, "吞吐量")
		fmt.Printf("❌ (%.0f req/s)\n", rps)
	}
	fmt.Println()

	// 输出总结
	fmt.Println("═══════════════════════════════════════════════════════════════")
	fmt.Printf("📊 测试结果: %d/%d 通过\n", passed, total)

	if failed > 0 {
		fmt.Println("❌ 失败的测试:")
		for _, err := range errors {
			fmt.Printf("   - %s\n", err)
		}
	} else {
		fmt.Println("🎉 所有测试通过！uSockets 后端验证成功！")
	}
	fmt.Println("═══════════════════════════════════════════════════════════════")
}

func checkServer(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == 200
}

func getBody(resp *http.Response) string {
	body, _ := io.ReadAll(resp.Body)
	return string(body)
}

func checkGetRoot(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "Hello")
}

func checkGetHealth(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && body == "OK"
}

func checkGetStatic(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && body == "OK"
}

func checkSingleParam(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/users/456")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "456")
}

func checkMultiParams(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/users/123/posts/789")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "123") && strings.Contains(body, "789")
}

func checkNestedParams(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/categories/tech/items/laptop")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "tech") && strings.Contains(body, "laptop")
}

func checkSingleQuery(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/search?q=test")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "test")
}

func checkMultiQuery(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/search?q=hello&limit=10&page=1")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "hello")
}

func checkJSONResponse(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/json")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	ct := resp.Header.Get("Content-Type")
	return resp.StatusCode == 200 && strings.Contains(ct, "application/json")
}

func checkHTMLResponse(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/html")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	ct := resp.Header.Get("Content-Type")
	return resp.StatusCode == 200 && strings.Contains(ct, "text/html")
}

func checkCustomStatus(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/api/created")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == 201
}

func checkPOST(client *http.Client) bool {
	resp, err := client.Post(baseURL+"/api/users", "application/json", nil)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 201 && strings.Contains(body, "created")
}

func checkPUT(client *http.Client) bool {
	req, _ := http.NewRequest("PUT", baseURL+"/api/users/123", nil)
	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "updated")
}

func checkDELETE(client *http.Client) bool {
	req, _ := http.NewRequest("DELETE", baseURL+"/api/users/123", nil)
	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body := getBody(resp)
	return resp.StatusCode == 200 && strings.Contains(body, "deleted")
}

func checkNotFound(client *http.Client) bool {
	resp, err := client.Get(baseURL + "/nonexistent/path")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == 404
}

func checkKeepAlive(client *http.Client) bool {
	for i := 0; i < 10; i++ {
		resp, err := client.Get(baseURL + "/health")
		if err != nil {
			return false
		}
		resp.Body.Close()
		if resp.StatusCode != 200 {
			return false
		}
	}
	return true
}

func checkThroughput(client *http.Client) float64 {
	start := time.Now()
	concurrency := 1000
	totalRequests := 1000000
	requestsPerWorker := totalRequests / concurrency

	// 创建共享的 Transport，启用连接池复用
	transport := &http.Transport{
		MaxIdleConns:        concurrency,
		MaxIdleConnsPerHost: concurrency,
		IdleConnTimeout:     30 * time.Second,
		DisableKeepAlives:   false,
	}

	results := make(chan int, concurrency)

	for i := 0; i < concurrency; i++ {
		go func() {
			localSuccess := 0
			// 每个 goroutine 使用独立 Client，但共享 Transport（连接池）
			localClient := &http.Client{
				Timeout:   10 * time.Second,
				Transport: transport,
			}
			for j := 0; j < requestsPerWorker; j++ {
				resp, err := localClient.Get(baseURL + "/health")
				if err != nil {
					continue
				}
				io.Copy(io.Discard, resp.Body)
				resp.Body.Close()
				if resp.StatusCode == 200 {
					localSuccess++
				}
			}
			results <- localSuccess
		}()
	}

	success := 0
	for i := 0; i < concurrency; i++ {
		success += <-results
	}

	elapsed := time.Since(start).Seconds()
	fmt.Printf("\n    [并发: %d, 总请求: %d, 成功: %d, 耗时: %.2fs]\n    ", concurrency, totalRequests, success, elapsed)
	return float64(success) / elapsed
}
