module hono

import json
import net.http

// 登录请求结构
pub struct LoginRequest {
pub:
	username string
	password string
}

// 注册请求结构
pub struct RegisterRequest {
pub:
	username string
	email    string
	password string
	role     string
}

// 菜单创建请求结构
pub struct MenuCreateRequest {
pub:
	name        string
	path        string
	icon        string
	parent_id   int
	sort_order  int
	permissions []string
}

// 认证中间件（只做校验，不注入 user）
pub fn auth_middleware(auth_manager AuthManager) ContextMiddleware {
	return fn [auth_manager] (mut c Context, next fn (mut Context) http.Response) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		if token == '' {
			c.status(401)
			return c.json(json.encode({
				'error': 'Authorization token required'
			}))
		}
		_ := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json.encode({
				'error': 'Invalid or expired token'
			}))
		}
		return next(mut c)
	}
}

// 权限检查中间件（直接校验 token 权限）
pub fn permission_middleware(auth_manager AuthManager, required_permission string) ContextMiddleware {
	return fn [auth_manager, required_permission] (mut c Context, next fn (mut Context) http.Response) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json.encode({
				'error': 'Invalid or expired token'
			}))
		}
		if !auth_manager.check_permission(user, required_permission) {
			c.status(403)
			return c.json(json.encode({
				'error': 'Insufficient permissions'
			}))
		}
		return next(mut c)
	}
}

// 注册认证路由
pub fn register_auth_routes(mut app Hono, mut auth_manager AuthManager) {
	// 登录路由
	app.post('/api/auth/login', fn [mut auth_manager] (mut c Context) http.Response {
		body := c.body
		login_req := json.decode(LoginRequest, body) or {
			c.status(400)
			return c.json(json.encode({
				'error': 'Invalid request body'
			}))
		}
		session := auth_manager.login(login_req.username, login_req.password) or {
			c.status(401)
			return c.json(json.encode({
				'error': err.msg()
			}))
		}
		return c.json(json.encode({
			'token': session.token.str()
			'expires_at': session.expires_at.str()
		}))
	})

	// 注册路由
	app.post('/api/auth/register', fn [mut auth_manager] (mut c Context) http.Response {
		body := c.body
		register_req := json.decode(RegisterRequest, body) or {
			c.status(400)
			return c.json(json.encode({
				'error': 'Invalid request body'
			}))
		}
		role := match register_req.role {
			'admin' { UserRole.admin }
			'manager' { UserRole.manager }
			'user' { UserRole.user }
			'guest' { UserRole.guest }
			else { UserRole.user }
		}
		user := auth_manager.create_user(register_req.username, register_req.email, register_req.password, role) or {
			c.status(400)
			return c.json(json.encode({
				'error': err.msg()
			}))
		}
		return c.json(json.encode({
			'user_id': user.id.str()
			'username': user.username
			'email': user.email
			'role': user.role.str()
		}))
	})

	// 注销路由
	app.post('/api/auth/logout', fn [mut auth_manager] (mut c Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		if token == '' {
			c.status(401)
			return c.json(json.encode({
				'error': 'Authorization token required'
			}))
		}
		auth_manager.logout(token) or {
			c.status(500)
			return c.json(json.encode({
				'error': err.msg()
			}))
		}
		return c.json(json.encode({
			'message': 'Logged out successfully'
		}))
	})

	// 获取用户信息路由
	app.get('/api/auth/profile', fn [auth_manager] (mut c Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json.encode({
				'error': 'Invalid or expired token'
			}))
		}
		return c.json(json.encode({
			'user_id': user.id.str()
			'username': user.username
			'email': user.email
			'role': user.role.str()
			'active': user.status.str()
		}))
	})

	// 获取用户菜单路由
	app.get('/api/auth/menus', fn [auth_manager] (mut c Context) http.Response {
		token := c.req.header.get_custom('Authorization') or { '' }
		user := auth_manager.verify_token(token) or {
			c.status(401)
			return c.json(json.encode({
				'error': 'Invalid or expired token'
			}))
		}
		menus := auth_manager.get_user_menus(user) or {
			c.status(500)
			return c.json(json.encode({
				'error': err.msg()
			}))
		}
		return c.json(json.encode({
			'menus': menus
		}))
	})

	// 创建菜单项路由 (需要管理员权限)
	app.post('/api/auth/menus', fn [mut auth_manager] (mut c Context) http.Response {
		body := c.body
		menu_req := json.decode(MenuCreateRequest, body) or {
			c.status(400)
			return c.json(json.encode({
				'error': 'Invalid request body'
			}))
		}
		menu := auth_manager.create_menu_item(menu_req.name, menu_req.path, menu_req.icon, menu_req.parent_id, menu_req.sort_order, menu_req.permissions) or {
			c.status(400)
			return c.json(json.encode({
				'error': err.msg()
			}))
		}
		return c.json(json.encode({
			'menu_id': menu.id.str()
			'name': menu.name
			'path': menu.path
			'icon': menu.icon
			'parent_id': menu.parent_id.str()
			'sort_order': menu.sort_order.str()
			'permissions': json.encode(menu.permissions)
			'active': menu.status.str()
		}))
	})

	// 获取所有菜单项路由 (需要管理员权限)
	app.get('/api/auth/menus/all', fn [auth_manager] (mut c Context) http.Response {
		menus := auth_manager.get_all_menu_items() or {
			c.status(500)
			return c.json(json.encode({
				'error': err.msg()
			}))
		}
		return c.json(json.encode({
			'menus': menus
		}))
	})
} 