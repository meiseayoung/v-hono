import net.http
import hono

fn main() {
	mut hono_app := hono.Hono{}
	hono_app.get('/article/:id', fn (req hono.Request) http.Response {
		println('Request url: ${req.url}')
		println('Query map: ${req.query}')
		println('Param map: ${req.param}')
		return hono.Response.text('Hello, GET request! id = ${req.param['id']}, q = ${req.param['q']}')
	})
	hono_app.get('/api/**/:folder/user', fn (req hono.Request) http.Response {
		println('Request url: ${req.url}')
		println('Query map: ${req.query}')
		println('Param map: ${req.param}')
		return hono.Response.text('Hello, GET request! id = ${req.param['id']}, q = ${req.param['q']}')
	})
	hono_app.post('/users/**', fn (req hono.Request) http.Response {
		println('Request url: ${req.url}')
		println('Query map: ${req.query}')
		println('Param map: ${req.param}')
		return hono.Response.text('Hello, GET request! id = ${req.param['id']}, q = ${req.param['q']}')
	})
	hono_app.get('/hello/:id/id/:q', fn (req hono.Request) http.Response {
		println('Request url: ${req.url}')
		println('Query map: ${req.query}')
		println('Param map: ${req.param}')
		return hono.Response.text('Hello, GET request! id = ${req.param['id']}, q = ${req.param['q']}')
	})
	hono_app.get('/html', fn (req hono.Request) http.Response {
		println('Request url: ${req.url}')
		println('Query map: ${req.query}')
		println('Param map: ${req.param}')
		result := '<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
	<title>Document</title>
	<script>
		const socket = new WebSocket("ws://127.0.0.1:8888")
		socket.onopen = function (event) {
			console.log("WebSocket is open now.")
			socket.send("hello")
		}
	</script>
</head>
<body>
	<h1>Component A</h1>
</body>
</html>'
		return hono.Response.html(result)
	})
	hono_app.get('/order/:id', fn (req hono.Request) http.Response {
		println('Query map: ${req.query}')
		println('Param map: ${req.param}')
		result := '{}'
		return hono.Response.json(result)
	})
	hono_app.put('/order/:id', fn (req hono.Request) http.Response {
		println('Query map: ${req.query}')
		println('Param map: ${req.param}')
		result := '{}'
		return hono.Response.json(result)
	})
	hono_app.post('/post/*', fn (req hono.Request) http.Response {
		println('Received POST request: ${req.data}')
		return http.Response{
			body:        'Hello, POST request'
			status_code: 200
		}
	})
	port := '0.0.0.0:8585'
	hono_app.listen(port)
	println('Listening on ${port}')
}
