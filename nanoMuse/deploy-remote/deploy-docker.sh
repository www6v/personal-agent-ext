#!/bin/bash
# nanoMuse Docker 部署脚本
# 使用源码中已有的 Docker 配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_HOST="124.221.28.203"
REMOTE_USER="root"
REMOTE_PASS="1qaZxsw@"
NANOMUSE_DIR="/home/wei/personal-agent/nanoMuse-main"
DEPLOY_DIR="$SCRIPT_DIR"

echo "============================================"
echo "    nanoMuse Docker 部署"
echo "============================================"
echo ""
echo "服务器: $REMOTE_HOST"
echo "端口: 8788"
echo ""

python3 << 'PYTHON_SCRIPT'
import paramiko
import time
import os
import sys

host = "124.221.28.203"
username = "root"
password = "1qaZxsw@"
nanomuse_dir = "/home/wei/personal-agent/nanoMuse-main"
deploy_dir = sys.argv[1] if len(sys.argv) > 1 else "."

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
print(f"连接到 {host}...")
client.connect(host, port=22, username=username, password=password, timeout=30)
print("✅ 连接成功\n")

def exec_cmd(cmd, timeout=600):
    display = cmd[:80] + "..." if len(cmd) > 80 else cmd
    print(f"$ {display}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8')
    err = stderr.read().decode('utf-8')
    if out:
        lines = out.split('\n')
        print('\n'.join(lines[-30:]) if len(lines) > 30 else out)
    if err and "WARNING" not in err and "Step" not in err:
        err_lines = err.split('\n')
        print('\n'.join(err_lines[-10:]) if len(err_lines) > 10 else err)
    return exit_status == 0

# 同步配置文件
print("=== 同步配置文件 ===")
sftp = client.open_sftp()

files_to_copy = {
    os.path.join(deploy_dir, ".env"): f"{nanomuse_dir}/.env",
    os.path.join(deploy_dir, "config.toml"): f"{nanomuse_dir}/config/config.toml",
}

for local, remote in files_to_copy.items():
    if os.path.exists(local):
        print(f"  复制: {os.path.basename(local)}")
        sftp.put(local, remote)

sftp.close()
print("✅ 配置已同步\n")

# 停止旧容器
print("=== 停止旧容器 ===")
exec_cmd(f"cd {nanomuse_dir} && docker compose down 2>/dev/null || true")

# 创建必要目录
print("\n=== 创建目录 ===")
exec_cmd(f"mkdir -p {nanomuse_dir}/workspace")

# 构建镜像
print("\n=== 构建 Docker 镜像 ===")
print("使用阿里云镜像加速...")
success = exec_cmd(f"cd {nanomuse_dir} && docker build --build-arg PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/ -t nanomuse:latest .", timeout=600)

if not success:
    print("\n❌ 构建失败")
    client.close()
    sys.exit(1)

print("\n✅ 镜像构建成功")

# 启动服务
print("\n=== 启动服务 ===")
exec_cmd(f"cd {nanomuse_dir} && docker compose up -d app")

# 等待启动
print("\n等待服务启动...")
time.sleep(10)

# 验证
print("\n=== 验证服务 ===")
exec_cmd("docker ps | grep nanomuse")

print("\n--- 容器日志 ---")
exec_cmd("docker logs nanomuse-app-1 --tail 30 2>/dev/null || docker logs nanomuse-muse-1 --tail 30 2>/dev/null || echo 'No logs yet'")

# 测试健康检查
print("\n--- 健康检查 ---")
exec_cmd("curl -s http://127.0.0.1:8788/api/health 2>/dev/null || curl -s http://127.0.0.1:8788/healthz 2>/dev/null || echo 'Checking...'")

print("\n============================================")
print("    ✅ Docker 部署完成！")
print("============================================")
print(f"\n📍 访问地址: http://{host}:8788")
print(f"🔑 Token: nanomuse-remote-token-2026")
print(f"\n🔗 完整链接: http://{host}:8788/#token=nanomuse-remote-token-2026")
print("\n📋 Docker 命令:")
print(f"   查看日志: docker logs -f nanomuse-app-1")
print(f"   停止服务: cd {nanomuse_dir} && docker compose down")
print(f"   重启服务: docker restart nanomuse-app-1")
print("")

client.close()
PYTHON_SCRIPT
