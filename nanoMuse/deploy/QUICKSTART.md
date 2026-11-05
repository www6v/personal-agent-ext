# nanoMuse 快速参考

## 🚀 访问地址

**网页版**: http://localhost:8787/#token=nanomuse-web-token-2026

**局域网**: http://192.168.3.7:8787/#token=nanomuse-web-token-2026

---

## ⚡ 常用命令

### 启动服务
```bash
cd '/home/wangwei/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/deploy'
./start-web-fixed.sh
```

### 停止服务
```bash
pkill -f "nanomuse serve"
```

### 查看状态
```bash
ps aux | grep "nanomuse serve"
ss -tlnp | grep 8787
```

### 查看日志
```bash
tail -f /tmp/nanomuse.log
```

---

## 🔧 配置信息

| 项目 | 值 |
|------|-----|
| **模型** | qwen-plus |
| **API** | 阿里云百炼 (DashScope) |
| **语言** | 中文 |
| **端口** | 8787 |
| **Token** | nanomuse-web-token-2026 |

---

## 📁 重要路径

| 路径 | 说明 |
|------|------|
| `~/wei/workspacePy/personal agent/nanoMuse-main/` | nanoMuse 源码 |
| `~/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/deploy/` | 部署文件 |
| `~/.nanomuse/` | 数据目录 |
| `~/.nanomuse/workspace/` | Agent 工作区 |

---

## 🔍 API 测试

```bash
# 检查状态
curl -s http://localhost:8787/api/state \
  -H "Authorization: Bearer nanomuse-web-token-2026" | jq .

# 检查设置
curl -s http://localhost:8787/api/settings \
  -H "Authorization: Bearer nanomuse-web-token-2026" | jq .

# 列出目标
curl -s http://localhost:8787/api/goals \
  -H "Authorization: Bearer nanomuse-web-token-2026" | jq .
```

---

## 📝 快速修改配置

编辑配置文件：
```bash
nano '/home/wangwei/wei/workspacePy/personal agent/personal-agent-ext/nanoMuse/deploy/config.toml'
```

然后重启服务：
```bash
pkill -f "nanomuse serve"
./start-web-fixed.sh
```

---

## 💡 故障排除

### 服务无法启动
```bash
# 检查端口占用
ss -tlnp | grep 8787

# 查看错误日志
cat /tmp/nanomuse.log
```

### API 调用失败
```bash
# 测试 Qwen API
curl https://dashscope.aliyuncs.com/compatible-mode/v1/models \
  -H "Authorization: Bearer sk-ff84a4311f0d484581f7decac8b54829"
```

### 内存不足
```bash
# 清理数据（谨慎！）
rm -rf ~/.nanomuse/*
```

---

## 🔗 相关链接

- 官方文档: https://nanomuse.cn/docs/
- 部署报告: ./DEPLOY_SUCCESS.md
- 详细文档: ./README.md
