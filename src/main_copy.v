module main
import os

fn get_file_default_content() string {
	return 'Alala'
}

fn do_nothing() {

}

fn main() {
	areas := ['game', 'web', 'tools', 'science', 'systems','embedded', 'drivers', 'GUI', 'mobile']
    for area in areas {
        println('Hello, ${area} developers!')
    }
	file_content := os.read_file('./src/main.v') or {
		get_file_default_content()
	}
	println('file_content: ${file_content}')

	os.write_file('./src/main_copy.v', file_content) or {
		panic(err.str())
	}
}
