module main

import hono
import net.http
import os
import json

fn main() {
	mut app := hono.Hono.new()

	// 创建分片上传管理器
	mut upload_manager := hono.new_chunk_upload_manager(hono.ChunkUploadConfig{})

	// 分片上传接口
	app.post('/upload/chunk', fn [mut upload_manager] (mut c hono.Context) http.Response {
		return upload_manager.handle_chunk_upload(mut c)
	})


	// 查询上传状态接口
	app.get('/upload/status', fn [mut upload_manager] (mut c hono.Context) http.Response {
		return upload_manager.get_upload_status(mut c)
	})

	// 查询已上传分片接口
	app.get('/upload/chunks', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_hash := c.query['file_hash'] or {
			c.status(400)
			return c.json('{"error": "Missing file_hash parameter"}')
		}
		upload_status := upload_manager.uploads[file_hash] or {
			// 如果内存中没有记录，检查是否有最终文件（已完成上传）
			final_path := './uploads/${file_hash.trim_space()}'
			if os.exists(final_path) {
				// 文件已存在，返回所有分片已上传
				mut uploaded_chunks := []int{}
				uploaded_chunks << 0 // 假设只有一个分片
				return c.json('{"uploaded_chunks": ' + json.encode(uploaded_chunks) + ', "total_chunks": 1, "completed": true}')
			}
			c.status(404)
			return c.json('{"error": "Upload not found"}')
		}
		
		// 检查是否所有分片都已上传（基于分片大小总和）
		chunk_dir := os.join_path(os.join_path('./uploads/chunks', file_hash.trim_space()), upload_status.chunk_size.str())
		mut total_chunk_size := u64(0)
		mut chunk_count := 0
		
		if os.exists(chunk_dir) {
			for i := 0; ; i++ {
				chunk_path := os.join_path(chunk_dir, 'chunk_${i}.part')
				if !os.exists(chunk_path) {
					break
				}
				chunk_info := os.stat(chunk_path) or { continue }
				total_chunk_size += chunk_info.size
				chunk_count++
			}
		}
		
		is_completed := total_chunk_size >= u64(upload_status.file_size)
		
		return c.json('{"uploaded_chunks": ' + json.encode(upload_status.uploaded_chunks) + ', "total_chunks": $chunk_count, "completed": $is_completed}')
	})

	// 检查分片是否存在接口（秒传功能）
	app.get('/upload/chunk_exists', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_hash := c.query['file_hash'] or {
			c.status(400)
			return c.json('{"error": "Missing file_hash parameter"}')
		}
		chunk_index := c.query['chunk_index'] or {
			c.status(400)
			return c.json('{"error": "Missing chunk_index parameter"}')
		}
		chunk_hash := c.query['chunk_hash'] or {
			c.status(400)
			return c.json('{"error": "Missing chunk_hash parameter"}')
		}
		file_size_str := c.query['file_size'] or {
			c.status(400)
			return c.json('{"error": "Missing file_size parameter"}')
		}
		file_size := file_size_str.int()

		// 新增 trunk_size 参数
		trunk_size_str := c.query['trunk_size'] or { '' }
		mut chunk_size := upload_manager.config.chunk_size
		if trunk_size_str != '' {
			chunk_size = trunk_size_str.int()
		} else if upload_status := upload_manager.uploads[file_hash] {
			chunk_size = upload_status.chunk_size
		}

		chunk_path := os.join_path(os.join_path(os.join_path('./uploads/chunks', file_hash.trim_space()), chunk_size.str()), 'chunk_${chunk_index}.part')
		println('[DEBUG] Checking chunk: $chunk_path')
		println('[DEBUG] File hash: $file_hash')
		println('[DEBUG] Chunk index: $chunk_index')
		println('[DEBUG] Expected hash: $chunk_hash')
		
		// 清理无效的上传状态
		upload_manager.cleanup_invalid_status()
		
		mut exists := os.exists(chunk_path)
		println('[DEBUG] File exists: $exists')
		
		// 计算是否所有分片都已上传
		mut all_chunk_uploaded := false
		
		// 方案1：优先检查最终文件是否存在（新格式：filehash.filetype）
		uploads_dir := './uploads/files'
		if os.exists(uploads_dir) {
			// 从上传状态中获取文件扩展名
			mut file_ext := ''
			if upload_status := upload_manager.uploads[file_hash] {
				file_ext = get_file_extension(upload_status.filename)
			}
			
			// 如果内存中没有记录，尝试从数据库获取
			if file_ext == '' {
				if file_info := upload_manager.db.get_file_by_hash(file_hash) {
					file_ext = file_info.file_type
				}
			}
			
			// 构建最终文件名
			final_filename := '${file_hash.trim_space()}${file_ext}'
			final_path := os.join_path(uploads_dir, final_filename)
			
			if os.exists(final_path) {
				println('[DEBUG] Found final file: $final_path')
				all_chunk_uploaded = true
			}
		}
		
		// 方案2：如果最终文件不存在，检查分片文件
		if !all_chunk_uploaded {
			chunk_dir := os.join_path(os.join_path('./uploads/chunks', file_hash.trim_space()), chunk_size.str())
			if os.exists(chunk_dir) {
				// 计算所有分片文件的大小总和
				mut total_chunk_size := u64(0)
				mut chunk_count := 0
				// 遍历所有分片文件
				for i := 0; ; i++ {
					chunk_file_path := '${chunk_dir}/chunk_${i}.part'
					if !os.exists(chunk_file_path) {
						break
					}
					// 获取分片文件大小
					chunk_info := os.stat(chunk_file_path) or { break }
					total_chunk_size += chunk_info.size
					chunk_count++
				}
				// 使用传入的文件大小
				expected_file_size := u64(file_size)
				println('[DEBUG] Total chunk size: $total_chunk_size, Expected file size: $expected_file_size, Chunk count: $chunk_count')
				
				// 计算理论上需要的分片数量
				expected_chunks := (expected_file_size + u64(chunk_size) - 1) / u64(chunk_size)
				println('[DEBUG] Expected chunks: $expected_chunks')
				
				// 只有当分片数量达到预期且总大小 >= 文件大小时，才认为上传完成
				if chunk_count >= int(expected_chunks) && total_chunk_size >= expected_file_size {
					all_chunk_uploaded = true
					println('[DEBUG] All chunks uploaded: chunk_count=$chunk_count >= expected_chunks=$expected_chunks && total_size=$total_chunk_size >= file_size=$expected_file_size')
				} else {
					println('[DEBUG] Not all chunks uploaded: chunk_count=$chunk_count < expected_chunks=$expected_chunks || total_size=$total_chunk_size < file_size=$expected_file_size')
				}
			}
		}
		
		println('[DEBUG] All chunk uploaded: $all_chunk_uploaded')
		
		// chunk_exists 接口不应该自动触发合并，只返回状态信息
		// 合并操作应该在 /upload/chunk 接口中处理
		
		// 只检查文件是否存在，不验证 hash（因为前后端 hash 算法可能不一致）
		// 如果需要严格验证，可以在这里添加 hash 检查逻辑
		
		return c.json('{"exists": $exists, "all_chunk_uploaded": $all_chunk_uploaded}')
	})

	// 获取所有文件信息
	app.get('/api/files', fn [mut upload_manager] (mut c hono.Context) http.Response {
		files := upload_manager.db.get_all_files() or {
			c.status(500)
			return c.json('{"error": "Failed to get files", "message": "$err"}')
		}
		return c.json(json.encode(files))
	})

	// 根据文件UUID获取文件信息
	app.get('/api/files/:uuid', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_uuid := c.params['uuid'] or {
			c.status(400)
			return c.json('{"error": "Missing file UUID"}')
		}
		
		file_info := upload_manager.db.get_file_by_uuid(file_uuid) or {
			c.status(404)
			return c.json('{"error": "File not found"}')
		}
		
		return c.json(json.encode(file_info))
	})

	// 根据文件hash获取文件信息
	app.get('/api/files/hash/:hash', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_hash := c.params['hash'] or {
			c.status(400)
			return c.json('{"error": "Missing file hash"}')
		}
		
		file_info := upload_manager.db.get_file_by_hash(file_hash) or {
			c.status(404)
			return c.json('{"error": "File not found"}')
		}
		
		return c.json(json.encode(file_info))
	})

	// 删除文件信息
	app.delete('/api/files/:uuid', fn [mut upload_manager] (mut c hono.Context) http.Response {
		file_uuid := c.params['uuid'] or {
			c.status(400)
			return c.json('{"error": "Missing file UUID"}')
		}
		
		upload_manager.db.delete_file(file_uuid) or {
			c.status(500)
			return c.json('{"error": "Failed to delete file", "message": "$err"}')
		}
		
		return c.json('{"success": true, "message": "File deleted successfully"}')
	})

	// 静态文件服务
	app.use(hono.serve_static_path('/files', './uploads'))

	// HTML 示例页面
	app.get('/', fn (mut c hono.Context) http.Response {
		html_content := os.read_file('public/upload.html') or {
			return c.text('Error: Cannot read upload.html file')
		}
		return c.html(html_content)
	})

	println('Chunk upload server running at http://localhost:8080')
	app.listen(':8080')
}

// 获取文件扩展名
fn get_file_extension(filename string) string {
	println('[DEBUG] Getting extension for filename: "$filename"')
	parts := filename.split('.')
	println('[DEBUG] Split parts: $parts')
	if parts.len > 1 {
		ext := '.${parts.last()}'
		println('[DEBUG] Extracted extension: "$ext"')
		return ext
	}
	println('[DEBUG] No extension found, returning empty string')
	return ''
} 