#!/bin/bash
# uSockets 编译脚本
# 用于重新编译 libusockets_full.a

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USOCKETS_DIR="/tmp/uSockets"

echo "=== uSockets 编译脚本 ==="

# 检查是否有 uSockets 源码
if [ ! -d "$USOCKETS_DIR" ]; then
    echo "克隆 uSockets..."
    git clone --depth 1 https://github.com/uNetworking/uSockets.git "$USOCKETS_DIR"
fi

# 应用 backlog 修改
echo "应用 backlog=16384 修改..."
if [ -f "$SCRIPT_DIR/src/bsd.c" ]; then
    cp "$SCRIPT_DIR/src/bsd.c" "$USOCKETS_DIR/src/bsd.c"
else
    # 如果没有本地修改的源码，直接修改
    sed -i.bak 's/listen(listenFd, 512)/listen(listenFd, 16384)/g' "$USOCKETS_DIR/src/bsd.c"
fi

# 编译
echo "编译 uSockets..."
cd "$USOCKETS_DIR"
make clean

# 根据系统选择编译参数
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if [[ $(uname -m) == "arm64" ]]; then
        # Apple Silicon
        WITH_LIBUV=1 CFLAGS="-I/opt/homebrew/include" make
    else
        # Intel Mac
        WITH_LIBUV=1 CFLAGS="-I/usr/local/include" make
    fi
else
    # Linux
    WITH_LIBUV=1 make
fi

# 复制到 v-hono
echo "复制库文件..."
cp "$USOCKETS_DIR/uSockets.a" "$SCRIPT_DIR/../lib/libusockets_full.a"

echo "=== 编译完成 ==="
echo "库文件: $SCRIPT_DIR/../lib/libusockets_full.a"
echo ""
echo "重新编译 v-hono 应用:"
echo "  v -enable-globals -prod -o your_app your_app.v"
