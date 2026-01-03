// 高并发测试 (5000-10000 并发)
//
// 使用方法:
// 1. 启动服务器 (必须设置 ulimit): ulimit -n 65535 && ./bench_server_usockets
// 2. 运行测试: ulimit -n 65535 && go run v-hono/tests/test_high_concurrency.go
// 3. 单独测试某个级别: ulimit -n 65535 && go run v-hono/tests/test_high_concurrency.go 8000
//
// 重要提示:
// - 服务器和客户端都需要设置 ulimit -n 65535
// - 连续测试多个并发级别时，建议每次测试前重启服务器
// - TIME_WAIT 连接会影响后续测试，建议等待 10 秒后再测试下一个级别
//
// 系统配置要求 (macOS):
//   sudo sysctl -w kern.ipc.somaxconn=8192
//   ulimit -n 65535

package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

type BenchResult struct {
	Concurrency int
	TotalReqs   int64
	SuccessReqs int64
	RPS         float64
	AvgLatency  float64
	P99Latency  float64
	SuccessRate float64
}

func main() {
	baseURL := "http://127.0.0.1:8080/"
	duration := 10 * time.Second

	// 默认测试级别: 5000, 6000, 7000, 8000, 9000, 10000
	concurrencyLevels := []int{5000, 6000, 7000, 8000, 9000, 10000}

	// 支持命令行参数指定单个并发级别
	if len(os.Args) > 1 {
		level, err := strconv.Atoi(os.Args[1])
		if err == nil {
			concurrencyLevels = []int{level}
		}
	}

	fmt.Println("╔═══════════════════════════════════════════════════════════════════════════╗")
	fmt.Println("║              v-hono 高并发测试 (5000-10000 并发)                          ║")
	fmt.Println("╚═══════════════════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// 检查服务器是否运行
	if !checkServer(baseURL) {
		fmt.Println("❌ 服务器未运行")
		fmt.Println("   请先启动: ./bench_server_usockets")
		fmt.Println()
		fmt.Println("   系统配置要求:")
		fmt.Println("   - macOS: sudo sysctl -w kern.ipc.somaxconn=8192")
		fmt.Println("   - ulimit -n 65535")
		return
	}
	fmt.Println("✅ 服务器已就绪")
	fmt.Println()

	results := make([]BenchResult, 0, len(concurrencyLevels))

	for _, conns := range concurrencyLevels {
		result := runBenchmark(baseURL, conns, duration)
		results = append(results, result)

		// 测试间隔，让系统恢复 (TIME_WAIT 连接需要时间释放)
		// macOS TIME_WAIT 默认 15-30 秒，建议等待 60 秒
		if len(concurrencyLevels) > 1 {
			fmt.Println("   ⏳ 等待 60 秒让系统恢复 (TIME_WAIT 连接释放)...")
			time.Sleep(60 * time.Second)
		}
	}

	// 输出汇总报告
	printSummary(results)
}

func checkServer(baseURL string) bool {
	client := &http.Client{Timeout: 2 * time.Second}
	for i := 0; i < 5; i++ {
		resp, err := client.Get(baseURL)
		if err == nil && resp.StatusCode < 400 {
			resp.Body.Close()
			return true
		}
		time.Sleep(200 * time.Millisecond)
	}
	return false
}

func runBenchmark(baseURL string, conns int, duration time.Duration) BenchResult {
	fmt.Printf("🔥 测试 %d 并发连接 (持续 %v)\n", conns, duration)

	var total, success int64
	var totalLatencyNs int64
	latencies := make([]int64, 0, 1000000)
	var mu sync.Mutex

	client := &http.Client{
		Timeout: 60 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        conns * 2,
			MaxIdleConnsPerHost: conns * 2,
			MaxConnsPerHost:     0,
			IdleConnTimeout:     120 * time.Second,
			DisableKeepAlives:   false,
			ForceAttemptHTTP2:   false,
		},
	}

	var wg sync.WaitGroup
	stop := make(chan struct{})
	start := time.Now()

	// 同时启动所有连接
	for i := 0; i < conns; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-stop:
					return
				default:
					t0 := time.Now()
					resp, err := client.Get(baseURL)
					lat := time.Since(t0).Nanoseconds()

					atomic.AddInt64(&total, 1)
					atomic.AddInt64(&totalLatencyNs, lat)

					mu.Lock()
					latencies = append(latencies, lat)
					mu.Unlock()

					if err != nil {
						continue
					}
					io.Copy(io.Discard, resp.Body)
					resp.Body.Close()
					if resp.StatusCode < 400 {
						atomic.AddInt64(&success, 1)
					}
				}
			}
		}()
	}

	time.Sleep(duration)
	close(stop)
	wg.Wait()

	elapsed := time.Since(start)

	// 计算 P99
	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	p99 := int64(0)
	if len(latencies) > 0 {
		idx := len(latencies) * 99 / 100
		p99 = latencies[idx]
	}

	avgLat := float64(totalLatencyNs) / float64(total) / 1e6
	rps := float64(total) / elapsed.Seconds()
	successRate := float64(success) / float64(total) * 100

	// 判断测试结果
	status := "✅"
	if successRate < 99.0 {
		status = "⚠️"
	}
	if successRate < 90.0 {
		status = "❌"
	}

	fmt.Printf("   %s RPS: %8.0f  Avg: %6.2fms  P99: %6.2fms  Success: %.1f%%\n",
		status, rps, avgLat, float64(p99)/1e6, successRate)
	fmt.Println()

	return BenchResult{
		Concurrency: conns,
		TotalReqs:   total,
		SuccessReqs: success,
		RPS:         rps,
		AvgLatency:  avgLat,
		P99Latency:  float64(p99) / 1e6,
		SuccessRate: successRate,
	}
}

func printSummary(results []BenchResult) {
	if len(results) <= 1 {
		return
	}

	fmt.Println("═══════════════════════════════════════════════════════════════════════════")
	fmt.Println("                           📊 测试结果汇总")
	fmt.Println("═══════════════════════════════════════════════════════════════════════════")
	fmt.Println()
	fmt.Println("┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐")
	fmt.Println("│   并发数     │     RPS      │   平均延迟   │   P99延迟    │   成功率     │")
	fmt.Println("├──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤")

	allPassed := true
	for _, r := range results {
		status := "✅"
		if r.SuccessRate < 99.0 {
			status = "⚠️"
			allPassed = false
		}
		if r.SuccessRate < 90.0 {
			status = "❌"
			allPassed = false
		}

		fmt.Printf("│ %s %6d    │ %10.0f   │ %8.2fms   │ %8.2fms   │ %8.1f%%   │\n",
			status, r.Concurrency, r.RPS, r.AvgLatency, r.P99Latency, r.SuccessRate)
	}

	fmt.Println("└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘")
	fmt.Println()

	if allPassed {
		fmt.Println("🎉 所有高并发测试通过！v-hono uSockets 后端表现优秀！")
	} else {
		fmt.Println("⚠️  部分测试未达到 99% 成功率，请检查系统配置")
		fmt.Println("   - macOS: sudo sysctl -w kern.ipc.somaxconn=8192")
		fmt.Println("   - ulimit -n 65535")
	}
	fmt.Println()
}
