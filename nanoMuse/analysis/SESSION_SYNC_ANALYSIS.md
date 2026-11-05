# nanoMuse 会话同步机制分析

> 分析日期: 2026-11-05  
> 主题: Web 和 Android 如何连接到同一个 Session  
> 源码参考: `docs/cloud.md`, `docs/hub.md`, `cloud/`

---

## 一、概述

nanoMuse 通过 **Conversation Sync（会话同步）** 机制，让同一账户下的所有设备（Web、Android、iOS、Desktop）共享相同的对话内容。用户在一台设备上发送的消息会实时出现在其他设备上。

### 1.1 核心架构

```mermaid
graph LR
    subgraph Devices["用户设备"]
        Web["🌐 Web App"]
        Android["📱 Android App"]
        iOS["📱 iOS App"]
        Desktop["💻 Desktop App"]
    end

    subgraph Cloud["nanoMuse Cloud"]
        API["API 服务器"]
        SyncStore["会话同步存储"]
        WebSocket["WebSocket 推送"]
        Auth["账户认证"]
    end

    Web -->|HTTPS| API
    Android -->|HTTPS| API
    iOS -->|HTTPS| API
    Desktop -->|HTTPS| API

    API --> SyncStore
    SyncStore --> WebSocket
    WebSocket --> Web
    WebSocket --> Android
    WebSocket --> iOS
    WebSocket --> Desktop

    style Devices fill:#d0ebff
    style Cloud fill:#d3f9d8
```

---

## 二、账户体系

### 2.1 统一账户

所有设备必须登录**同一个 nanoMuse Cloud 账户**：

| 登录方式 | 支持地区 |
|---------|---------|
| 邮箱地址 | 全球 |
| 手机号 | 中国大陆（+86） |

### 2.2 认证流程

```mermaid
sequenceDiagram
    participant User as 用户
    participant App as 设备 App
    participant Cloud as nanoMuse Cloud

    User->>App: 输入邮箱/手机号
    App->>Cloud: POST /v1/auth/request-code
    Cloud->>Cloud: 生成 6 位验证码
    Cloud->>User: 发送验证码（邮件/短信）
    User->>App: 输入验证码
    App->>Cloud: POST /v1/auth/verify
    Cloud->>App: 返回 API Token
    App->>App: 保存 Token（本地存储）

    Note over App: Token 用于后续所有请求
    App->>Cloud: Authorization: Bearer {token}
```

### 2.3 设备标识

每个设备在首次登录时注册：

```json
{
  "device_id": "pc-abc123",
  "device_name": "My MacBook",
  "kind": "desktop",
  "platform": "macos",
  "version": "1.0.9"
}
```

---

## 三、会话同步机制

### 3.1 同步开关

在设备设置中控制：

```
Settings → nanoMuse Cloud → Sync conversations between my devices
```

| 选项 | 默认值 | 说明 |
|------|--------|------|
| Sync conversations | ✅ ON | 同步主对话 |
| Also sync side chats | ❌ OFF | 同步侧对话（目标、触发器等） |

**注意**: 关闭同步会删除 relay 上存储的所有会话数据。

### 3.2 同步的数据

| 数据类型 | 是否同步 | 存储位置 |
|---------|---------|---------|
| 消息文本 | ✅ 是 | Relay + 本地 |
| 会话标题 | ✅ 是 | Relay + 本地 |
| 消息时间戳 | ✅ 是 | Relay + 本地 |
| 发送设备信息 | ✅ 是 | Relay + 本地 |
| 文件元数据（名称/大小） | ✅ 是 | Relay + 本地 |
| 文件内容 | ❌ 否 | 仅本地 |
| 截图 | ❌ 否 | 仅本地 |
| API Key / 配置 | ❌ 否 | 仅本地 |
| 记忆数据 | ❌ 否 | 仅本地 |

### 3.3 同步流程

```mermaid
sequenceDiagram
    participant DeviceA as 设备 A (Web)
    participant Relay as nanoMuse Cloud
    participant DeviceB as 设备 B (Android)

    Note over DeviceA,DeviceB: 开启会话同步后

    DeviceA->>Relay: POST /v1/sync/push<br/>(新消息)
    Relay->>Relay: 存储到 sync store
    Relay->>DeviceB: WebSocket: sync 事件
    DeviceB->>Relay: GET /v1/sync/changes<br/>?cursor={last}
    Relay->>DeviceB: 返回新消息
    DeviceB->>DeviceB: 更新本地 UI

    Note over DeviceA,DeviceB: 实时状态同步
    DeviceA->>Relay: POST /v1/sync/working<br/>(开始处理)
    Relay->>DeviceB: WebSocket: working 事件
    DeviceB->>DeviceB: 显示 "Web 正在工作..."
    DeviceA->>Relay: POST /v1/sync/working<br/>(完成处理)
    Relay->>DeviceB: WebSocket: working=false
    DeviceB->>DeviceB: 移除工作状态
```

---

## 四、API 端点

### 4.1 推送会话变更

```http
POST /v1/sync/push
Authorization: Bearer {token}
Content-Type: application/json

{
  "conversation_id": "main",
  "messages": [
    {
      "role": "user",
      "text": "你好",
      "timestamp": "2026-11-05T10:00:00Z",
      "device_id": "web-abc123"
    }
  ],
  "cursor": 12345
}
```

### 4.2 拉取变更

```http
GET /v1/sync/changes?cursor={last_cursor}&limit=100
Authorization: Bearer {token}
```

响应:
```json
{
  "changes": [
    {
      "conversation_id": "main",
      "messages": [...],
      "cursor": 12346,
      "from_device": "android-xyz789"
    }
  ],
  "next_cursor": 12346
}
```

### 4.3 工作状态报告

```http
POST /v1/sync/working
Authorization: Bearer {token}
Content-Type: application/json

{
  "conversation_id": "main",
  "working": true,
  "state": "working",
  "detail": "正在搜索网络..."
}
```

### 4.4 删除同步数据

```http
POST /v1/sync/delete
Authorization: Bearer {token}
```

---

## 五、WebSocket 实时推送

### 5.1 连接

设备启动时建立 WebSocket 连接：

```javascript
const ws = new WebSocket('wss://cloud.nanomuse.cn/ws');

// 认证
ws.send(JSON.stringify({
  kind: 'auth',
  token: 'your-api-token'
}));
```

### 5.2 事件类型

#### sync 事件 - 会话更新

```json
{
  "kind": "sync",
  "what": "conversations",
  "cursor": 12345,
  "from": "device-id-xxx"
}
```

#### working 事件 - 工作状态

```json
{
  "kind": "working",
  "cid": "main",
  "from": "device-id-xxx",
  "device_name": "Pixel 8",
  "working": true,
  "state": "working",
  "detail": "正在搜索网络...",
  "at": "2026-11-05T10:00:00Z"
}
```

#### hub 事件 - 设备状态

```json
{
  "kind": "hub",
  "devices": [
    {
      "id": "web-abc123",
      "name": "Chrome",
      "kind": "web",
      "online": true
    },
    {
      "id": "android-xyz789",
      "name": "Pixel 8",
      "kind": "phone",
      "online": true
    }
  ]
}
```

---

## 六、数据流向图

```mermaid
graph TB
    subgraph DeviceA["设备 A (Web)"]
        LocalDB_A["本地数据库<br/>threads.db"]
        SyncClient_A["同步客户端"]
        UI_A["用户界面"]
    end

    subgraph DeviceB["设备 B (Android)"]
        LocalDB_B["本地数据库<br/>threads.db"]
        SyncClient_B["同步客户端"]
        UI_B["用户界面"]
    end

    subgraph Cloud["nanoMuse Cloud"]
        SyncStore["同步存储<br/>SQLite"]
        EventBus["事件总线"]
        WSServer["WebSocket 服务器"]
    end

    UI_A -->|发送消息| SyncClient_A
    SyncClient_A -->|POST /sync/push| SyncStore
    SyncStore -->|存储| SyncStore
    SyncStore -->|触发| EventBus
    EventBus -->|推送| WSServer
    WSServer -->|sync 事件| SyncClient_B
    SyncClient_B -->|GET /sync/changes| SyncStore
    SyncStore -->|返回数据| SyncClient_B
    SyncClient_B -->|写入| LocalDB_B
    LocalDB_B -->|更新| UI_B

    style DeviceA fill:#d0ebff
    style DeviceB fill:#d0ebff
    style Cloud fill:#d3f9d8
```

---

## 七、配置示例

### 7.1 Android 设备

```
Settings → nanoMuse Cloud
├── 账号：user@example.com ✅
├── Sync conversations: ON ✅
├── Also sync side chats: OFF
├── 已登录设备：
│   ├── Chrome (Web) - 最后使用：刚刚
│   ├── Pixel 8 (本设备) - 最后使用：刚刚
│   └── MacBook (Desktop) - 最后使用：1小时前
└── 支出：¥0.00 / ¥10.00 (本月额度)
```

### 7.2 Web 设备

```
Settings → Connections
├── nanoMuse Cloud
│   ├── 账号：user@example.com ✅
│   ├── Sync conversations: ON ✅
│   └── 服务器：https://cloud.nanomuse.cn
└── 其他提供商：
    ├── Qwen (自有 Key)
    └── Local (Ollama)
```

---

## 八、故障排查

### 8.1 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| 消息不同步 | 同步开关关闭 | 开启 `Sync conversations` |
| 延迟较高 | 网络问题 | 检查 WebSocket 连接 |
| 只有部分消息同步 | cursor 丢失 | 重启应用重新拉取 |
| 显示 "Relay 连接失败" | 服务器不可达 | 检查网络和服务器地址 |
| 设备列表不显示 | 未登录或 Token 过期 | 重新登录 |

### 8.2 调试命令

**Web 设备**:
```javascript
// 浏览器开发者工具 → Console
// 查看 WebSocket 消息
// 查看 Network → WS 标签
```

**Android 设备**:
```
Settings → nanoMuse Cloud → 查看连接状态
// 或查看日志
adb logcat | grep nanomuse
```

**本地运行时**:
```bash
# 查看同步状态
curl http://localhost:8787/api/sync/state \
  -H "Authorization: Bearer nanomuse-web-token-2026"

# 手动触发同步
curl -X POST http://localhost:8787/api/sync/pull \
  -H "Authorization: Bearer nanomuse-web-token-2026"
```

---

## 九、隐私与安全

### 9.1 数据保护

| 措施 | 说明 |
|------|------|
| 传输加密 | HTTPS + WSS (TLS) |
| 存储加密 | 会话文本加密存储 |
| Token 认证 | 每个设备独立的 API Token |
| 可撤销 | 可在任一设备撤销其他设备的访问 |

### 9.2 数据删除

| 操作 | 影响范围 |
|------|---------|
| 关闭同步开关 | 删除 relay 上的所有同步数据 |
| 注销账号 | 删除所有数据（本地 + relay） |
| 撤销设备 | 该设备无法再访问账户 |
| 删除账号 | 永久删除所有数据 |

---

## 十、技术细节

### 10.1 增量同步

使用 cursor 机制避免重复同步：

```python
# 伪代码
last_cursor = get_local_cursor()
changes = fetch_changes(cursor=last_cursor)
for change in changes:
    apply_to_local_db(change)
    update_local_cursor(change.cursor)
```

### 10.2 冲突处理

当多台设备同时修改同一会话时：

- 基于时间戳排序
- 后到达的消息追加到末尾
- 不支持编辑/删除已同步的消息

### 10.3 性能优化

| 优化 | 说明 |
|------|------|
| 增量同步 | 只同步 cursor 之后的变更 |
| WebSocket 推送 | 避免轮询，近实时通知 |
| 本地缓存 | 优先读取本地数据库 |
| 批量推送 | 多条消息合并推送 |

---

## 十一、总结

### 11.1 核心要点

1. **统一账户**: 所有设备登录同一 nanoMuse Cloud 账户
2. **同步开关**: 默认开启，可在设置中控制
3. **实时推送**: WebSocket 实现近实时同步
4. **增量同步**: 基于 cursor 避免重复
5. **隐私保护**: 文件/截图保留在本地，仅同步文本

### 11.2 数据流向

```
用户输入 → 本地存储 → 推送到 Relay → WebSocket 推送 → 其他设备拉取 → 更新本地 → 显示 UI
```

### 11.3 关键 API

| 端点 | 用途 |
|------|------|
| `POST /v1/sync/push` | 推送会话变更 |
| `GET /v1/sync/changes` | 拉取其他设备的变更 |
| `POST /v1/sync/working` | 报告工作状态 |
| `POST /v1/sync/delete` | 删除同步数据 |

---

## 附录

### A. 相关文件

| 文件 | 说明 |
|------|------|
| `docs/cloud.md` | Cloud 功能说明 |
| `docs/hub.md` | Hub 协议文档 |
| `docs/sync.md` | 同步状态机 |
| `cloud/` | Cloud 源码 |

### B. 相关配置

| 配置项 | 位置 | 说明 |
|--------|------|------|
| `NANOMUSE_CLOUD_BASE_URL` | .env / config.toml | Relay 服务器地址 |
| `Sync conversations` | App Settings | 同步开关 |
| `Also sync side chats` | App Settings | 侧对话同步 |

---

*文档完成*
