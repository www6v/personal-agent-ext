# nanoMuse 部署包

本目录包含 nanoMuse 的部署脚本和配置文件，使用 Qwen (通义千问) API。

## 📁 文件说明

- `config.toml` - nanoMuse 配置文件 (Qwen API)
- `.env` - 环境变量配置
- `deploy-web.sh` - 部署网页版 (Docker)
- `start-local.sh` - 本地启动 (Python)
- `start-desktop.sh` - 启动桌面版 (Electron)
- `stop.sh` - 停止所有服务

## 🚀 快速开始

### 方式一：网页版 (推荐)

使用 Docker 部署网页版：

```bash
# 赋予执行权限
chmod +x deploy-web.sh

# 部署并启动
./deploy-web.sh
```

访问地址：
- 🌐 http://localhost:8787
- 🔑 Token: `nanomuse-web-token-2026`
- 完整链接: http://localhost:8787/#token=nanomuse-web-token-2026

### 方式二：本地启动 (Python)

不使用 Docker，直接运行 Python：

```bash
chmod +x start-local.sh
./start-local.sh
```

### 方式三：桌面版

启动 Electron 桌面应用：

```bash
chmod +x start-desktop.sh
./start-desktop.sh
```

**注意**: 桌面版需要从 GitHub 下载预编译版本，或自行构建。

下载地址：https://github.com/nano-muse/nanoMuse/releases/latest

## ⚙️ 配置说明

### Qwen API 配置

配置文件 `config.toml` 中已设置 Qwen API：

```toml
[llm]
provider = "openai"
model = "qwen-plus"
base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1"
api_key = "sk-ff84a4311f0d484581f7decac8b54829"
```

可选模型：
- `qwen-turbo` - 快速响应
- `qwen-plus` - 平衡性能 (推荐)
- `qwen-max` - 最强能力

### 修改配置

编辑 `config.toml` 后，需要重启服务：

```bash
# 停止服务
./stop.sh

# 重新启动
./deploy-web.sh  # 或 ./start-local.sh
```

## 🔧 常用命令

### 查看日志

```bash
# Docker 版本
cd ../nanoMuse-main
docker compose logs -f app

# 本地版本
# 日志直接输出在终端
```

### 停止服务

```bash
./stop.sh
```

### 重启服务

```bash
./stop.sh
./deploy-web.sh
```

## 📝 数据目录

nanoMuse 的数据存储在 `~/.nanomuse` 目录：

- `threads.db` - 对话历史
- `goals.db` - 目标数据
- `memory.db` - 记忆数据
- `workspace/` - Agent 工作区

## 🌐 远程访问

如需从其他设备访问网页版：

1. 修改 `.env` 中的 `NANOMUSE_SERVER_HOST=0.0.0.0` (已设置)
2. 确保防火墙允许 8787 端口
3. 使用 `http://<服务器IP>:8787/#token=nanomuse-web-token-2026` 访问

## 🔒 安全说明

- **Token**: 修改 `.env` 中的 `NANOMUSE_SERVER_TOKEN`
- **API Key**: 已在配置文件中设置，请勿泄露
- **Sentinel**: 默认开启安全控制，敏感操作需要审批

## 📚 更多信息

- 官方文档: https://nanomuse.cn/docs/
- GitHub: https://github.com/nano-muse/nanoMuse
- 自托管指南: https://nanomuse.cn/docs/zh/self-hosting

## ❓ 故障排除

### Docker 启动失败

```bash
# 查看详细错误
cd ../nanoMuse-main
docker compose logs app

# 重新构建
docker compose build --no-cache app
```

### 端口被占用

修改 `.env` 中的端口：
```bash
NANOMUSE_SERVER_PORT=8788  # 改为其他端口
```

### API 调用失败

检查 API Key 是否有效：
```bash
curl https://dashscope.aliyuncs.com/compatible-mode/v1/models \
  -H "Authorization: Bearer sk-ff84a4311f0d484581f7decac8b54829"
```
