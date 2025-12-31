package main

import (
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	url := flag.String("url", "http://127.0.0.1:3000", "Target base URL")
	connections := flag.Int("c", 500, "Number of connections")
	requests := flag.Int("n", 1000000, "Total number of requests")
	flag.Parse()

	fmt.Printf("Benchmarking %s/users/:id\n", *url)
	fmt.Printf("Connections: %d, Requests: %d\n\n", *connections, *requests)

	client := &http.Client{
		Transport: &http.Transport{
			MaxIdleConns:        *connections,
			MaxIdleConnsPerHost: *connections,
			MaxConnsPerHost:     *connections,
			IdleConnTimeout:     90 * time.Second,
		},
		Timeout: 10 * time.Second,
	}

	var completed int64
	var errors int64
	var latencies []int64
	var mu sync.Mutex
	totalReqs := int64(*requests)

	start := time.Now()

	var wg sync.WaitGroup
	for i := 0; i < *connections; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				if atomic.LoadInt64(&completed)+atomic.LoadInt64(&errors) >= totalReqs {
					return
				}
				reqStart := time.Now()
				userId := rand.Intn(10000)
				targetUrl := fmt.Sprintf("%s/users/%d", *url, userId)
				resp, err := client.Get(targetUrl)
				if err != nil {
					atomic.AddInt64(&errors, 1)
					continue
				}
				io.Copy(io.Discard, resp.Body)
				resp.Body.Close()

				latency := time.Since(reqStart).Microseconds()
				mu.Lock()
				latencies = append(latencies, latency)
				mu.Unlock()
				atomic.AddInt64(&completed, 1)
			}
		}()
	}

	wg.Wait()

	elapsed := time.Since(start).Seconds()
	total := atomic.LoadInt64(&completed)
	errs := atomic.LoadInt64(&errors)
	rps := float64(total) / elapsed

	mu.Lock()
	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	var avg, p50, p95, p99 int64
	if len(latencies) > 0 {
		var sum int64
		for _, l := range latencies {
			sum += l
		}
		avg = sum / int64(len(latencies))
		p50 = latencies[len(latencies)*50/100]
		p95 = latencies[len(latencies)*95/100]
		p99 = latencies[len(latencies)*99/100]
	}
	mu.Unlock()

	fmt.Println("Results:")
	fmt.Printf("  Requests:    %d\n", total)
	fmt.Printf("  Errors:      %d\n", errs)
	fmt.Printf("  Duration:    %.2fs\n", elapsed)
	fmt.Printf("  RPS:         %.0f\n", rps)
	fmt.Printf("  Latency avg: %.2fms\n", float64(avg)/1000)
	fmt.Printf("  Latency p50: %.2fms\n", float64(p50)/1000)
	fmt.Printf("  Latency p95: %.2fms\n", float64(p95)/1000)
	fmt.Printf("  Latency p99: %.2fms\n", float64(p99)/1000)
}
