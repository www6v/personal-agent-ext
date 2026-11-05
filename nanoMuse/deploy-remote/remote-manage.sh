#!/bin/bash
# nanoMuse 远程管理脚本
# 服务器: 124.221.28.203

set -e

REMOTE_HOST="124.221.28.203"
REMOTE_USER="root"
REMOTE_PASS="1qaZxsw@"
NANOMUSE_DIR="/home/wei/personal-agent/nanoMuse-main"
SERVER_PORT=8788
TOKEN="nanomuse-remote-token-2026"

show_help() {
    echo "nanoMuse 远程管理"
    echo ""
    echo "用法: $0 <命令>"
    echo ""
    echo "命令:"
    echo "  status    - 查看服务状态"
    echo "  logs      - 查看日志"
    echo "  stop      - 停止服务"
    echo "  restart   - 重启服务"
    echo "  info      - 查看服务信息"
    echo ""
}

run_remote() {
    python3 - "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PASS" "$1" << 'EOF'
import paramiko
import sys

host = sys.argv[1]
user = sys.argv[2]
pass_ = sys.argv[3]
cmd = sys.argv[4]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, port=22, username=user, password=pass_, timeout=30)

stdin, stdout, stderr = client.exec_command(cmd, timeout=30)
print(stdout.read().decode('utf-8'))
err = stderr.read().decode('utf-8')
if err:
    print(err, file=sys.stderr)

client.close()
EOF
}

case "${1:-}" in
    status)
        echo "=== 服务状态 ==="
        run_remote "ss -tlnp | grep $SERVER_PORT"
        run_remote "ps aux | grep nanomuse | grep -v grep"
        ;;
    logs)
        echo "=== 最近日志 ==="
        run_remote "tail -50 /tmp/nanomuse.log"
        ;;
    stop)
        echo "停止服务..."
        run_remote "pkill -f 'nanomuse serve'"
        echo "✅ 服务已停止"
        ;;
    restart)
        echo "重启服务..."
        run_remote "pkill -f 'nanomuse serve' || true"
        sleep 2
        run_remote "cd $NANOMUSE_DIR && source .venv/bin/activate && export NANOMUSE_SERVER_TOKEN=$TOKEN && nohup nanomuse serve --host 0.0.0.0 --port $SERVER_PORT --no-qr > /tmp/nanomuse.log 2>&1 &"
        sleep 3
        echo "✅ 服务已重启"
        ;;
    info)
        echo "=== 服务信息 ==="
        echo ""
        echo "访问地址: http://$REMOTE_HOST:$SERVER_PORT"
        echo "Token: $TOKEN"
        echo "完整链接: http://$REMOTE_HOST:$SERVER_PORT/#token=$TOKEN"
        echo ""
        run_remote "curl -s http://127.0.0.1:$SERVER_PORT/api/state -H 'Authorization: Bearer $TOKEN' | head -c 500"
        ;;
    *)
        show_help
        ;;
esac
