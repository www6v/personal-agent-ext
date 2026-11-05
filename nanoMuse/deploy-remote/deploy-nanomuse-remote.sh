#!/bin/bash
# nanoMuse 远程服务器部署脚本
# 使用方法: API_KEY=xxx REMOTE_PASS=xxx ./deploy-nanomuse-remote.sh

set -e

# 从环境变量获取敏感信息
API_KEY="${API_KEY:?请设置 API_KEY 环境变量}"
REMOTE_PASS="${REMOTE_PASS:?请设置 REMOTE_PASS 环境变量}"

# 配置
REMOTE_HOST="124.221.28.203"
REMOTE_USER="root"
NANOMUSE_DIR="/home/wei/personal-agent/nanoMuse-main"
SERVER_PORT=8788
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "    nanoMuse 远程部署"
echo "============================================"
echo ""
echo "服务器: $REMOTE_HOST"
echo "端口: $SERVER_PORT"
echo ""

python3 "$SCRIPT_DIR/deploy_remote.py" \
    --host "$REMOTE_HOST" \
    --user "$REMOTE_USER" \
    --password "$REMOTE_PASS" \
    --api-key "$API_KEY" \
    --nanomuse-dir "$NANOMUSE_DIR" \
    --port "$SERVER_PORT" \
    --config "$SCRIPT_DIR/config.toml"
