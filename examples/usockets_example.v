module main

import net.http
import hono

fn main() {
    mut app := hono.Hono.new()

    app.get('/', fn (mut c hono.Context) http.Response {
        return c.text('Hello from V-Hono + uSockets!')
    })

    app.get('/json', fn (mut c hono.Context) http.Response {
        return c.json('{"message": "Hello, JSON!"}')
    })

    app.get('/users/:id', fn (mut c hono.Context) http.Response {
        user_id := c.params['id'] or { 'unknown' }
        return c.json('{"user_id": "${user_id}"}')
    })

    // 使用 uSockets 后端
    app.listen_usockets(3008)
}
