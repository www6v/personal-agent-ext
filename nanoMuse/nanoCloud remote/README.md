# nanoMuse Cloud 远程部署

在远程服务器 (124.221.28.203) 上部署 nanoMuse Cloud（多租户中继服务器）。

---

## ✅ 部署状态

**当前状态**: 运行中

| 项目 | 值 |
|------|-----|
| **服务器** | 124.221.28.203 |
| **端口** | 8789 |
| **访问地址** | http://124.221.28.203:8789 |
| **管理后台** | http://124.221.28.203:8789/app/admin/ |
| **版本** | 0.31.1 |
| **部署时间** | 2026-11-06 |

---

## 📍 服务信息

| 项目 | 值 |
|------|-----|
| **源码目录** | /home/wei/personal-agent/nanoMuse-main |
| **部署目录** | /home/wei/personal-agent/nanomuse-cloud-deploy |
| **验证码方式** | log（输出到容器日志） |

---

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `.env` | nanoMuse Cloud 配置模板 |
| `docker-compose.nanomuse-cloud.yml` | Docker Compose 配置 |
| `deploy_nanomuse_cloud.py` | 部署/管理脚本 |
| `README.md` | 本文档 |

---

## 🚀 使用方法

### 部署

```bash
cd '/home/wangwei/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/nanoCloud remote'
python deploy_nanomuse_cloud.py
```

脚本会自动：
1. 生成随机密钥和管理员密码
2. 上传配置文件到远程服务器
3. 使用源码中的 Dockerfile 构建镜像
4. 启动 nanoMuse Cloud 容器

### 管理

```bash
# 查看状态
python deploy_nanomuse_cloud.py --status

# 查看日志
python deploy_nanomuse_cloud.py --logs

# 持续跟踪日志
python deploy_nanomuse_cloud.py --logs --follow

# 停止服务
python deploy_nanomuse_cloud.py --stop
```

---

## 🔐 访问

### 网页

- **Cloud 主页**: http://124.221.28.203:8789
- **管理后台**: http://124.221.28.203:8789/app/admin/

### 客户端配置

在 nanoMuse App 中：
1. Settings → Connections → nanoMuse Cloud
2. Server URL: `http://124.221.28.203:8789`
3. 注册或登录

### 验证码

部署时使用 `CODE_SENDER=log`，验证码输出到容器日志：

```bash
# 查看验证码
docker logs nanomuse-cloud 2>&1 | grep -i code

# 持续监控
docker logs -f nanomuse-cloud
```

---

## 🛠️ Docker 命令

```bash
# 查看容器状态
docker ps | grep nanomuse-cloud

# 查看日志
docker logs -f nanomuse-cloud

# 停止服务
docker compose -f /home/wei/personal-agent/nanomuse-cloud-deploy/docker-compose.nanomuse-cloud.yml down

# 重启服务
docker restart nanomuse-cloud

# 重新构建
docker compose -f /home/wei/personal-agent/nanomuse-cloud-deploy/docker-compose.nanomuse-cloud.yml build --no-cache
```

---

## 📋 配置说明

### 关键环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `CLOUD_SECRET` | 加密密钥（32字节随机十六进制） | 自动生成 |
| `CLOUD_ADMIN_TOKEN` | 管理员密码 | 自动生成 |
| `PUBLIC_BASE` | 公开访问 URL | http://124.221.28.203:8789 |
| `UPSTREAM_BASE` | 模型 API 地址 | https://dashscope.aliyuncs.com/compatible-mode/v1 |
| `UPSTREAM_KEY` | 模型 API Key | sk-ff84a4311f0d484581f7decac8b54829 |
| `CODE_SENDER` | 验证码方式 | log |
| `SIGNUP_OPEN` | 是否开放注册 | 1（开放） |
| `ALLOWANCE_CNY` | 每用户额度（元） | 10 |
| `HUB_ENABLED` | 启用 Hub 设备协作 | true |

### 验证码发送方式

| 值 | 说明 |
|----|------|
| `log` | 输出到容器日志（推荐开发用） |
| `smtp` | 邮件发送（需配置 SMTP_HOST 等） |
| `aliyun` | 阿里云短信（中国大陆手机号） |
| `both` | 邮件+短信 |

---

## ⚠️ 注意事项

1. **CLOUD_SECRET**: 不要旋转此密钥，否则所有账户会失效
2. **CLOUD_ADMIN_TOKEN**: 请妥善保管，用于访问管理后台
3. **数据持久化**: 数据存储在 Docker volume `cloud-data` 中
4. **端口**: 容器内部固定 8787，宿主机映射到 8789
5. **源码**: 部署脚本不修改 nanoMuse-main 目录中的任何代码
