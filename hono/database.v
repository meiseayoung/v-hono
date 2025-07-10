module hono

import db.sqlite
import time
import crypto.rand

// 文件信息结构
pub struct FileInfo {
pub:
	file_uuid    string
	file_hash    string
	file_name    string
	file_size    int
	file_type    string
	created_at   int
	updated_at   int
}

// 数据库管理器
pub struct DatabaseManager {
mut:
	db sqlite.DB
}

// 创建数据库管理器
pub fn new_database_manager(db_path string) !DatabaseManager {
	mut db := sqlite.connect(db_path) or {
		return error('Failed to connect to database: $err')
	}
	
	// 创建文件信息表
	db.exec('CREATE TABLE IF NOT EXISTS file_info (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_uuid TEXT UNIQUE NOT NULL,
		file_hash TEXT NOT NULL,
		file_name TEXT NOT NULL,
		file_size INTEGER NOT NULL,
		file_type TEXT NOT NULL,
		created_at INTEGER NOT NULL,
		updated_at INTEGER NOT NULL
	);') or {
		return error('Failed to create table: $err')
	}
	db.exec('CREATE INDEX IF NOT EXISTS idx_file_hash ON file_info(file_hash);') or {
		return error('Failed to create index: $err')
	}
	db.exec('CREATE INDEX IF NOT EXISTS idx_file_uuid ON file_info(file_uuid);') or {
		return error('Failed to create index: $err')
	}
	
	return DatabaseManager{
		db: db
	}
}

// 生成文件UUID
pub fn generate_file_uuid() string {
	// 生成16字节的随机数据
	random_bytes := rand.bytes(16) or { return '' }
	
	// 转换为UUID格式 (8-4-4-4-12)
	mut uuid := ''
	for i, byte in random_bytes {
		if i == 4 || i == 6 || i == 8 || i == 10 {
			uuid += '-'
		}
		uuid += '${byte:02x}'
	}
	
	return uuid
}

// 插入或更新文件信息
pub fn (mut db DatabaseManager) insert_or_update_file(file_hash string, file_name string, file_size int, file_type string) !FileInfo {
	now := int(time.now().unix())
	
	// 检查是否已存在相同的file_hash
	existing_file := db.get_file_by_hash(file_hash) or { FileInfo{} }
	
	if existing_file.file_uuid != '' {
		// 如果存在相同的file_hash但文件名不同，创建新记录
		if existing_file.file_name != file_name {
			// 生成新的UUID
			file_uuid := generate_file_uuid()
			
			// 插入新记录
			db.db.exec('INSERT INTO file_info (file_uuid, file_hash, file_name, file_size, file_type, created_at, updated_at) VALUES ("$file_uuid", "$file_hash", "$file_name", $file_size, "$file_type", $now, $now)') or {
				return error('Failed to insert file info: $err')
			}
			
			return FileInfo{
				file_uuid: file_uuid
				file_hash: file_hash
				file_name: file_name
				file_size: file_size
				file_type: file_type
				created_at: now
				updated_at: now
			}
		} else {
			// 文件名相同，更新现有记录
			db.db.exec('UPDATE file_info SET file_size = $file_size, file_type = "$file_type", updated_at = $now WHERE file_hash = "$file_hash"') or {
				return error('Failed to update file info: $err')
			}
			
			return FileInfo{
				file_uuid: existing_file.file_uuid
				file_hash: file_hash
				file_name: file_name
				file_size: file_size
				file_type: file_type
				created_at: existing_file.created_at
				updated_at: now
			}
		}
	} else {
		// 不存在相同的file_hash，创建新记录
		file_uuid := generate_file_uuid()
		
		db.db.exec('INSERT INTO file_info (file_uuid, file_hash, file_name, file_size, file_type, created_at, updated_at) VALUES ("$file_uuid", "$file_hash", "$file_name", $file_size, "$file_type", $now, $now)') or {
			return error('Failed to insert file info: $err')
		}
		
		return FileInfo{
			file_uuid: file_uuid
			file_hash: file_hash
			file_name: file_name
			file_size: file_size
			file_type: file_type
			created_at: now
			updated_at: now
		}
	}
}

// 根据文件hash获取文件信息
pub fn (db DatabaseManager) get_file_by_hash(file_hash string) !FileInfo {
	rows := db.db.exec('SELECT file_uuid, file_hash, file_name, file_size, file_type, created_at, updated_at FROM file_info WHERE file_hash = "$file_hash"') or {
		return error('Failed to query file info: $err')
	}
	
	if rows.len > 0 {
		row := rows[0]
		return FileInfo{
			file_uuid: row.vals[0]
			file_hash: row.vals[1]
			file_name: row.vals[2]
			file_size: row.vals[3].int()
			file_type: row.vals[4]
			created_at: row.vals[5].int()
			updated_at: row.vals[6].int()
		}
	}
	
	return error('File not found')
}

// 根据文件UUID获取文件信息
pub fn (db DatabaseManager) get_file_by_uuid(file_uuid string) !FileInfo {
	rows := db.db.exec('SELECT file_uuid, file_hash, file_name, file_size, file_type, created_at, updated_at FROM file_info WHERE file_uuid = "$file_uuid"') or {
		return error('Failed to query file info: $err')
	}
	
	if rows.len > 0 {
		row := rows[0]
		return FileInfo{
			file_uuid: row.vals[0]
			file_hash: row.vals[1]
			file_name: row.vals[2]
			file_size: row.vals[3].int()
			file_type: row.vals[4]
			created_at: row.vals[5].int()
			updated_at: row.vals[6].int()
		}
	}
	
	return error('File not found')
}

// 获取所有文件信息
pub fn (db DatabaseManager) get_all_files() ![]FileInfo {
	rows := db.db.exec('SELECT file_uuid, file_hash, file_name, file_size, file_type, created_at, updated_at FROM file_info ORDER BY created_at DESC') or {
		return error('Failed to query all files: $err')
	}
	
	mut files := []FileInfo{}
	for row in rows {
		files << FileInfo{
			file_uuid: row.vals[0]
			file_hash: row.vals[1]
			file_name: row.vals[2]
			file_size: row.vals[3].int()
			file_type: row.vals[4]
			created_at: row.vals[5].int()
			updated_at: row.vals[6].int()
		}
	}
	
	return files
}

// 删除文件信息
pub fn (mut db DatabaseManager) delete_file(file_uuid string) ! {
	db.db.exec('DELETE FROM file_info WHERE file_uuid = "$file_uuid"') or {
		return error('Failed to delete file info: $err')
	}
}

// 关闭数据库连接
pub fn (mut db DatabaseManager) close() {
	db.db.close() or { }
} 