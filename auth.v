module hono

import crypto.sha256
import crypto.rand
import time
import json

// 用户角色枚举
pub enum UserRole {
	admin
	manager
	user
	guest
}

// 用户结构
pub struct User {
pub:
	id          int
	username    string
	email       string
	password_hash string
	role        UserRole
	status      bool // true: active, false: inactive
	created_at  int
	updated_at  int
}

// 菜单项结构
pub struct MenuItem {
pub:
	id          int
	name        string
	path        string
	icon        string
	parent_id   int
	sort_order  int
	permissions []string
	status      bool
	created_at  int
	updated_at  int
mut:
	children    []MenuItem
}

// 用户会话结构
pub struct UserSession {
pub:
	user_id     int
	token       string
	expires_at  int
	created_at  int
}

// 认证管理器
pub struct AuthManager {
mut:
	db DatabaseManager
}

// 创建认证管理器
pub fn new_auth_manager(db DatabaseManager) AuthManager {
	return AuthManager{
		db: db
	}
}

// 初始化认证相关表
pub fn (mut auth AuthManager) init_tables() ! {
	// 创建用户表
	auth.db.db.exec('CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		email TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		role TEXT NOT NULL,
		status BOOLEAN DEFAULT 1,
		created_at INTEGER NOT NULL,
		updated_at INTEGER NOT NULL
	);') or {
		return error('Failed to create users table: $err')
	}

	// 创建菜单表
	auth.db.db.exec('CREATE TABLE IF NOT EXISTS menu_items (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		path TEXT NOT NULL,
		icon TEXT,
		parent_id INTEGER DEFAULT 0,
		sort_order INTEGER DEFAULT 0,
		permissions TEXT,
		status BOOLEAN DEFAULT 1,
		created_at INTEGER NOT NULL,
		updated_at INTEGER NOT NULL
	);') or {
		return error('Failed to create menu_items table: $err')
	}

	// 创建用户会话表
	auth.db.db.exec('CREATE TABLE IF NOT EXISTS user_sessions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		token TEXT UNIQUE NOT NULL,
		expires_at INTEGER NOT NULL,
		created_at INTEGER NOT NULL,
		FOREIGN KEY (user_id) REFERENCES users (id)
	);') or {
		return error('Failed to create user_sessions table: $err')
	}

	// 创建索引
	auth.db.db.exec('CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);') or {
		return error('Failed to create index: $err')
	}
	auth.db.db.exec('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);') or {
		return error('Failed to create index: $err')
	}
	auth.db.db.exec('CREATE INDEX IF NOT EXISTS idx_menu_parent ON menu_items(parent_id);') or {
		return error('Failed to create index: $err')
	}
	auth.db.db.exec('CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions(token);') or {
		return error('Failed to create index: $err')
	}
}

// 密码哈希
fn hash_password(password string) string {
	return sha256.sum(password.bytes()).hex()
}

// 生成随机令牌
fn generate_token() string {
	random_bytes := rand.bytes(32) or { return '' }
	mut token := ''
	for byte in random_bytes {
		token += '${byte:02x}'
	}
	return token
}

// 创建用户
pub fn (mut auth AuthManager) create_user(username string, email string, password string, role UserRole) !User {
	now := int(time.now().unix())
	password_hash := hash_password(password)
	role_str := role.str()

	auth.db.db.exec('INSERT INTO users (username, email, password_hash, role, status, created_at, updated_at) VALUES ("$username", "$email", "$password_hash", "$role_str", 1, $now, $now)') or {
		return error('Failed to create user: $err')
	}

	// 获取插入的用户ID
	rows := auth.db.db.exec('SELECT last_insert_rowid()') or {
		return error('Failed to get user ID: $err')
	}
	user_id := rows[0].vals[0].int()

	return User{
		id: user_id
		username: username
		email: email
		password_hash: password_hash
		role: role
		status: true
		created_at: now
		updated_at: now
	}
}

// 用户登录
pub fn (mut auth AuthManager) login(username string, password string) !UserSession {
	password_hash := hash_password(password)
	
	rows := auth.db.db.exec('SELECT id, username, email, password_hash, role, status FROM users WHERE username = "$username" AND password_hash = "$password_hash" AND status = 1') or {
		return error('Failed to query user: $err')
	}

	if rows.len == 0 {
		return error('Invalid username or password')
	}

	user := rows[0]
	user_id := user.vals[0].int()

	// 生成会话令牌
	token := generate_token()
	now := int(time.now().unix())
	expires_at := now + (24 * 60 * 60) // 24小时后过期

	// 保存会话
	auth.db.db.exec('INSERT INTO user_sessions (user_id, token, expires_at, created_at) VALUES ($user_id, "$token", $expires_at, $now)') or {
		return error('Failed to create session: $err')
	}

	return UserSession{
		user_id: user_id
		token: token
		expires_at: expires_at
		created_at: now
	}
}

// 验证令牌
pub fn (auth AuthManager) verify_token(token string) !User {
	rows := auth.db.db.exec('SELECT u.id, u.username, u.email, u.password_hash, u.role, u.status FROM users u JOIN user_sessions s ON u.id = s.user_id WHERE s.token = "$token" AND s.expires_at > ${int(time.now().unix())} AND u.status = 1') or {
		return error('Failed to verify token: $err')
	}

	if rows.len == 0 {
		return error('Invalid or expired token')
	}

	user := rows[0]
	role_str := user.vals[4]
	role := match role_str {
		'admin' { UserRole.admin }
		'manager' { UserRole.manager }
		'user' { UserRole.user }
		'guest' { UserRole.guest }
		else { UserRole.guest }
	}

	return User{
		id: user.vals[0].int()
		username: user.vals[1]
		email: user.vals[2]
		password_hash: user.vals[3]
		role: role
		status: user.vals[5].int() == 1
		created_at: 0
		updated_at: 0
	}
}

// 注销会话
pub fn (mut auth AuthManager) logout(token string) ! {
	auth.db.db.exec('DELETE FROM user_sessions WHERE token = "$token"') or {
		return error('Failed to logout: $err')
	}
}

// 创建菜单项
pub fn (mut auth AuthManager) create_menu_item(name string, path string, icon string, parent_id int, sort_order int, permissions []string) !MenuItem {
	now := int(time.now().unix())
	permissions_json := json.encode(permissions)
	permissions_sql := permissions_json.replace('"', "''")

	auth.db.db.exec('INSERT INTO menu_items (name, path, icon, parent_id, sort_order, permissions, status, created_at, updated_at) VALUES ("$name", "$path", "$icon", $parent_id, $sort_order, "$permissions_sql", 1, $now, $now)')
	or {
		eprintln('菜单插入SQL错误: $err')
		return error('Failed to create menu item: $err')
	}

	// 获取插入的菜单ID
	rows := auth.db.db.exec('SELECT last_insert_rowid()') or {
		return error('Failed to get menu ID: $err')
	}
	menu_id := rows[0].vals[0].int()

	return MenuItem{
		id: menu_id
		name: name
		path: path
		icon: icon
		parent_id: parent_id
		sort_order: sort_order
		permissions: permissions
		status: true
		created_at: now
		updated_at: now
	}
}

// 获取所有菜单项
pub fn (auth AuthManager) get_all_menu_items() ![]MenuItem {
	rows := auth.db.db.exec('SELECT id, name, path, icon, parent_id, sort_order, permissions, status FROM menu_items ORDER BY parent_id, sort_order') or {
		return error('Failed to query all menu items: $err')
	}

	mut menus := []MenuItem{}
	for row in rows {
		permissions_str := row.vals[6]
		permissions := json.decode([]string, permissions_str) or { []string{} }

		menus << MenuItem{
			id: row.vals[0].int()
			name: row.vals[1]
			path: row.vals[2]
			icon: row.vals[3]
			parent_id: row.vals[4].int()
			sort_order: row.vals[5].int()
			permissions: permissions
			status: row.vals[7].int() == 1
			created_at: 0
			updated_at: 0
		}
	}

	return menus
}

// 获取用户菜单
pub fn (auth AuthManager) get_user_menus(user User) ![]MenuItem {
	// 根据用户角色获取菜单
	role_permissions := match user.role {
		.admin { ['*'] } // 管理员拥有所有权限
		.manager { ['read', 'write', 'manage'] }
		.user { ['read', 'write'] }
		.guest { ['read'] }
	}

	// 构建权限查询条件
	mut permission_conditions := []string{}
	for permission in role_permissions {
		if permission == '*' {
			permission_conditions << 'permissions LIKE "%*%"'
		} else {
			permission_conditions << 'permissions LIKE "%$permission%"'
		}
	}
	permission_where := permission_conditions.join(' OR ')

	rows := auth.db.db.exec('SELECT id, name, path, icon, parent_id, sort_order, permissions, status FROM menu_items WHERE status = 1 AND ($permission_where) ORDER BY parent_id, sort_order') or {
		return error('Failed to query menu items: $err')
	}

	mut menus := []MenuItem{}
	for row in rows {
		permissions_str := row.vals[6]
		permissions := json.decode([]string, permissions_str) or { []string{} }

		menus << MenuItem{
			id: row.vals[0].int()
			name: row.vals[1]
			path: row.vals[2]
			icon: row.vals[3]
			parent_id: row.vals[4].int()
			sort_order: row.vals[5].int()
			permissions: permissions
			status: row.vals[7].int() == 1
			created_at: 0
			updated_at: 0
		}
	}

	return menus
}

// 构建菜单树
pub fn (auth AuthManager) build_menu_tree(menus []MenuItem) []MenuItem {
	mut menu_map := map[int]MenuItem{}
	mut root_menus := []MenuItem{}

	// 创建菜单映射
	for menu in menus {
		menu_map[menu.id] = menu
	}

	// 构建树结构
	for menu in menus {
		if menu.parent_id == 0 {
			// 根菜单
			mut root_menu := menu
			root_menu.children = auth.get_children(menu.id, menu_map)
			root_menus << root_menu
		}
	}

	return root_menus
}

// 获取子菜单
fn (auth AuthManager) get_children(parent_id int, menu_map map[int]MenuItem) []MenuItem {
	mut children := []MenuItem{}
	
	for _, menu in menu_map {
		if menu.parent_id == parent_id {
			mut child := menu
			child.children = auth.get_children(menu.id, menu_map)
			children << child
		}
	}

	return children
}

// 检查用户权限
pub fn (auth AuthManager) check_permission(user User, required_permission string) bool {
	return match user.role {
		.admin { true } // 管理员拥有所有权限
		.manager { required_permission in ['read', 'write', 'manage'] }
		.user { required_permission in ['read', 'write'] }
		.guest { required_permission == 'read' }
	}
} 

// 获取菜单id（通过path）
pub fn (auth AuthManager) get_menu_id_by_path(path string) int {
	rows := auth.db.db.exec('SELECT id FROM menu_items WHERE path = "$path"') or { return 0 }
	if rows.len > 0 {
		return rows[0].vals[0].int()
	}
	return 0
} 