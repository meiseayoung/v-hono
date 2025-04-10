import net.http.file;
import os

fn main() {
	path := os.join_path(os.abs_path('./'),'/component/')
	println("path ${path}")
	file.serve(folder: "./src/component",on: "127.0.0.1:5002")
}
