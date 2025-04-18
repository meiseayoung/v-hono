// import regex
import pcre

fn main() {
	// path := '/order/**'
	// mut replaced_path := path.replace('**','[\\w+//?]+')
	// println("replaced_path: ${replaced_path}")
	// replaced_path = replaced_path.replace('*','\\w+')
	// println("replaced_path: ${replaced_path}")
	// replaced_path = replaced_path + '$'
	// println("replaced_path: ${replaced_path}")
	// mut reg := regex.regex_opt(replaced_path) or { panic(err) }
	// result := reg.matches_string("/order/33")
	mut reg := pcre.new_regex(r'/(?:order)/[\w+/]+', 0) or { panic(err) }
	result := reg.match_str('555/order/33//?88/', 0, 0) or { panic(err) }
	mut count := 0
	for count < result.group_size {
		println('group ${count} ${result.get(count) or { 'not found' }}')
		count++
	}
	println('reg match result ${result}')
}
