# nanoMuse Cloud 本地部署

将 nanoMuse Cloud（中继服务器）部署在本地或局域网。

---

## 📋 前置要求

- Docker 和 Docker Compose
- nanoMuse 源码（位于上级目录的 `nanoMuse-main/`）

---

## 🚀 快速部署

### 方式一：仅本机访问

```bash
cd '/home/wangwei/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/nanoCloud deploy'
./deploy-local.sh local
```

访问地址: http://127.0.0.1:8787

### 方式二：局域网访问

```bash
./deploy-local.sh lan
```

访问地址: http://你的IP:8787

---

## 📱 客户端配置

在 nanoMuse App 中配置 Cloud 服务器：

1. 打开 Settings（设置）
2. 选择 nanoMuse Cloud
3. 在 Server 字段输入: `http://127.0.0.1:8787` 或 `http://你的IP:8787`
4. 点击 Connect

---

## 🔐 验证码发送方式

本地部署支持 4 种验证码发送方式，通过 `.env` 中的 `CODE_SENDER` 配置：

### 1. 日志模式（默认，开发用）

```env
CODE_SENDER=log
```

验证码打印到服务器日志，查看方法：

```bash
# 实时查看
docker compose -f docker-compose.local.yml logs -f relay | grep -i code

# 或使用脚本
./logs.sh
```

适合测试和开发。

### 2. 邮件发送

```env
CODE_SENDER=smtp
SMTP_HOST=smtp.example.com
SMTP_PORT=465
SMTP_USER=your-email@example.com
SMTP_PASSWORD=your-password
SMTP_FROM=nanoMuse <no-reply@example.com>
```

需要 SMTP 服务器账号。

### 3. 阿里云短信

```env
CODE_SENDER=aliyun
ALIYUN_ACCESS_KEY_ID=your-access-key
ALIYUN_ACCESS_KEY_SECRET=your-secret
ALIYUN_SMS_SIGN=你的签名
ALIYUN_SMS_TEMPLATE=SMS_123456
```

需要阿里云短信服务。

### 4. 同时使用邮件和短信

```env
CODE_SENDER=both
# 同时配置 SMTP 和阿里云
```

---

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `.env.local` | 配置模板 |
| `.env` | 实际配置（部署后生成） |
| `deploy-local.sh` | 部署脚本 |
| `start.sh` | 启动服务 |
| `stop.sh` | 停止服务 |
| `logs.sh` | 查看日志 |
| `docker-compose.local.yml` | Docker 配置 |
| `data/` | 数据目录（自动创建） |

---

## 🔧 常用命令

```bash
# 部署
./deploy-local.sh local    # 本机模式
./deploy-local.sh lan      # 局域网模式

# 管理
./start.sh                 # 启动
./stop.sh                  # 停止
./logs.sh                  # 查看日志

# 查看验证码
docker compose -f docker-compose.local.yml logs -f relay | grep -i code

# 查看管理员密码
grep "CLOUD_ADMIN_TOKEN" .env

# 重启服务
docker compose -f docker-compose.local.yml restart
```

---

## 🌐 访问地址

| 服务 | 地址 |
|------|------|
| Cloud API | http://127.0.0.1:8787 |
| 健康检查 | http://127.0.0.1:8787/healthz |
| 管理控制台 | http://127.0.0.1:8787/app/admin/ |

---

## ⚠️ 注意事项

1. **验证码**: 默认使用 log 模式，验证码打印到日志
2. **安全**: 管理员密码保存在 `.env` 文件中
3. **数据**: 数据库保存在 `data/cloud.db`
4. **备份**: 定期备份 `data/` 目录和 `.env` 文件
