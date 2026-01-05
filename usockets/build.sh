#!/bin/bash
# uSockets 编译脚本
# 用于重新编译 libusockets_full.a (包含 uSockets + libuv)
# 支持: Windows (Git Bash/MSYS2), macOS (Intel/Apple Silicon), Linux
# 输出到: usockets/lib/{platform}/libusockets_full.a

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USOCKETS_DIR="/tmp/uSockets"
LIBUV_DIR="/tmp/libuv"
MERGE_DIR="/tmp/merge_libs"

echo "=== uSockets 编译脚本 ==="
echo "检测到系统: $OSTYPE"

# 确定输出目录
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
        OUTPUT_DIR="$SCRIPT_DIR/lib/macos-arm64"
    else
        OUTPUT_DIR="$SCRIPT_DIR/lib/macos-x64"
    fi
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/lib/windows"
elif [[ "$OSTYPE" == "linux"* ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/lib/linux"
else
    OUTPUT_DIR="$SCRIPT_DIR/lib/linux"
fi

echo "输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 检查是否有 uSockets 源码
if [ ! -d "$USOCKETS_DIR" ]; then
    echo "克隆 uSockets..."
    git clone --depth 1 https://github.com/uNetworking/uSockets.git "$USOCKETS_DIR"
fi

# 检查是否有 libuv 源码
if [ ! -d "$LIBUV_DIR" ]; then
    echo "克隆 libuv..."
    git clone --depth 1 --branch v1.48.0 https://github.com/libuv/libuv.git "$LIBUV_DIR"
fi

# 应用 backlog 修改
echo "应用 backlog=16384 修改..."
if [ -f "$SCRIPT_DIR/src/bsd.c" ]; then
    cp "$SCRIPT_DIR/src/bsd.c" "$USOCKETS_DIR/src/bsd.c"
else
    sed -i.bak 's/listen(listenFd, 512)/listen(listenFd, 16384)/g' "$USOCKETS_DIR/src/bsd.c"
fi

# 编译 libuv
compile_libuv() {
    echo "编译 libuv..."
    cd "$LIBUV_DIR"
    rm -rf build 2>/dev/null || true
    mkdir -p build
    cd build
    
    if ! command -v cmake &> /dev/null; then
        echo "错误: 需要安装 cmake"
        echo "  macOS: brew install cmake"
        echo "  Linux: sudo apt install cmake 或 sudo yum install cmake"
        echo "  Windows: scoop install cmake 或 choco install cmake"
        exit 1
    fi
    
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
        cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DLIBUV_BUILD_SHARED=OFF
    else
        cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DLIBUV_BUILD_SHARED=OFF
    fi
    
    cmake --build . --config Release
}

# 编译 uSockets
compile_usockets() {
    echo "编译 uSockets..."
    cd "$USOCKETS_DIR"
    rm -f *.o *.a 2>/dev/null || true
    
    gcc -DLIBUS_NO_SSL -DLIBUS_USE_LIBUV -std=c11 -Isrc -I"$LIBUV_DIR/include" -O3 -c src/*.c src/eventing/*.c src/crypto/*.c
    ar rcs uSockets.a *.o
    rm -f *.o
}

# 合并库文件
merge_libraries() {
    echo "合并库文件..."
    rm -rf "$MERGE_DIR"
    mkdir -p "$MERGE_DIR"
    
    cd "$MERGE_DIR"
    ar x "$USOCKETS_DIR/uSockets.a"
    ar x "$LIBUV_DIR/build/libuv.a"
    
    ar rcs "$OUTPUT_DIR/libusockets_full.a" *.o
    
    rm -rf "$MERGE_DIR"
}

# 执行编译
compile_libuv
compile_usockets
merge_libraries

# 显示结果
LIB_SIZE=$(ls -lh "$OUTPUT_DIR/libusockets_full.a" | awk '{print $5}')
echo ""
echo "=== 编译完成 ==="
echo "库文件: $OUTPUT_DIR/libusockets_full.a ($LIB_SIZE)"
echo ""
echo "编译 v-hono 应用:"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "mingw"* ]]; then
    echo "  v -enable-globals -cc gcc -ldflags \"-ldbghelp\" -o app.exe app.v"
else
    echo "  v -enable-globals -prod -o app app.v"
fi
