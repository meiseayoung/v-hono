module hono

import net.http

pub struct Response {
}

pub fn Response.json(body string) http.Response {
	return http.Response{
		header:      http.new_header(http.HeaderConfig{
			key:   http.CommonHeader.content_type
			value: 'application/json'
		})
		status_code: 200
		body:        body
	}
}

pub fn Response.text(body string) http.Response {
	return http.Response{
		header:      http.new_header(http.HeaderConfig{
			key:   http.CommonHeader.content_type
			value: 'plain/text'
		})
		status_code: 200
		body:        body
	}
}

pub fn Response.html(body string) http.Response {
	return http.Response{
		header:      http.new_header(http.HeaderConfig{
			key:   http.CommonHeader.content_type
			value: 'text/html'
		})
		status_code: 200
		body:        body
	}
}
