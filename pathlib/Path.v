module pathlib

import regex
import os { File }

pub struct Path {
pub:
	path string = os.abs_path ('.')
}

pub fn Path.pwd() Path {
	pwd := os.abs_path ('./')
	return Path {
		path: pwd
	}
}
pub fn (p Path) exists() bool {
	return os.exists(p.path)
}

pub fn (p Path) absolute() Path {
	return Path{
		path: os.abs_path(p.path)
	}
}

pub fn (p Path) is_dir() bool {
    return os.is_dir(p.path)
}

pub fn (p Path) is_file() bool {
	return os.is_file(p.path)
}

pub fn (p Path) walk() []Path {
	entries := os.ls(p.path) or { [] }
	mut result := [] Path {}
	if !p.is_dir() {
		return result
	}
	for entry in entries {
		entry_path := Path{
			path:entry
		}
		current_path := p / entry_path
		result << current_path
		if current_path.is_dir(){
			result << current_path.walk()
		}
	}
	return result
}


pub fn (p Path) str() string {
		mut p_path := p.path
		mut re := regex.regex_opt(r'^[/\\]+') or { panic(error)}
		p_path = re.replace(p_path,'/')
        return "Path(${p_path})"
}

pub fn (p Path) / (n Path) Path {
		mut n_path := n.path
		mut re := regex.regex_opt(r'[/\\]+') or { panic(error)}
		n_path = re.replace(n_path,'')
        return Path{
                path: p.path + '\\' + n_path
        }
}

pub fn (p Path) glob(pattern string) []Path {
	match_results := os.glob(pattern) or { ["abc"] }
	return match_results.map(fn (path string) Path {
		return Path {
			path: path
		}
	})
}
