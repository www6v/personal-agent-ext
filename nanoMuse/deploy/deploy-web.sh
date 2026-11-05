#!/bin/bash
# nanoMuse 网页版部署脚本
# 使用 Qwen API

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANOMUSE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/nanoMuse-main"
DEPLOY_DIR="$SCRIPT_DIR"

echo "=== nanoMuse 网页版部署 ==="
echo "部署目录: $DEPLOY_DIR"
echo "nanoMuse 源码: $NANOMUSE_DIR"
echo ""

# 检查 nanoMuse 目录
if [ ! -d "$NANOMUSE_DIR" ]; then
    echo "错误: 找不到 nanoMuse 源码目录: $NANOMUSE_DIR"
    exit 1
fi

# 复制配置文件到 nanoMuse 目录
echo "=== 复制配置文件 ==="
cp "$DEPLOY_DIR/config.toml" "$NANOMUSE_DIR/config/config.toml"
echo "✓ 配置文件已复制到 $NANOMUSE_DIR/config/config.toml"

cp "$DEPLOY_DIR/.env" "$NANOMUSE_DIR/.env"
echo "✓ 环境变量已复制到 $NANOMUSE_DIR/.env"

# 创建必要的目录
echo ""
echo "=== 创建目录 ==="
mkdir -p "$NANOMUSE_DIR/workspace"
echo "✓ workspace 目录已创建"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    echo "请先安装 Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "错误: Docker Compose 未安装"
    exit 1
fi

echo "✓ Docker 和 Docker Compose 已安装"

# 进入 nanoMuse 目录
cd "$NANOMUSE_DIR"

# 构建 Docker 镜像
echo ""
echo "=== 构建 Docker 镜像 ==="
docker compose build app

# 启动服务
echo ""
echo "=== 启动 nanoMuse 网页服务 ==="
docker compose up -d app

# 等待服务启动
echo ""
echo "等待服务启动..."
sleep 5

# 检查服务状态
if docker compose ps app | grep -q "Up"; then
    echo ""
    echo "=== 部署成功! ==="
    echo ""
    echo "🌐 网页版地址: http://localhost:8787"
    echo "🔑 访问 Token: nanomuse-web-token-2026"
    echo ""
    echo "完整访问链接:"
    echo "http://localhost:8787/#token=nanomuse-web-token-2026"
    echo ""
    echo "=== 常用命令 ==="
    echo "查看日志: cd $NANOMUSE_DIR && docker compose logs -f app"
    echo "停止服务: cd $NANOMUSE_DIR && docker compose stop app"
    echo "重启服务: cd $NANOMUSE_DIR && docker compose restart app"
    echo ""
else
    echo ""
    echo "错误: 服务启动失败"
    echo "查看日志: docker compose logs app"
    exit 1
fi
