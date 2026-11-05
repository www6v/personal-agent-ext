#!/bin/bash
# 停止 nanoMuse Cloud 服务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "⏹️  停止 nanoMuse Cloud..."
docker compose -f docker-compose.local.yml down

echo "✅ 服务已停止"
