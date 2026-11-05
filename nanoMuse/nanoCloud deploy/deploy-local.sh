#!/bin/bash
# nanoMuse Cloud 本地部署脚本
# 使用方法: ./deploy-local.sh [local|lan]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/nanoMuse-main/cloud"

echo "============================================"
echo "    nanoMuse Cloud 本地部署"
echo "============================================"
echo ""

# 解析参数
MODE="${1:-local}"

case "$MODE" in
    local)
        echo "📍 部署模式: 本机访问"
        BIND_ADDR="127.0.0.1"
        BASE_URL="http://127.0.0.1:8787"
        ;;
    lan)
        echo "📍 部署模式: 局域网访问"
        # 获取本机 IP
        BIND_ADDR="0.0.0.0"
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        BASE_URL="http://${LOCAL_IP}:8787"
        echo "📍 本机 IP: $LOCAL_IP"
        ;;
    *)
        echo "❌ 未知模式: $MODE"
        echo "用法: $0 [local|lan]"
        exit 1
        ;;
esac

echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 未安装 Docker"
    echo "请先安装 Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# 检查 Docker Compose
if ! docker compose version &> /dev/null; then
    echo "❌ 未安装 Docker Compose"
    exit 1
fi

echo "✅ Docker 已安装"
echo ""

# 检查 cloud 源码目录
if [ ! -d "$CLOUD_DIR" ]; then
    echo "❌ 未找到 nanoMuse Cloud 源码"
    echo "期望路径: $CLOUD_DIR"
    exit 1
fi

echo "✅ 源码目录: $CLOUD_DIR"
echo ""

# 创建数据目录
mkdir -p "$SCRIPT_DIR/data"

# 复制配置文件
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "📝 创建配置文件..."
    cp "$SCRIPT_DIR/.env.local" "$SCRIPT_DIR/.env"
    
    # 生成随机密钥
    SECRET=$(openssl rand -hex 32)
    ADMIN_TOKEN=$(openssl rand -hex 16)
    
    # 替换配置
    sed -i "s/CLOUD_SECRET=change-me-to-random-string/CLOUD_SECRET=$SECRET/" "$SCRIPT_DIR/.env"
    sed -i "s/CLOUD_ADMIN_TOKEN=admin-password-here/CLOUD_ADMIN_TOKEN=$ADMIN_TOKEN/" "$SCRIPT_DIR/.env"
    sed -i "s|PUBLIC_BASE=http://127.0.0.1:8787|PUBLIC_BASE=$BASE_URL|" "$SCRIPT_DIR/.env"
    sed -i "s/RELAY_BIND=127.0.0.1/RELAY_BIND=$BIND_ADDR/" "$SCRIPT_DIR/.env"
    
    echo "✅ 配置文件已创建: $SCRIPT_DIR/.env"
    echo "   管理员密码: $ADMIN_TOKEN"
    echo ""
    echo "⚠️  请保存以上信息！"
    echo ""
else
    echo "✅ 配置文件已存在: $SCRIPT_DIR/.env"
    
    # 读取管理员密码
    ADMIN_TOKEN=$(grep "^CLOUD_ADMIN_TOKEN=" "$SCRIPT_DIR/.env" | cut -d'=' -f2)
    
    echo ""
fi

# 进入部署目录
cd "$SCRIPT_DIR"

echo "🔨 构建 Docker 镜像..."
echo ""

# 构建并启动
docker compose -f docker-compose.local.yml up -d --build

echo ""
echo "============================================"
echo "    ✅ 部署成功！"
echo "============================================"
echo ""
echo "📍 访问地址: $BASE_URL"
echo "🔑 管理员密码: $ADMIN_TOKEN"
echo ""
echo "📱 客户端配置:"
echo "   在 nanoMuse App 中:"
echo "   Settings → nanoMuse Cloud → Server"
echo "   输入: $BASE_URL"
echo ""
echo "📋 常用命令:"
echo "   查看日志: docker compose -f docker-compose.local.yml logs -f relay"
echo "   停止服务: docker compose -f docker-compose.local.yml down"
echo "   重启服务: docker compose -f docker-compose.local.yml restart"
echo ""
echo "📖 验证码查看:"
echo "   docker compose -f docker-compose.local.yml logs -f relay | grep code"
echo ""

# 等待健康检查
echo "⏳ 等待服务启动..."
for i in {1..30}; do
    if curl -sf "$BASE_URL/healthz" > /dev/null 2>&1; then
        echo "✅ 服务已就绪！"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  服务启动超时，请检查日志"
    fi
    sleep 1
done

echo ""
echo "管理控制台: $BASE_URL/app/admin/"
echo ""
