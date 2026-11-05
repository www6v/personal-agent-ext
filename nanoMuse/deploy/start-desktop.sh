#!/bin/bash
# nanoMuse 桌面版启动脚本
# 桌面版使用 Electron + Python 后端

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANOMUSE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/nanoMuse-main"
DEPLOY_DIR="$SCRIPT_DIR"

echo "=== nanoMuse 桌面版启动 ==="
echo "nanoMuse 目录: $NANOMUSE_DIR"
echo ""

# 复制配置文件
echo "=== 复制配置文件 ==="
cp "$DEPLOY_DIR/config.toml" "$NANOMUSE_DIR/config/config.toml"
echo "✓ 配置文件已复制"

# 进入 nanoMuse 目录
cd "$NANOMUSE_DIR"

# 检查系统类型
OS="$(uname -s)"
case "$OS" in
    Linux*)
        echo "检测到 Linux 系统"
        DESKTOP_APP="harness/desktop"
        ;;
    Darwin*)
        echo "检测到 macOS 系统"
        DESKTOP_APP="harness/desktop"
        ;;
    MINGW*|CYGWIN*|MSYS*)
        echo "检测到 Windows 系统"
        DESKTOP_APP="harness/desktop"
        ;;
    *)
        echo "不支持的系统: $OS"
        exit 1
        ;;
esac

# 检查是否已安装桌面应用
DESKTOP_DIR="$NANOMUSE_DIR/$DESKTOP_APP"
if [ ! -d "$DESKTOP_DIR" ]; then
    echo ""
    echo "桌面应用源码目录不存在"
    echo "请从 GitHub Releases 下载桌面应用:"
    echo "https://github.com/nano-muse/nanoMuse/releases/latest"
    echo ""
    echo "或者使用网页版: bash $SCRIPT_DIR/deploy-web.sh"
    exit 1
fi

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 未安装"
    echo "请先安装 Node.js: https://nodejs.org/"
    exit 1
fi

echo "✓ Node.js 已安装: $(node --version)"

# 检查 pnpm
if ! command -v pnpm &> /dev/null; then
    echo "安装 pnpm..."
    npm install -g pnpm
fi

echo "✓ pnpm 已安装"

# 安装桌面应用依赖
echo ""
echo "=== 安装桌面应用依赖 ==="
cd "$DESKTOP_DIR"
pnpm install

# 启动桌面应用
echo ""
echo "=== 启动桌面应用 ==="
pnpm dev

echo ""
echo "桌面应用已启动!"
echo "配置文件: $NANOMUSE_DIR/config/config.toml"
echo "使用 Qwen API"
