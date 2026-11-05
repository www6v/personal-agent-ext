#!/usr/bin/env python3
"""nanoMuse 远程部署脚本"""

import paramiko
import time
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description='Deploy nanoMuse to remote server')
    parser.add_argument('--host', required=True)
    parser.add_argument('--user', required=True)
    parser.add_argument('--password', required=True)
    parser.add_argument('--api-key', required=True)
    parser.add_argument('--nanomuse-dir', required=True)
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--config', required=True)
    args = parser.parse_args()

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    print(f"连接到 {args.host}...")
    client.connect(args.host, port=22, username=args.user, password=args.password, timeout=30)
    print("✅ 连接成功\n")

    def exec_cmd(cmd, timeout=300, show=True):
        if show:
            print(f"$ {cmd[:100]}..." if len(cmd) > 100 else f"$ {cmd}")
        stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
        exit_status = stdout.channel.recv_exit_status()
        out = stdout.read().decode('utf-8').strip()
        err = stderr.read().decode('utf-8').strip()
        if out:
            print(out)
        if err and "WARNING" not in err:
            print(err)
        return exit_status == 0, out

    # 1. 读取并修改配置文件
    print("=== 创建配置文件 ===")
    with open(args.config, 'r') as f:
        config_content = f.read()
    
    # 替换 API key 和端口
    config_content = config_content.replace('QWEN_API_KEY_PLACEHOLDER', args.api_key)
    config_content = config_content.replace('port = 8788', f'port = {args.port}')
    
    # 写入远程服务器
    escaped_config = config_content.replace("'", "'\\''")
    exec_cmd(f"cat > {args.nanomuse_dir}/config/config.toml << 'TOML'\n{config_content}\nTOML")
    print("✅ 配置文件已创建\n")

    # 2. 创建虚拟环境
    print("=== 设置 Python 环境 ===")
    exec_cmd(f"cd {args.nanomuse_dir} && python3 -m venv .venv")
    exec_cmd(f"cd {args.nanomuse_dir} && source .venv/bin/activate && pip install --upgrade pip -q")
    print("✅ 虚拟环境已创建\n")

    # 3. 安装依赖
    print("=== 安装依赖 (这可能需要几分钟) ===")
    exec_cmd(f"cd {args.nanomuse_dir} && source .venv/bin/activate && pip install -e . -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -q", timeout=600)
    print("✅ 依赖已安装\n")

    # 4. 创建数据目录
    print("=== 创建数据目录 ===")
    exec_cmd("mkdir -p ~/.nanomuse/workspace")
    print("✅ 数据目录已创建\n")

    # 5. 停止已有服务
    print("=== 停止已有服务 ===")
    exec_cmd("pkill -f 'nanomuse serve' || true")
    time.sleep(2)
    print("✅ 已清理旧进程\n")

    # 6. 启动服务
    print("=== 启动 nanoMuse 服务 ===")
    token = "nanomuse-remote-token-2026"
    start_cmd = f"""cd {args.nanomuse_dir} && source .venv/bin/activate && export NANOMUSE_SERVER_TOKEN={token} && nohup nanomuse serve --host 0.0.0.0 --port {args.port} --no-qr > /tmp/nanomuse.log 2>&1 &"""
    exec_cmd(start_cmd)
    time.sleep(3)

    # 7. 验证
    print("=== 验证服务 ===")
    exec_cmd(f"ss -tlnp | grep {args.port}")
    success, _ = exec_cmd(f"curl -s http://127.0.0.1:{args.port}/healthz")

    print("\n============================================")
    print("    ✅ 部署完成！")
    print("============================================")
    print(f"\n📍 访问地址: http://{args.host}:{args.port}")
    print(f"🔑 Token: {token}")
    print(f"\n🔗 完整链接: http://{args.host}:{args.port}/#token={token}")
    print("\n📋 常用命令:")
    print(f"   查看日志: tail -f /tmp/nanomuse.log")
    print(f"   停止服务: pkill -f 'nanomuse serve'")
    print(f"   检查端口: ss -tlnp | grep {args.port}")
    print("")

    client.close()

if __name__ == '__main__':
    main()
