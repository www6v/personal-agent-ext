# nanoMuse 远程部署

在远程服务器上部署 nanoMuse 网页控制台。

---

## 📍 服务信息

| 项目 | 值 |
|------|-----|
| **服务器** | 124.221.28.203 |
| **端口** | 8788 |
| **Token** | nanomuse-remote-token-2026 |
| **模型** | qwen-plus (Qwen API) |

---

## 🌐 访问地址

**网页控制台**: http://124.221.28.203:8788/#token=nanomuse-remote-token-2026

---

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `deploy-nanomuse-remote.sh` | 部署脚本 |
| `deploy_remote.py` | Python 部署模块 |
| `config.toml` | 配置模板 |
| `remote-manage.sh` | 远程管理脚本 |

---

## 🚀 使用方法

### 部署

```bash
# 设置环境变量
export API_KEY="sk-ff84a4311f0d484581f7decac8b54829"
export REMOTE_PASS="1qaZxsw@"

# 运行部署脚本
./deploy-nanomuse-remote.sh
```

### 管理

```bash
# 查看状态
./remote-manage.sh status

# 查看日志
./remote-manage.sh logs

# 停止服务
./remote-manage.sh stop

# 重启服务
./remote-manage.sh restart

# 查看信息
./remote-manage.sh info
```

---

## 🔧 配置

编辑 `config.toml` 修改配置：

```toml
[llm]
provider = "openai"
model = "qwen-plus"
base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1"
api_key = "your-api-key"

[agent]
language = "zh"
```

---

## 📋 远程服务器路径

| 路径 | 说明 |
|------|------|
| `/home/wei/personal-agent/nanoMuse-main/` | nanoMuse 源码 |
| `/home/wei/personal-agent/nanoMuse-main/.venv/` | Python 虚拟环境 |
| `/home/wei/personal-agent/nanoMuse-main/config/config.toml` | 配置文件 |
| `~/.nanomuse/` | 数据目录 |
| `/tmp/nanomuse.log` | 日志文件 |
