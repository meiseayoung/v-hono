module main

import pathlib { Path }
import time
import rand
import crypto.md5
import os

fn async_fn(print_string string, delay f32) f32 {
	return delay
}

fn main() {
	p1 := Path{}
	p2 := Path{
		path: '//src'
	}
	println('p2 ${p2}')
	p3 := p1 / p2
	println('p3: ${p3}')
	for path in p3.walk() {
		println('${path}')
	}

	match_results := p3.glob('**.html')
	println('match_results ${match_results}')
	mut threads := []f32{}
	start := time.now()
	for _ in 1 .. 1000 {
		threads << async_fn('1', rand.f32())
	}
	end := time.now()
	println('spawn time ${end - start}')
	println('done ${threads[0..10]}')
	println('absolute path ${os.abs_path('.')}')
	text := os.read_file(Path{ path: './src/component/maplabel.js' }.absolute().path) or {
		eprintln('failed to read the file: ${err}')
		return
	}
	hash_start := time.now()
	println('hexhash ${md5.hexhash(text)}')
	hash_end := time.now()
	println('hash time ${hash_end - hash_start}')
}
