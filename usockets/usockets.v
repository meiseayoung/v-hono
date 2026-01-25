module usockets

// 条件编译：根据操作系统选择正确的路径和库
// @VMODROOT 指向包含 v.mod 的模块根目录 (v-hono/)
// 预编译库按平台存放在 usockets/lib/{platform}/ 目录

$if windows {
	#flag -DLIBUS_USE_LIBUV
	#flag -DLIBUS_NO_SSL
	#flag -I@VMODROOT/usockets/include
	#flag -L@VMODROOT/usockets/lib/windows
	#flag @VMODROOT/usockets/lib/windows/libusockets_full.a
	#flag -lws2_32 -liphlpapi -lpsapi -luserenv -lole32 -ldbghelp
} $else $if macos {
	#flag -DLIBUS_USE_LIBUV
	#flag -DLIBUS_NO_SSL
	#flag -I@VMODROOT/usockets/include
	
	$if arm64 {
		// Apple Silicon (M1/M2/M3)
		#flag -L@VMODROOT/usockets/lib/macos-arm64
		#flag @VMODROOT/usockets/lib/macos-arm64/libusockets_full.a
	} $else {
		// Intel Mac
		#flag -L@VMODROOT/usockets/lib/macos-x64
		#flag @VMODROOT/usockets/lib/macos-x64/libusockets_full.a
	}
} $else {
	// Linux 和其他平台
	#flag -DLIBUS_USE_LIBUV
	#flag -DLIBUS_NO_SSL
	#flag -I@VMODROOT/usockets/include
	#flag -L@VMODROOT/usockets/lib/linux
	#flag @VMODROOT/usockets/lib/linux/libusockets_full.a
}

#include "libusockets.h"

pub type Loop = &C.us_loop_t
pub type SocketContext = &C.us_socket_context_t
pub type Socket = &C.us_socket_t
pub type ListenSocket = &C.us_listen_socket_t

struct C.us_loop_t {}
struct C.us_socket_context_t {}
struct C.us_socket_t {}
struct C.us_listen_socket_t {}

struct C.us_socket_context_options_t {
	key_file_name         voidptr
	cert_file_name        voidptr
	passphrase            voidptr
	dh_params_file_name   voidptr
	ca_file_name          voidptr
	ssl_ciphers           voidptr
	ssl_prefer_low_memory_usage int
}

fn C.us_create_loop(hint voidptr, wakeup_cb voidptr, pre_cb voidptr, post_cb voidptr, ext_size u32) Loop
fn C.us_loop_free(loop Loop)
fn C.us_loop_run(loop Loop)

fn C.us_create_socket_context(ssl int, loop Loop, ext_size int, options C.us_socket_context_options_t) SocketContext
fn C.us_socket_context_free(ssl int, context SocketContext)
fn C.us_socket_context_on_open(ssl int, context SocketContext, on_open voidptr)
fn C.us_socket_context_on_close(ssl int, context SocketContext, on_close voidptr)
fn C.us_socket_context_on_data(ssl int, context SocketContext, on_data voidptr)
fn C.us_socket_context_on_writable(ssl int, context SocketContext, on_writable voidptr)
fn C.us_socket_context_on_timeout(ssl int, context SocketContext, on_timeout voidptr)
fn C.us_socket_context_on_end(ssl int, context SocketContext, on_end voidptr)
fn C.us_socket_context_listen(ssl int, context SocketContext, host voidptr, port int, options int, socket_ext_size int) ListenSocket
fn C.us_socket_context_ext(ssl int, context SocketContext) voidptr

fn C.us_socket_write(ssl int, socket Socket, data &char, length int, msg_more int) int
fn C.us_socket_shutdown(ssl int, socket Socket)
fn C.us_socket_close(ssl int, socket Socket, code int, reason voidptr) Socket
fn C.us_socket_context(ssl int, socket Socket) SocketContext
fn C.us_socket_ext(ssl int, socket Socket) voidptr

fn C.us_listen_socket_close(ssl int, ls ListenSocket)

fn empty_wakeup(loop Loop) {}
fn empty_pre(loop Loop) {}
fn empty_post(loop Loop) {}

pub fn create_loop() Loop {
	return C.us_create_loop(unsafe { nil }, empty_wakeup, empty_pre, empty_post, 0)
}

pub fn (l Loop) run() { C.us_loop_run(l) }
pub fn (l Loop) free() { C.us_loop_free(l) }

pub fn create_socket_context(loop Loop) SocketContext {
	options := C.us_socket_context_options_t{}
	return C.us_create_socket_context(0, loop, 0, options)
}

// 创建带扩展数据的 socket context
pub fn create_socket_context_with_ext(loop Loop, ext_size int) SocketContext {
	options := C.us_socket_context_options_t{}
	return C.us_create_socket_context(0, loop, ext_size, options)
}

pub fn (ctx SocketContext) free() { C.us_socket_context_free(0, ctx) }
pub fn (ctx SocketContext) on_open(h voidptr) { C.us_socket_context_on_open(0, ctx, h) }
pub fn (ctx SocketContext) on_close(h voidptr) { C.us_socket_context_on_close(0, ctx, h) }
pub fn (ctx SocketContext) on_data(h voidptr) { C.us_socket_context_on_data(0, ctx, h) }
pub fn (ctx SocketContext) on_writable(h voidptr) { C.us_socket_context_on_writable(0, ctx, h) }
pub fn (ctx SocketContext) on_timeout(h voidptr) { C.us_socket_context_on_timeout(0, ctx, h) }
pub fn (ctx SocketContext) on_end(h voidptr) { C.us_socket_context_on_end(0, ctx, h) }
pub fn (ctx SocketContext) listen(port int) ListenSocket {
	return C.us_socket_context_listen(0, ctx, unsafe { nil }, port, 0, 0)
}
// 获取 context 的扩展数据指针
pub fn (ctx SocketContext) ext() voidptr {
	return C.us_socket_context_ext(0, ctx)
}

pub fn (s Socket) write_bytes(data string) int { return C.us_socket_write(0, s, data.str, data.len, 0) }
pub fn (s Socket) shutdown() { C.us_socket_shutdown(0, s) }
pub fn (s Socket) close() Socket { return C.us_socket_close(0, s, 0, unsafe { nil }) }
// 获取 socket 所属的 context
pub fn (s Socket) context() SocketContext { return C.us_socket_context(0, s) }
// 获取 socket 的扩展数据指针
pub fn (s Socket) ext() voidptr { return C.us_socket_ext(0, s) }

pub fn (ls ListenSocket) close() { C.us_listen_socket_close(0, ls) }
pub fn (ls ListenSocket) is_valid() bool { return ls != unsafe { nil } }
