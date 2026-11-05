# nanoMuse 部署成功报告

**部署时间**: 2026-11-04 22:32  
**部署状态**: ✅ 成功

---

## 📊 部署概览

### 网页版 (Web App)

**状态**: ✅ 运行中

| 项目 | 值 |
|------|-----|
| **版本** | nanoMuse v1.0.9 |
| **模型** | qwen-plus (Qwen API) |
| **监听地址** | 0.0.0.0:8787 |
| **进程PID** | 135981 |
| **访问Token** | nanomuse-web-token-2026 |

**访问链接**:
- 本地: http://localhost:8787/#token=nanomuse-web-token-2026
- 局域网: http://192.168.3.7:8787/#token=nanomuse-web-token-2026

### 桌面版 (Desktop App)

**状态**: ✅ 已安装并运行

| 项目 | 值 |
|------|-----|
| **安装路径** | /opt/nanoMuse |
| **进程** | nanomuse-desktop |
| **配置文件** | ~/.config/nanomuse-desktop |

桌面版已经在使用系统安装的版本，配置文件已更新为使用 Qwen API。

---

## 🔧 配置文件

### LLM 配置 (Qwen API)

```toml
[llm]
provider = "openai"
model = "qwen-plus"
base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1"
api_key = "sk-ff84a4311f0d484581f7decac8b54829"
```

### 关键配置

- **语言**: 中文 (zh)
- **安全模式**: ask (敏感操作需审批)
- **记忆系统**: 已启用
- **最大步骤数**: 30
- **流式输出**: 已启用

---

## 📁 部署文件

所有部署相关文件位于：
```
/home/wangwei/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/deploy/
```

### 文件清单

| 文件 | 说明 |
|------|------|
| `config.toml` | nanoMuse 配置文件 (Qwen API) |
| `.env` | 环境变量配置 |
| `start-web-fixed.sh` | 网页版启动脚本 (推荐) |
| `start-local.sh` | 本地启动脚本 |
| `start-desktop.sh` | 桌面版启动脚本 |
| `stop.sh` | 停止服务脚本 |
| `README.md` | 部署说明文档 |
| `DEPLOY_SUCCESS.md` | 本报告 |

---

## 🚀 快速启动

### 启动网页版

```bash
cd '/home/wangwei/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/deploy'
./start-web-fixed.sh
```

### 停止服务

```bash
# 停止后台进程
pkill -f "nanomuse serve"

# 或使用脚本
./stop.sh
```

### 查看日志

```bash
# 前台运行时直接查看
# 或后台运行时查看日志文件
tail -f /tmp/nanomuse.log
```

---

## ✅ 功能验证

### 已验证功能

1. ✅ **服务启动** - 端口 8787 正常监听
2. ✅ **健康检查** - /healthz 端点响应正常
3. ✅ **Web 界面** - HTML 页面正常返回
4. ✅ **配置文件** - Qwen API 配置已加载
5. ✅ **桌面应用** - 已安装并可运行

### 待验证功能

- [ ] 聊天功能 - 需要打开网页测试
- [ ] 目标管理 - 需要打开网页测试
- [ ] 记忆系统 - 需要打开网页测试
- [ ] 工具调用 - 需要打开网页测试

---

## 🌐 网络访问

### 本地访问
```
http://localhost:8787/#token=nanomuse-web-token-2026
```

### 局域网访问
```
http://192.168.3.7:8787/#token=nanomuse-web-token-2026
```

**注意**: 
- 确保防火墙允许 8787 端口
- Token 是访问凭证，请勿泄露

---

## 🔍 进程管理

### 查看运行状态

```bash
# 检查进程
ps aux | grep "nanomuse serve"

# 检查端口
ss -tlnp | grep 8787

# 查看日志
cat /tmp/nanomuse.log
```

### 重启服务

```bash
# 停止
pkill -f "nanomuse serve"

# 启动
cd '/home/wangwei/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/deploy'
./start-web-fixed.sh
```

---

## 📝 数据目录

nanoMuse 数据存储在：`~/.nanomuse/`

| 文件/目录 | 说明 |
|----------|------|
| `threads.db` | 对话历史 |
| `goals.db` | 目标数据 |
| `memory.db` | 记忆数据 |
| `triggers.db` | 触发器 |
| `reminders.db` | 提醒 |
| `workspace/` | Agent 工作区 |

---

## 💡 使用建议

### 模型选择

Qwen 提供多个模型，可根据需求选择：

- `qwen-turbo` - 快速响应，适合简单任务
- `qwen-plus` - 平衡性能（当前使用，推荐）
- `qwen-max` - 最强能力，适合复杂任务

修改 `config.toml` 中的 `model` 字段即可切换。

### 安全设置

当前安全模式为 `ask`，敏感操作会请求审批。

如需调整：
- `auto` - 自动批准所有操作（无人值守）
- `strict` - 更严格的审批
- `ask` - 平衡安全（当前）

### 语言设置

当前默认语言为中文。如需切换为英文：

```toml
[agent]
language = "en"
```

---

## 📚 相关资源

- **官方文档**: https://nanomuse.cn/docs/
- **GitHub**: https://github.com/nano-muse/nanoMuse
- **自托管指南**: https://nanomuse.cn/docs/zh/self-hosting
- **Qwen API**: https://help.aliyun.com/zh/dashscope/

---

## ⚠️ 注意事项

1. **API Key 安全**: 已在配置文件中设置，请勿泄露
2. **Token 安全**: 访问 Token 是凭证，仅分享给自己的设备
3. **沙箱限制**: 当前环境的 bubblewrap 沙箱无法使用（权限限制），命令会直接执行
4. **后台运行**: 网页版需要保持终端运行，或使用 nohup/systemd

---

## 🎉 部署完成

nanoMuse 已成功部署并运行！

- ✅ 网页版服务已启动
- ✅ 使用 Qwen API
- ✅ 桌面版已安装
- ✅ 配置文件已就绪

现在可以打开浏览器访问：
**http://localhost:8787/#token=nanomuse-web-token-2026**

开始使用你的个人 AI 助手！
