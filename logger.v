module hono

import os
import time
import x.json2

// 日志级别枚举
pub enum LogLevel {
	debug = 0
	info  = 1
	warn  = 2
	error = 3
}

// 日志级别字符串映射
const log_level_strings = {
	LogLevel.debug: 'DEBUG'
	LogLevel.info:  'INFO'
	LogLevel.warn:  'WARN'
	LogLevel.error: 'ERROR'
}

// 日志输出类型
pub enum LogOutput {
	console
	file
	both
}

// 日志条目结构
pub struct LogEntry {
pub mut:
	timestamp string
	level     string
	message   string
	module    string
	function  string
	file      string
	line      int
	fields    map[string]string
	request_id string
}

// 日志配置
pub struct LoggerConfig {
pub mut:
	level            LogLevel = LogLevel.info
	output           LogOutput = LogOutput.console
	file_path        string = './logs/app.log'
	max_file_size    u64 = 10 * 1024 * 1024  // 10MB
	max_backup_files int = 5
	enable_colors    bool = true
	enable_json      bool
	time_format      string = '2006-01-02 15:04:05'
}

// 日志器结构
pub struct Logger {
pub mut:
	config LoggerConfig
	current_file_size u64
}

// 创建新的日志器实例
pub fn new_logger(config LoggerConfig) &Logger {
	return &Logger{
		config: config
	}
}

// 字符串转日志级别
pub fn parse_log_level(level_str string) LogLevel {
	match level_str.to_lower() {
		'debug' { return LogLevel.debug }
		'info' { return LogLevel.info }
		'warn' { return LogLevel.warn }
		'error' { return LogLevel.error }
		else { return LogLevel.info }
	}
}

// 日志级别转字符串
pub fn log_level_to_string(level LogLevel) string {
	return log_level_strings[level] or { 'INFO' }
}

// 检查日志级别是否应该输出
fn (l &Logger) should_log(level LogLevel) bool {
	return int(level) >= int(l.config.level)
}

// 格式化时间戳
fn format_timestamp() string {
	now := time.now()
	return now.format_ss()
}

// 获取ANSI颜色代码
fn get_color_code(level LogLevel) string {
	match level {
		.debug { return '\033[36m' }  // 青色
		.info { return '\033[32m' }   // 绿色
		.warn { return '\033[33m' }   // 黄色
		.error { return '\033[31m' }  // 红色
	}
}

// 重置ANSI颜色
const color_reset = '\033[0m'

// 格式化日志消息（文本格式）
fn (l &Logger) format_text_log(entry LogEntry) string {
	mut parts := []string{}
	
	// 时间戳
	parts << '[${entry.timestamp}]'
	
	// 日志级别（带颜色）
	if l.config.enable_colors {
		color := get_color_code(parse_log_level(entry.level))
		parts << '${color}${entry.level}${color_reset}'
	} else {
		parts << entry.level
	}
	
	// 模块信息
	if entry.module != '' {
		parts << '[${entry.module}]'
	}
	
	// 消息
	parts << entry.message
	
	// 附加字段
	if entry.fields.len > 0 {
		mut field_parts := []string{}
		for key, value in entry.fields {
			field_parts << '${key}=${value}'
		}
		parts << '{${field_parts.join(', ')}}'
	}
	
	// 请求ID
	if entry.request_id != '' {
		parts << '[req:${entry.request_id}]'
	}
	
	return parts.join(' ')
}

// 格式化日志消息（JSON格式）
fn (l &Logger) format_json_log(entry LogEntry) string {
	return json2.encode[LogEntry](entry)
}

// 写入日志到文件
fn (mut l Logger) write_to_file(content string) {
	// 确保日志目录存在
	log_dir := os.dir(l.config.file_path)
	if !os.exists(log_dir) {
		os.mkdir_all(log_dir) or {
			eprintln('无法创建日志目录: ${err}')
			return
		}
	}
	
	// 检查文件大小，必要时轮转
	if l.config.max_file_size > 0 {
		if os.exists(l.config.file_path) {
			file_size := os.file_size(l.config.file_path)
			if file_size >= l.config.max_file_size {
				l.rotate_log_file()
			}
		}
	}
	
	// 写入日志
	mut file := os.open_append(l.config.file_path) or {
		eprintln('无法打开日志文件: ${err}')
		return
	}
	defer {
		file.close()
	}
	
	file.writeln(content) or {
		eprintln('无法写入日志文件: ${err}')
	}
}

// 轮转日志文件
fn (l &Logger) rotate_log_file() {
	// 删除最旧的备份文件
	oldest_backup := '${l.config.file_path}.${l.config.max_backup_files}'
	if os.exists(oldest_backup) {
		os.rm(oldest_backup) or {}
	}
	
	// 移动现有备份文件
	for i := l.config.max_backup_files - 1; i >= 1; i-- {
		old_file := '${l.config.file_path}.${i}'
		new_file := '${l.config.file_path}.${i + 1}'
		if os.exists(old_file) {
			os.mv(old_file, new_file) or {}
		}
	}
	
	// 移动当前日志文件为第一个备份
	if os.exists(l.config.file_path) {
		backup_file := '${l.config.file_path}.1'
		os.mv(l.config.file_path, backup_file) or {}
	}
}

// 核心日志方法
fn (mut l Logger) log(level LogLevel, message string, mod_name string, fields map[string]string, request_id string) {
	if !l.should_log(level) {
		return
	}
	
	entry := LogEntry{
		timestamp: format_timestamp()
		level: log_level_to_string(level)
		message: message
		module: mod_name
		fields: fields
		request_id: request_id
	}
	
	// 格式化日志内容
	content := if l.config.enable_json {
		l.format_json_log(entry)
	} else {
		l.format_text_log(entry)
	}
	
	// 输出日志
	match l.config.output {
		.console {
			println(content)
		}
		.file {
			l.write_to_file(content)
		}
		.both {
			println(content)
			l.write_to_file(content)
		}
	}
}

// 公共日志方法
pub fn (mut l Logger) debug(message string) {
	l.log(LogLevel.debug, message, '', {}, '')
}

pub fn (mut l Logger) info(message string) {
	l.log(LogLevel.info, message, '', {}, '')
}

pub fn (mut l Logger) warn(message string) {
	l.log(LogLevel.warn, message, '', {}, '')
}

pub fn (mut l Logger) error(message string) {
	l.log(LogLevel.error, message, '', {}, '')
}

// 带模块的日志方法
pub fn (mut l Logger) debug_with_module(message string, mod_name string) {
	l.log(LogLevel.debug, message, mod_name, {}, '')
}

pub fn (mut l Logger) info_with_module(message string, mod_name string) {
	l.log(LogLevel.info, message, mod_name, {}, '')
}

pub fn (mut l Logger) warn_with_module(message string, mod_name string) {
	l.log(LogLevel.warn, message, mod_name, {}, '')
}

pub fn (mut l Logger) error_with_module(message string, mod_name string) {
	l.log(LogLevel.error, message, mod_name, {}, '')
}

// 带字段的日志方法
pub fn (mut l Logger) debug_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.debug, message, '', fields, '')
}

pub fn (mut l Logger) info_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.info, message, '', fields, '')
}

pub fn (mut l Logger) warn_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.warn, message, '', fields, '')
}

pub fn (mut l Logger) error_with_fields(message string, fields map[string]string) {
	l.log(LogLevel.error, message, '', fields, '')
}

// 带请求ID的日志方法
pub fn (mut l Logger) debug_with_request(message string, request_id string) {
	l.log(LogLevel.debug, message, '', {}, request_id)
}

pub fn (mut l Logger) info_with_request(message string, request_id string) {
	l.log(LogLevel.info, message, '', {}, request_id)
}

pub fn (mut l Logger) warn_with_request(message string, request_id string) {
	l.log(LogLevel.warn, message, '', {}, request_id)
}

pub fn (mut l Logger) error_with_request(message string, request_id string) {
	l.log(LogLevel.error, message, '', {}, request_id)
}

// 完整的日志方法
pub fn (mut l Logger) log_full(level LogLevel, message string, mod_name string, fields map[string]string, request_id string) {
	l.log(level, message, mod_name, fields, request_id)
}

// HTTP请求日志结构
pub struct RequestLog {
pub mut:
	method        string
	path          string
	status_code   int
	response_time f64  // 毫秒
	user_agent    string
	remote_addr   string
	request_size  u64
	response_size u64
	request_id    string
}

// 记录HTTP请求日志
pub fn log_request(mut logger Logger, req_log RequestLog) {
	fields := {
		'method': req_log.method
		'path': req_log.path
		'status': req_log.status_code.str()
		'response_time': '${req_log.response_time:.2f}ms'
		'user_agent': req_log.user_agent
		'remote_addr': req_log.remote_addr
		'request_size': req_log.request_size.str()
		'response_size': req_log.response_size.str()
	}
	
	message := '${req_log.method} ${req_log.path} ${req_log.status_code} ${req_log.response_time:.2f}ms'
	logger.log_full(LogLevel.info, message, 'HTTP', fields, req_log.request_id)
}

// 性能监控日志
pub fn log_performance(mut logger Logger, operation string, duration f64, details map[string]string) {
	mut fields := {
		'operation': operation
		'duration': '${duration:.2f}ms'
	}
	
	// 合并详细信息
	for key, value in details {
		fields[key] = value
	}
	
	message := '性能监控: ${operation} 耗时 ${duration:.2f}ms'
	logger.log_full(LogLevel.info, message, 'PERF', fields, '')
}

// 错误日志（带堆栈信息）
pub fn log_error_with_stack(mut logger Logger, message string, err_details string, mod_name string) {
	fields := {
		'error_details': err_details
		'stack_trace': 'V语言暂不支持堆栈跟踪'
	}
	
	logger.log_full(LogLevel.error, message, mod_name, fields, '')
}