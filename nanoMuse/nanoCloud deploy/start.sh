#!/bin/bash
# 启动 nanoMuse Cloud 服务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
    echo "❌ 配置文件不存在，请先运行 ./deploy-local.sh"
    exit 1
fi

echo "🚀 启动 nanoMuse Cloud..."
docker compose -f docker-compose.local.yml up -d

echo ""
echo "✅ 服务已启动"
echo ""

# 读取配置
BIND_ADDR=$(grep "^RELAY_BIND=" .env | cut -d'=' -f2)
PORT=$(grep "^RELAY_PORT=" .env | cut -d'=' -f2)
PUBLIC_BASE=$(grep "^PUBLIC_BASE=" .env | cut -d'=' -f2)

if [ "$BIND_ADDR" = "127.0.0.1" ]; then
    echo "📍 访问地址: $PUBLIC_BASE"
else
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "📍 本机访问: http://127.0.0.1:${PORT:-8787}"
    echo "📍 局域网访问: http://${LOCAL_IP}:${PORT:-8787}"
fi
echo ""
echo "📋 查看日志: docker compose -f docker-compose.local.yml logs -f relay"
echo "📋 查看验证码: docker compose -f docker-compose.local.yml logs -f relay | grep -i code"
