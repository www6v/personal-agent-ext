#!/bin/bash
# nanoMuse Cloud 管理快捷脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
    status)
        python3 "$SCRIPT_DIR/deploy_nanomuse_cloud.py" --status
        ;;
    logs)
        python3 "$SCRIPT_DIR/deploy_nanomuse_cloud.py" --logs ${2:+"$2"}
        ;;
    stop)
        python3 "$SCRIPT_DIR/deploy_nanomuse_cloud.py" --stop
        ;;
    *)
        echo "nanoMuse Cloud 管理"
        echo ""
        echo "用法: $0 <命令>"
        echo ""
        echo "命令:"
        echo "  (无参数)  - 部署 nanoMuse Cloud"
        echo "  status    - 查看服务状态"
        echo "  logs      - 查看日志"
        echo "  stop      - 停止服务"
        echo ""
        python3 "$SCRIPT_DIR/deploy_nanomuse_cloud.py"
        ;;
esac
