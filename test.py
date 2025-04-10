from  datetime import datetime
def async_fn (delay):
	return delay

threads = []
start = datetime.now()
count = 0
while(count < 10000000):
    count+=1
    threads.append(async_fn(1))
end = datetime.now()
print(f"spawn time {end - start}")
print(f"done {threads[1:100]}")
