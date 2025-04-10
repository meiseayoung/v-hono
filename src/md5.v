import net.http { get,Response }
import crypto.md5
import time

fn hexhash(text string) string {
	return md5.hexhash(text)
}

fn get_content(url string) string {
	content := get(url) or {
		println("Error: $err")
		Response{
			body:"string"
		}
	}
	result := content.bytestr()
	println("get_content ${url} ${result[0..10]}")
	return result
}

fn worker(id int, jobs chan int, results chan int) {
    for {
        job := <-jobs // 从jobs通道接收任务
        println('工作者 ${id} 开始处理任务 ${job}')
        // 模拟工作耗时
        time.sleep(job * 100 * time.millisecond)
		j1 := job * 2
		results <- j1 // 将结果发送到results通道
    }
}

fn main()  {
	jobs := chan int{cap: 10}
    results := chan int{cap: 10}

    // 启动3个工作者协程
    for i in 0..3 {
        spawn worker(i, jobs, results)
    }

    // 发送5个任务
    for i in 1..6 {
        jobs <- i
    }

    // 接收并处理结果
    // for _ in 1..6 {
    //     result := <-results
    //     println('收到结果: ${result}')
    // }
	mut count := 0
	for {
		select {
			result := <-results {
				println('收到结果: ${result}')
				count++
			}
			1000 * time.millisecond {
				println('超时')
				break
			}
		}

		if count >= 6 {
			break
		}
	}
	start := time.now()
	mut threads := []thread string{}
	for _ in 1..20 {
		time.sleep(0.01)
		threads << spawn get_content("https://www.163.com")
	}
	// contents := threads.wait()
	end := time.now()
	println("get_content time ${end - start}")
	// println("md5 init. ${contents[0][0]}")
}
