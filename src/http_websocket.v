import net.websocket as socket
import net

fn main() {
	opt := socket.ServerOpt{}

	addr := net.AddrFamily.ip

	mut server := socket.new_server(addr, 8888, '', opt)

	server.on_connect(fn (mut client socket.ServerClient) !bool {
		println('Client connected from')
		conn := client.client.conn
		peer_ip := conn.peer_ip() or { '0.0.0.0' }
		println('IP: ${peer_ip}')
		return true
	})!

	server.on_message(fn (mut client socket.Client, msg &socket.Message) ! {
		payload := msg.payload
		if payload.len > 0 {
			println('payload: ${payload.bytestr()}')
			client.write_string('hello from server')!
		}
	})

	server.listen()!
}
