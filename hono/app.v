module hono

import net.urllib
import net.http
import regex
import time

type Handler = fn (req Request) http.Response

struct RequestHandler {
	path    string
	handler Handler = unsafe { nil }
	mut: app Hono
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
	routes map[string] Hono = {}
	base_path string
}

pub fn (mut app Hono) get(path string, handler Handler) {
	mut handlers := RequestHandler{path,handler,app}
	app.router.handlers.get << handlers
}

pub fn (mut app Hono) post(path string, handler Handler) {
	app.router.handlers.post << RequestHandler{path,handler,app}
}

pub fn (mut app Hono) put(path string, handler Handler) {
	app.router.handlers.put << RequestHandler{path,handler,app}
}

pub fn (mut app Hono) delete(path string, handler Handler) {
	app.router.handlers.delete << RequestHandler{path,handler,app}
}

pub fn (mut app Hono) patch(path string, handler Handler) {
	app.router.handlers.patch << RequestHandler{path,handler,app}
}

pub fn (mut app Hono) head(path string, handler Handler) {
	app.router.handlers.head << RequestHandler{path,handler,app}
}

pub fn (mut app Hono) options(path string, handler Handler) {
	app.router.handlers.options << RequestHandler{path,handler,app}
}

struct ServerHanler {
mut:
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
			return r'[^#\?]+'
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

fn get_all_handlers_from_hono(app Hono,req http.Request) []RequestHandler {
	mut result := []RequestHandler{}
	handlers := match req.method {
		.get {
			app.router.handlers.get
		}
		.post {
			app.router.handlers.post
		}
		.put {
			app.router.handlers.put
		}
		.delete {
			app.router.handlers.delete
		}
		.patch {
			app.router.handlers.patch
		}
		.head {
			app.router.handlers.head
		}
		.options {
			app.router.handlers.options
		}
		else {
			[]
		}
	}
	result << handlers
	for key in app.routes.keys() {
		subapp_handlers := get_all_handlers_from_hono(app.routes[key],req)
		result << subapp_handlers
	}
	return result
}

fn (s ServerHanler) handle(req http.Request) http.Response {
	mut res := http.Response{
		status_code: 404
		body:        'Not Found'
	}
	handlers := get_all_handlers_from_hono(s.app,req)
	for handler in handlers {
		url := urllib.parse(req.url) or {
			urllib.URL{
				path: '/'
			}
		}
		match_result, mut replaced_path_reg := match_path_with_regex(url.path, handler.app.base_path + handler.path)
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

pub fn (mut app Hono) route(prefix string,mut subapp Hono) {
	for mut request_handler in subapp.router.handlers.get {
		request_handler.app.base_path = prefix
	}
	for mut request_handler in subapp.router.handlers.post {
		request_handler.app.base_path = prefix
	}
	app.routes[prefix] = subapp
}

pub fn (mut app Hono) set_base_path(base_path string) {
	app.base_path = base_path
}
