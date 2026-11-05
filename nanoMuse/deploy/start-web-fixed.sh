#!/bin/bash
# nanoMuse 网页版启动脚本 (修正版)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANOMUSE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/nanoMuse-main"
DEPLOY_DIR="$SCRIPT_DIR"

echo "=== nanoMuse 网页版启动 ==="
echo "nanoMuse 目录: $NANOMUSE_DIR"
echo ""

# 复制配置文件
echo "=== 复制配置文件 ==="
cp "$DEPLOY_DIR/config.toml" "$NANOMUSE_DIR/config/config.toml"
echo "✓ 配置文件已复制"

# 进入 nanoMuse 目录
cd "$NANOMUSE_DIR"

# 检查虚拟环境
if [ ! -d ".venv" ]; then
    echo ""
    echo "=== 创建虚拟环境 ==="
    uv venv .venv
    echo "✓ 虚拟环境已创建"
fi

# 激活虚拟环境
source .venv/bin/activate

# 检查依赖
if ! python -c "import nanomuse" 2>/dev/null; then
    echo ""
    echo "=== 安装依赖 ==="
    uv pip install -e . --index-url https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
    echo "✓ 依赖已安装"
fi

# 创建必要目录
mkdir -p workspace

# 设置环境变量
export NANOMUSE_SERVER_TOKEN=nanomuse-web-token-2026

# 启动服务
echo ""
echo "=== 启动 nanoMuse 服务 ==="
echo "🌐 网页版地址: http://localhost:8787"
echo "🔑 访问 Token: nanomuse-web-token-2026"
echo ""
echo "完整访问链接:"
echo "http://localhost:8787/#token=nanomuse-web-token-2026"
echo ""
echo "按 Ctrl+C 停止服务"
echo ""

# 启动 serve 命令
nanomuse serve --host 0.0.0.0 --port 8787 --no-qr
