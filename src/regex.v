import regex

fn main(){
	path := "/order/**"
	mut replaced_path := path.replace('**','[\\w+//?]+')
	println("replaced_path: ${replaced_path}")
	replaced_path = replaced_path.replace('*','\\w+')
	println("replaced_path: ${replaced_path}")
	replaced_path = replaced_path + '$'
	println("replaced_path: ${replaced_path}")
	mut reg := regex.regex_opt(replaced_path) or { panic(err) }
	result := reg.matches_string("/order/33")
	println("reg match result ${result}")
}