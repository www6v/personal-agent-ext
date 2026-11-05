#!/bin/bash
# 查看 nanoMuse Cloud 日志

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📋 nanoMuse Cloud 日志"
echo "按 Ctrl+C 退出"
echo ""

docker compose -f docker-compose.local.yml logs -f relay
