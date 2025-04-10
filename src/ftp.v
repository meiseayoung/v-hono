import net.ftp

fn main() {
	mut instance := ftp.new()
	println('instance')
	defer {
		instance.close() or { panic(err) }
	}
	connected := instance.connect('148.251.128.152:22')!
	println('connected ${connected}')
	login_status := instance.login('root', '6e5W3kqeTWKqQG')!
	println('login_status ${login_status}')
}
