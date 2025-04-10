module hono

import net.http

pub struct Request {
pub:
	url    string
	header http.Header
	query  map[string][]string
	param  map[string]string
	data   map[string]string
}
