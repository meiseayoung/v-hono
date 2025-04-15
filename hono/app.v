module hono

import net.urllib
import net.http
import regex
import time

type Handler = fn (req Request) http.Response

struct RequestHandler {
	path    string
	handler Handler = unsafe { nil }
}

struct Router {
mut:
	handlers struct {
	mut:
		get     []RequestHandler
		post    []RequestHandler
		put     []RequestHandler
		delete  []RequestHandler
		patch   []RequestHandler
		head    []RequestHandler
		options []RequestHandler
	}
}

pub struct Hono {
mut:
	server http.Server = http.Server{}
	router Router      = Router{}
}

pub fn (mut app Hono) get(path string, handler Handler) {
	app.router.handlers.get << RequestHandler{path, handler}
}

pub fn (mut app Hono) post(path string, handler Handler) {
	app.router.handlers.post << RequestHandler{path, handler}
}

pub fn (mut app Hono) put(path string, handler Handler) {
	app.router.handlers.put << RequestHandler{path, handler}
}

pub fn (mut app Hono) delete(path string, handler Handler) {
	app.router.handlers.delete << RequestHandler{path, handler}
}

pub fn (mut app Hono) patch(path string, handler Handler) {
	app.router.handlers.patch << RequestHandler{path, handler}
}

pub fn (mut app Hono) head(path string, handler Handler) {
	app.router.handlers.head << RequestHandler{path, handler}
}

pub fn (mut app Hono) options(path string, handler Handler) {
	app.router.handlers.options << RequestHandler{path, handler}
}

struct ServerHanler {
	app Hono
}

fn ServerHanler.new(app Hono) ServerHanler {
	return ServerHanler{
		app: app
	}
}

fn match_path_with_regex(real_path string, reg_path string) (bool, regex.RE) {
	start := time.now()
	mut one_more_star_reg := regex.regex_opt(r'\*{2,}') or { panic(err) }
	repl_on_e_more_star_fn := fn (re regex.RE, in_txt string, start int, end int) string {
		if in_txt.ends_with('*') {
			return r'([^#\?]/){0,}[^#\?]+'
		}
		return r'([^#\?]+//){0,}[^#\?]+'
	}
	mut replaced_reg_path := reg_path.replace('?', r'\?')
	replaced_reg_path = replaced_reg_path.replace('+', r'\+')
	mut replaced_path := one_more_star_reg.replace_by_fn(replaced_reg_path, repl_on_e_more_star_fn)
	replaced_path = replaced_path.replace('*', r'[^#\?]+')
	mut pamam_reg := regex.regex_opt(r':[^/]+') or { panic(err) }
	repl_fn := fn (re regex.RE, in_txt string, start int, end int) string {
		match_str := in_txt[start..end]
		return '(?P<${match_str[1..]}>[^/]+)'
	}
	replaced_path = pamam_reg.replace_by_fn(replaced_path, repl_fn)
	replaced_path = replaced_path + '$'
	mut reg := regex.regex_opt(replaced_path) or { panic(err) }
	end := time.now()
	println('Regex time: ${end - start}')
	return reg.matches_string(real_path), reg
}

fn (s ServerHanler) handle(req http.Request) http.Response {
	mut res := http.Response{
		status_code: 404
		body:        'Not Found'
	}
	handlers := match req.method {
		.get {
			s.app.router.handlers.get
		}
		.post {
			s.app.router.handlers.post
		}
		.put {
			s.app.router.handlers.put
		}
		.delete {
			s.app.router.handlers.delete
		}
		.patch {
			s.app.router.handlers.patch
		}
		.head {
			s.app.router.handlers.head
		}
		.options {
			s.app.router.handlers.options
		}
		else {
			[]
		}
	}
	for handler in handlers {
		url := urllib.parse(req.url) or {
			urllib.URL{
				path: '/'
			}
		}
		match_result, mut replaced_path_reg := match_path_with_regex(url.path, handler.path)
		if match_result {
			mut param_map := map[string]string{}
			mut pamam_reg := regex.regex_opt(r':\w+') or { panic(err) }
			all_params := pamam_reg.find_all_str(handler.path)
			for param in all_params {
				param_name := param[1..]
				group := replaced_path_reg.get_group_by_name(url.path, param_name)
				param_map[param_name] = group
			}
			query_map := url.query().to_map()
			res = handler.handler(Request{
				url:   url.path
				param: param_map
				query: query_map
			})
			break
		}
	}
	return res
}

pub fn (mut app Hono) listen(port string) {
	app.server.addr = port
	app.server.handler = ServerHanler.new(app)
	app.server.listen_and_serve()
}
