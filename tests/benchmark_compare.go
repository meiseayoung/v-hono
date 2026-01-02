// 高并发基准测试 - 用于对比 v-hono 内外性能
// 参数与外层 benchmark.go 保持一致: 500 并发, 100万请求
//
// 使用方法:
// 1. 启动服务器: v -enable-globals run v-hono/tests/test_picoev_server.v
// 2. 运行测试: go run v-hono/tests/benchmark_compare.go

package main

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	baseURL     = "http://127.0.0.1:9999"
	connections = 500
	requests    = 1000000
	timeout     = 10 * time.Second
)

type Metrics struct {
	TotalRequests   int64
	SuccessRequests int64
	FailedRequests  int64
	TotalBytes      int64
	MinLatency      time.Duration
	MaxLatency      time.Duration
	TotalLatencyNs  int64
	StartTime       time.Time
	EndTime         time.Time
}

func main() {
	fmt.Println("🔥 V-Hono 高并发基准测试")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Printf("服务器: %s\n", baseURL)
	fmt.Printf("并发数: %d\n", connections)
	fmt.Printf("请求数: %d\n", requests)
	fmt.Printf("超时:   %v\n", timeout)
	fmt.Println()

	// 检查服务器
	if !checkServer() {
		fmt.Println("❌ 服务器未运行")
		fmt.Println("   请先启动: v -enable-globals run v-hono/tests/test_picoev_server.v")
		return
	}
	fmt.Println("✅ 服务器已就绪")

	// 预热
	fmt.Println("\n🔥 预热服务器...")
	warmup()
	fmt.Println("✅ 预热完成")

	// 运行测试
	testCases := []struct {
		name string
		path string
	}{
		{"健康检查", "/health"},
		{"根路径", "/"},
		{"JSON接口", "/json"},
		{"动态路由", "/users/123"},
	}

	allResults := make(map[string]*Metrics)

	for _, tc := range testCases {
		fmt.Printf("\n🚀 测试: %s (%s)\n", tc.name, tc.path)
		fmt.Println(strings.Repeat("-", 50))

		metrics := runBenchmark(tc.path)
		allResults[tc.name] = metrics
		printMetrics(tc.name, metrics)

		time.Sleep(2 * time.Second)
	}

	// 汇总
	printSummary(allResults)
}

func checkServer() bool {
	client := &http.Client{Timeout: 2 * time.Second}
	for i := 0; i < 3; i++ {
		resp, err := client.Get(baseURL + "/health")
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			return true
		}
		time.Sleep(500 * time.Millisecond)
	}
	return false
}

func warmup() {
	client := &http.Client{Timeout: 5 * time.Second}
	for i := 0; i < 100; i++ {
		resp, err := client.Get(baseURL + "/health")
		if err == nil {
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
		}
	}
}

func runBenchmark(endpoint string) *Metrics {
	url := baseURL + endpoint
	metrics := &Metrics{
		StartTime:  time.Now(),
		MinLatency: time.Hour,
	}

	client := &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			MaxIdleConns:        connections,
			MaxIdleConnsPerHost: connections,
			IdleConnTimeout:     30 * time.Second,
		},
	}

	requestsPerWorker := requests / connections
	var wg sync.WaitGroup
	var latencyMutex sync.Mutex

	// 进度显示
	done := make(chan bool)
	go showProgress(metrics, done)

	// 启动工作协程
	for i := 0; i < connections; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			for j := 0; j < requestsPerWorker; j++ {
				start := time.Now()
				resp, err := client.Get(url)
				latency := time.Since(start)

				atomic.AddInt64(&metrics.TotalRequests, 1)
				atomic.AddInt64(&metrics.TotalLatencyNs, int64(latency))

				latencyMutex.Lock()
				if latency < metrics.MinLatency {
					metrics.MinLatency = latency
				}
				if latency > metrics.MaxLatency {
					metrics.MaxLatency = latency
				}
				latencyMutex.Unlock()

				if err != nil {
					atomic.AddInt64(&metrics.FailedRequests, 1)
					continue
				}

				body, err := io.ReadAll(resp.Body)
				resp.Body.Close()

				if err != nil || resp.StatusCode >= 400 {
					atomic.AddInt64(&metrics.FailedRequests, 1)
				} else {
					atomic.AddInt64(&metrics.SuccessRequests, 1)
					atomic.AddInt64(&metrics.TotalBytes, int64(len(body)))
				}
			}
		}()
	}

	wg.Wait()
	metrics.EndTime = time.Now()
	done <- true

	return metrics
}

func showProgress(metrics *Metrics, done chan bool) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-done:
			fmt.Println()
			return
		case <-ticker.C:
			current := atomic.LoadInt64(&metrics.TotalRequests)
			elapsed := time.Since(metrics.StartTime).Seconds()
			rps := float64(current) / elapsed
			progress := float64(current) / float64(requests) * 100

			fmt.Printf("\r进度: %.1f%% | 完成: %d | RPS: %.0f | 耗时: %.1fs",
				progress, current, rps, elapsed)
		}
	}
}

func printMetrics(name string, m *Metrics) {
	duration := m.EndTime.Sub(m.StartTime)
	avgLatency := time.Duration(m.TotalLatencyNs / m.TotalRequests)

	fmt.Printf("\n📊 %s - 测试结果\n", name)
	fmt.Println(strings.Repeat("=", 40))

	fmt.Printf("总请求数:     %d\n", m.TotalRequests)
	fmt.Printf("成功请求:     %d\n", m.SuccessRequests)
	fmt.Printf("失败请求:     %d\n", m.FailedRequests)
	fmt.Printf("成功率:       %.2f%%\n", float64(m.SuccessRequests)/float64(m.TotalRequests)*100)

	fmt.Printf("总耗时:       %.2f 秒\n", duration.Seconds())
	fmt.Printf("RPS:          %.0f 请求/秒\n", float64(m.TotalRequests)/duration.Seconds())

	fmt.Printf("最小延迟:     %v\n", m.MinLatency)
	fmt.Printf("最大延迟:     %v\n", m.MaxLatency)
	fmt.Printf("平均延迟:     %v\n", avgLatency)

	if m.TotalBytes > 0 {
		throughputMB := float64(m.TotalBytes) / 1024 / 1024 / duration.Seconds()
		fmt.Printf("数据传输:     %.2f MB\n", float64(m.TotalBytes)/1024/1024)
		fmt.Printf("吞吐量:       %.2f MB/s\n", throughputMB)
	}
}

func printSummary(results map[string]*Metrics) {
	fmt.Printf("\n🏆 性能汇总报告\n")
	fmt.Println(strings.Repeat("=", 60))

	fmt.Printf("%-15s %-12s %-10s %-12s %-10s\n", "接口", "RPS", "成功率", "平均延迟", "吞吐量")
	fmt.Println(strings.Repeat("-", 60))

	for name, metrics := range results {
		duration := metrics.EndTime.Sub(metrics.StartTime)
		rps := float64(metrics.TotalRequests) / duration.Seconds()
		successRate := float64(metrics.SuccessRequests) / float64(metrics.TotalRequests) * 100
		avgLatency := time.Duration(metrics.TotalLatencyNs / metrics.TotalRequests)
		throughput := float64(metrics.TotalBytes) / 1024 / 1024 / duration.Seconds()

		fmt.Printf("%-15s %-12.0f %-9.1f%% %-12v %-8.1fMB/s\n",
			name, rps, successRate, avgLatency, throughput)
	}

	fmt.Println("\n✅ 测试完成!")
}
