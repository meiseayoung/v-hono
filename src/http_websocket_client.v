import net.websocket as socket

fn main() {
	opt := socket.ClientOpt{}

	mut client := socket.new_client('ws://127.0.0.1:8888/hi', opt)!

	client.connect()!

	client.write_string('hi from client')!

	client.listen()!
}
