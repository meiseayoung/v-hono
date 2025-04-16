module hono

fn init() {
	is_match, _ := match_path_with_regex('/api/v1/user', '/api/v1/:user_id')
	assert is_match == true
	is_match2, reg2 := match_path_with_regex('/api/v1/abc/user', '/api/**/user')
	println('reg2: ${reg2.query}')
	assert is_match2 == true
	is_match3, reg := match_path_with_regex('/users/123/posts/456/comments', '/users/**')
	println('reg: ${reg.query}')
	assert is_match3 == true
	is_match4, _ := match_path_with_regex('/article+&9/article1/why-!important#999', '/article+&*/:article/why-!important#999')
	assert is_match4 == true
	is_match5, _ := match_path_with_regex('/api/aaa/bbb/////888', '/api/**/888')
	assert is_match5 == true
	println('all tests passed')
}
