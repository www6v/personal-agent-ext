#!/usr/bin/env python3
"""
nanoMuse Cloud Docker 部署脚本
部署到远程服务器: 124.221.28.203

用法:
  python deploy_nanomuse_cloud.py
  python deploy_nanomuse_cloud.py --stop     # 停止服务
  python deploy_nanomuse_cloud.py --status   # 查看状态
  python deploy_nanomuse_cloud.py --logs     # 查看日志
"""

import paramiko
import time
import os
import sys
import argparse
import secrets

# ============================================
# 配置
# ============================================

REMOTE_HOST = "124.221.28.203"
REMOTE_USER = "root"
REMOTE_PASS = "1qaZxsw@"

# 远程服务器上的 nanoMuse 源码目录
NANOMUSE_DIR = "/home/wei/personal-agent/nanoMuse-main"
# 远程服务器上的 Cloud 部署目录
CLOUD_DEPLOY_DIR = "/home/wei/personal-agent/nanomuse-cloud-deploy"

# 容器端口映射
SERVER_PORT = 8789
SERVER_TOKEN = "nanomuse-cloud-token-2026"

# 本地部署脚本目录
LOCAL_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def get_ssh_client():
    """创建 SSH 客户端并连接"""
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"连接到 {REMOTE_HOST}...")
    client.connect(REMOTE_HOST, port=22, username=REMOTE_USER, password=REMOTE_PASS, timeout=30)
    print("✅ 连接成功\n")
    return client


def exec_cmd(client, cmd, timeout=600):
    """执行远程命令"""
    display = cmd[:90] + "..." if len(cmd) > 90 else cmd
    print(f"$ {display}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8')
    err = stderr.read().decode('utf-8')

    if out:
        lines = out.split('\n')
        # 显示最后 20 行，避免输出过多
        if len(lines) > 20:
            print(f"  ... ({len(lines)} 行)")
            print('\n'.join(lines[-20:]))
        else:
            print(out.rstrip())
    if err:
        err_lines = err.split('\n')
        # 过滤掉无害的警告
        filtered = [l for l in err_lines if 'WARNING' not in l and 'Step' not in l and l.strip()]
        if filtered:
            if len(filtered) > 10:
                print('\n'.join(filtered[-10:]))
            else:
                print('\n'.join(filtered))
    return exit_status == 0


def upload_file(sftp, local_path, remote_path):
    """上传文件到远程服务器"""
    if os.path.exists(local_path):
        sftp.put(local_path, remote_path)
        print(f"  ✅ {os.path.basename(local_path)}")


def do_stop(client):
    """停止 nanoMuse Cloud 服务"""
    print("=" * 50)
    print("停止 nanoMuse Cloud...")
    print("=" * 50)
    exec_cmd(client, f"cd {CLOUD_DEPLOY_DIR} && docker compose -f docker-compose.nanomuse-cloud.yml down 2>/dev/null || true")
    print("\n✅ 服务已停止")


def do_status(client):
    """查看服务状态"""
    print("=" * 50)
    print("nanoMuse Cloud 服务状态")
    print("=" * 50)
    exec_cmd(client, f"cd {CLOUD_DEPLOY_DIR} && docker compose -f docker-compose.nanomuse-cloud.yml ps 2>/dev/null || true")
    exec_cmd(client, "docker ps | grep nanomuse-cloud")
    exec_cmd(client, f"ss -tlnp | grep {SERVER_PORT}")


def do_logs(client, follow=False):
    """查看日志"""
    tail = "50"
    flag = "-f" if follow else ""
    exec_cmd(client, f"docker logs {flag} nanomuse-cloud --tail {tail} 2>&1", timeout=60 if not follow else 300)


def do_deploy(client):
    """部署 nanoMuse Cloud"""
    # ---- Step 1: 上传配置文件 ----
    print("=" * 50)
    print("Step 1: 上传配置文件")
    print("=" * 50)

    sftp = client.open_sftp()

    # 创建远程目录
    try:
        sftp.mkdir(CLOUD_DEPLOY_DIR)
    except IOError:
        pass

    # 生成随机密钥
    cloud_secret = secrets.token_hex(32)
    cloud_admin_token = secrets.token_hex(16)

    # 准备 .env 内容
    env_path = os.path.join(LOCAL_SCRIPT_DIR, ".env")
    env_content = open(env_path).read()
    env_content = env_content.replace("change-me-to-random-32-hex-chars", cloud_secret)
    env_content = env_content.replace("change-me-to-admin-password", cloud_admin_token)

    # 写入临时文件并上传
    temp_env = f"/tmp/nanomuse-cloud-env-{int(time.time())}"
    with open(temp_env, 'w') as f:
        f.write(env_content)

    print(f"  CLOUD_SECRET: {cloud_secret[:8]}...{cloud_secret[-8:]}")
    print(f"  CLOUD_ADMIN_TOKEN: {cloud_admin_token}")

    upload_file(sftp, temp_env, f"{CLOUD_DEPLOY_DIR}/.env")
    upload_file(sftp, os.path.join(LOCAL_SCRIPT_DIR, "docker-compose.nanomuse-cloud.yml"),
                f"{CLOUD_DEPLOY_DIR}/docker-compose.nanomuse-cloud.yml")

    os.remove(temp_env)
    sftp.close()
    print()

    # ---- Step 2: 检查环境 ----
    print("=" * 50)
    print("Step 2: 检查环境")
    print("=" * 50)
    exec_cmd(client, f"ls {NANOMUSE_DIR}/cloud/Dockerfile")
    exec_cmd(client, f"ls {NANOMUSE_DIR}/cloud/nanomuse_cloud/__init__.py")
    print()

    # ---- Step 3: 停止旧容器 ----
    print("=" * 50)
    print("Step 3: 停止旧容器")
    print("=" * 50)
    exec_cmd(client, f"cd {CLOUD_DEPLOY_DIR} && docker compose -f docker-compose.nanomuse-cloud.yml down 2>/dev/null || true")
    exec_cmd(client, "docker rm -f nanomuse-cloud 2>/dev/null || true")
    print()

    # ---- Step 4: 构建镜像 ----
    print("=" * 50)
    print("Step 4: 构建 Docker 镜像")
    print("=" * 50)
    print("使用阿里云 PyPI 镜像加速...")

    # 先检查基础镜像是否存在
    print("检查基础镜像 python:3.12-slim...")
    check_image = exec_cmd(client, "docker image inspect python:3.12-slim >/dev/null 2>&1")

    if not check_image:
        print("拉取基础镜像（使用镜像加速）...")
        # 通过镜像加速站拉取
        mirrors = [
            "docker.1ms.run/library/python:3.12-slim",
            "registry.cn-hangzhou.aliyuncs.com/library/python:3.12-slim",
        ]
        pulled = False
        for mirror in mirrors:
            if exec_cmd(client, f"docker pull {mirror}", timeout=300):
                exec_cmd(client, f"docker tag {mirror} python:3.12-slim")
                print(f"✅ 已拉取: {mirror}")
                pulled = True
                break
        if not pulled:
            print("⚠️ 镜像拉取失败，尝试直接构建...")

    # 构建：先创建临时的带 pip 配置的 Dockerfile
    # 由于原始 Dockerfile 不支持 PIP_INDEX_URL build-arg，我们通过环境变量传递
    print("构建 nanoMuse Cloud 镜像...")
    success = exec_cmd(
        client,
        f"""cd {NANOMUSE_DIR}/cloud && \
        docker build \
          --build-arg PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/ \
          --build-arg PIP_TRUSTED_HOST=mirrors.aliyun.com \
          -t nanomuse-cloud:latest .""",
        timeout=600
    )

    if not success:
        print("\n❌ 镜像构建失败")
        print("请检查源码目录是否正确以及网络是否正常")
        return

    print("\n✅ 镜像构建成功")
    print()

    # ---- Step 5: 启动服务 ----
    print("=" * 50)
    print("Step 5: 启动服务")
    print("=" * 50)
    exec_cmd(client, f"cd {CLOUD_DEPLOY_DIR} && docker compose -f docker-compose.nanomuse-cloud.yml up -d")

    # 等待启动
    print("\n等待服务启动...")
    time.sleep(10)

    # ---- Step 6: 验证 ----
    print("=" * 50)
    print("Step 6: 验证服务")
    print("=" * 50)

    exec_cmd(client, "docker ps | grep nanomuse-cloud")
    exec_cmd(client, f"curl -s http://127.0.0.1:{SERVER_PORT}/healthz")

    print("\n============================================")
    print("    ✅ nanoMuse Cloud 部署完成！")
    print("============================================")
    print(f"\n📍 访问地址: http://{REMOTE_HOST}:{SERVER_PORT}")
    print(f"📱 管理页面: http://{REMOTE_HOST}:{SERVER_PORT}/app/admin/")
    print(f"🔑 管理员密码: {cloud_admin_token}")
    print(f"\n⚠️  请保存以上管理员密码！")
    print(f"\n📋 验证码: CODE_SENDER=log，验证码输出到容器日志")
    print(f"   docker logs nanomuse-cloud 2>&1 | grep -i code")
    print(f"\n📋 Docker 命令:")
    print(f"   查看日志: docker logs -f nanomuse-cloud")
    print(f"   停止服务: cd {CLOUD_DEPLOY_DIR} && docker compose -f docker-compose.nanomuse-cloud.yml down")
    print(f"   重启服务: docker restart nanomuse-cloud")
    print(f"   查看状态: cd {CLOUD_DEPLOY_DIR} && docker compose -f docker-compose.nanomuse-cloud.yml ps")
    print("")


def main():
    parser = argparse.ArgumentParser(description='nanoMuse Cloud Docker 部署')
    parser.add_argument('--stop', action='store_true', help='停止服务')
    parser.add_argument('--status', action='store_true', help='查看状态')
    parser.add_argument('--logs', action='store_true', help='查看日志')
    parser.add_argument('--follow', action='store_true', help='持续跟踪日志')
    args = parser.parse_args()

    client = None
    try:
        client = get_ssh_client()

        if args.stop:
            do_stop(client)
        elif args.status:
            do_status(client)
        elif args.logs:
            do_logs(client, follow=args.follow)
        else:
            do_deploy(client)

    except Exception as e:
        print(f"\n❌ 错误: {e}")
        sys.exit(1)
    finally:
        if client:
            client.close()
            print("连接已关闭")


if __name__ == '__main__':
    main()
