#!/bin/bash
# nanoMuse 停止脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANOMUSE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/nanoMuse-main"

echo "=== 停止 nanoMuse 服务 ==="

# 检查是否在 nanoMuse 目录
if [ ! -d "$NANOMUSE_DIR" ]; then
    echo "错误: 找不到 nanoMuse 目录"
    exit 1
fi

cd "$NANOMUSE_DIR"

# 停止 Docker 服务
if docker compose ps 2>/dev/null | grep -q "Up"; then
    echo "停止 Docker 服务..."
    docker compose stop
    echo "✓ Docker 服务已停止"
else
    echo "Docker 服务未运行"
fi

# 停止本地进程
echo ""
echo "检查本地进程..."
if pgrep -f "nanomuse serve" > /dev/null; then
    echo "停止 nanomuse serve 进程..."
    pkill -f "nanomuse serve"
    echo "✓ 本地服务已停止"
else
    echo "本地服务未运行"
fi

echo ""
echo "=== 完成 ==="
