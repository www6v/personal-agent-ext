# nanoMuse 侧边栏导航功能后端实现分析

> 分析日期: 2026-11-04  
> 分析对象: 侧边栏导航图标对应的后端功能实现  
> 源码位置: `nanomuse/server/`, `nanomuse/goals/`, `nanomuse/memory/`, `nanomuse/hub/`

---

## 一、后端架构总览

侧边栏的每个导航项都对应着后端的一套完整服务：数据存储、API 端点、业务逻辑。

```mermaid
graph TD
    subgraph Frontend["前端侧边栏"]
        Chat["💬 Chat<br/>聊天"]
        Feed["📰 Feed<br/>动态"]
        Ideas["💡 Ideas<br/>灵感"]
        Goals["☑️ Goals<br/>目标"]
        Library["⊞ Library<br/>库"]
        Devices["📱 Devices<br/>设备"]
    end

    subgraph API["FastAPI 路由层"]
        ChatAPI["/api/threads<br/>/api/threads/{id}/send"]
        FeedAPI["/api/feed<br/>/api/feed/posts"]
        IdeasAPI["/api/ideas"]
        GoalsAPI["/api/goals<br/>/api/goals/{id}"]
        FilesAPI["/api/files"]
        HubAPI["/api/connections<br/>Hub WebSocket"]
    end

    subgraph Service["MuseService 服务层"]
        ThreadSvc["线程管理<br/>消息处理"]
        FeedSvc["Feed 生成<br/>定时任务"]
        IdeasSvc["灵感生成<br/>LLM 调用"]
        GoalSvc["目标管理<br/>计划调度"]
        FileSvc["工作区文件<br/>列表/读取"]
        HubSvc["设备连接<br/>状态同步"]
    end

    subgraph Storage["数据存储层"]
        SQLite["SQLite<br/>threads.db, goals.db"]
        JSON["JSON 文件<br/>feed_posts.json, ideas.json"]
        FS["文件系统<br/>workspace/"]
    end

    Chat --> ChatAPI --> ThreadSvc --> SQLite
    Feed --> FeedAPI --> FeedSvc --> JSON
    Ideas --> IdeasAPI --> IdeasSvc --> JSON
    Goals --> GoalsAPI --> GoalSvc --> SQLite
    Library --> FilesAPI --> FileSvc --> FS
    Devices --> HubAPI --> HubSvc

    style Frontend fill:#d0ebff
    style API fill:#d3f9d8
    style Service fill:#fff3bf
    style Storage fill:#ffe3e3
```

---

## 二、核心数据模型

### 2.1 状态快照 (State Snapshot)

后端通过 `state()` 方法向前端发送完整状态，包含所有侧边栏功能的数据：

```python
# nanomuse/server/service.py
def state(self) -> dict[str, Any]:
    return {
        "version": __version__,
        "profile": self.profile.to_dict(),           # Agent 配置
        "status": self.ui.overall_status(),          # 运行状态
        "threads": [t.meta() for t in self.visible_threads()],  # 聊天线程
        "pending_approvals": [...],                  # 待审批 (Chat 徽章)
        "goals": [goal_to_dict(g) for g in self.app.goals.list()],  # 目标列表
        "settings": self.settings_view(),            # 设置
        "hub": self.hub.view(),                      # 设备信息 (Devices)
        # ...
    }
```

### 2.2 数据流图

```mermaid
sequenceDiagram
    participant Client as 前端
    participant WS as WebSocket /ws
    participant API as REST API
    participant Service as MuseService
    participant Store as 存储

    Note over Client: 页面加载
    Client->>API: GET /api/state
    API->>Service: state()
    Service->>Store: 读取所有数据
    Store-->>Service: 返回数据
    Service-->>API: 状态快照
    API-->>Client: JSON 响应

    Note over Client: 实时更新
    Service->>WS: publish({"kind": "goals"})
    WS-->>Client: 推送更新
    Client->>Client: 更新徽章数字
```

---

## 三、Chat (聊天) 后端实现

### 3.1 架构

```mermaid
graph TD
    subgraph Thread["线程管理"]
        MainThread["主线程 'main'"]
        SideThread["侧线程<br/>(目标/触发器)"]
    end

    subgraph Agent["Agent 循环"]
        MuseAgent["MuseAgent<br/>LLM 调用"]
        Tools["工具执行<br/>Sentinel 控制"]
        Timeline["事件时间线"]
    end

    subgraph Storage["持久化"]
        ThreadDB["threads.db<br/>SQLite"]
        Files["附件文件"]
    end

    MainThread --> MuseAgent --> Tools
    MuseAgent --> Timeline
    Timeline --> ThreadDB
    SideThread --> MuseAgent

    style Thread fill:#d0ebff
    style Agent fill:#d3f9d8
    style Storage fill:#fff3bf
```

### 3.2 核心数据结构

```python
# nanomuse/server/service.py
@dataclass
class Thread:
    id: str                    # 线程 ID，主线程为 "main"
    title: str                 # 显示标题
    created_at: str           # 创建时间
    updated_at: str           # 更新时间
    timeline: Timeline        # 事件时间线 (消息、工具调用、审批)
    agent: MuseAgent          # 绑定到线程的 Agent 实例
    inbox: asyncio.Queue      # 消息队列 (异步处理)
    worker: asyncio.Task      # 后台工作协程
    busy: bool                # 是否正在处理
    purposes: dict            # 后台任务标签 (如 "goal work")
    device: str | None        # 目标设备 (跨设备聊天)
```

### 3.3 API 端点

```python
# nanomuse/server/api.py
POST /api/threads              # 创建新线程
GET  /api/threads              # 列出所有线程
GET  /api/threads/{id}/events  # 获取时间线事件 (?limit&before)
POST /api/threads/{id}/send    # 发送消息 (非阻塞)
POST /api/approvals/{id}       # 审批工具调用
```

### 3.4 消息处理流程

```mermaid
flowchart TD
    Start([用户发送消息]) --> Queue["加入 inbox 队列"]
    Queue --> Check{线程是否 busy?}
    Check -->|否| Spawn["启动 worker 协程"]
    Check -->|是| Wait["等待当前任务完成"]
    Wait --> Spawn
    Spawn --> Loop{循环处理 inbox}
    Loop --> Pop["取出消息"]
    Pop --> Agent["MuseAgent.process()"]
    Agent --> LLM["调用 LLM"]
    LLM --> ToolCheck{需要工具?}
    ToolCheck -->|是| Sentinel["Sentinel 检查权限"]
    Sentinel -->|需审批| Approval["创建审批请求<br/>pending_approvals"]
    Sentinel -->|允许| Execute["执行工具"]
    Execute --> LLM
    ToolCheck -->|否| Reply["生成回复"]
    Approval --> WaitApproval["等待用户审批"]
    WaitApproval --> Execute
    Reply --> Save["保存到 Timeline"]
    Save --> Emit["发布事件到 WebSocket"]
    Emit --> Loop
    Approval --> Loop

    style Start fill:#4dabf7
    style Approval fill:#ffd43b
```

### 3.5 徽章数据来源

Chat 图标的徽章显示 `pendingApprovals`，来自：

```python
# 从 state() 中提取待审批列表
"pending_approvals": [
    ev for t in self.visible_threads()
    for ev in t.timeline.events
    if ev.get("type") == "approval" and ev.get("status") == "pending"
]
```

---

## 四、Feed (动态) 后端实现

### 4.1 架构

Feed 是 Agent 主动为用户生成的内容，无需用户请求。

```mermaid
graph TD
    subgraph Sources["数据来源"]
        Memory["记忆<br/>MemoryStore"]
        Goals["目标<br/>GoalStore"]
        Calendar["日历事件"]
        Recent["最近对话"]
        Profile["用户配置"]
    end

    subgraph Generation["内容生成"]
        Prompt["构建上下文<br/>_feed_context()"]
        LLM["LLM 生成<br/>write_feed_posts()"]
        Parse["解析 JSON<br/>_parse_posts()"]
    end

    subgraph Storage["存储"]
        JSON["feed_posts.json"]
        Push["推送通知"]
    end

    Sources --> Prompt
    Prompt --> LLM --> Parse --> JSON
    Parse --> Push

    style Sources fill:#d0ebff
    style Generation fill:#d3f9d8
    style Storage fill:#fff3bf
```

### 4.2 数据模型

```python
# feed_posts.json 结构
{
    "instructions": "用户自定义的 Feed 偏好",
    "daily": true,                    # 是否每日生成
    "time": "08:00",                  # 生成时间 (本地时间)
    "generated_at": "2026-11-04T00:00:00Z",  # 上次生成时间
    "posts": [
        {
            "id": "post_xxx",
            "title": "标题 (最多10词)",
            "body": "Markdown 正文 (60-160词)",
            "area": "planning|research|goals|...",
            "prompt": "后续问题",
            "ts": "时间戳"
        }
    ]
}
```

### 4.3 定时生成逻辑

```python
# nanomuse/server/service.py
def feed_posts_due(self) -> bool:
    """判断是否需要生成新的 Feed"""
    if self._writing_feed:
        return False
    data = self.feed_posts()
    if not data["daily"]:
        return False
    
    # 需要有足够的内容才能生成
    known = (
        bool(data["instructions"])
        or bool(self.app.goals.list("active"))
        or bool(self.connections.data.get("onboarded"))
    )
    if not known and self.app.memory is not None:
        known = self.app.memory.count() >= 5
    
    if not known:
        return False
    
    # 检查是否到了生成时间
    last = data.get("generated_at")
    # ... 时间计算逻辑
    return written < self.feed_scheduled_at()

async def write_feed_posts(self, n: int = 3) -> dict[str, Any]:
    """生成新的 Feed 帖子"""
    # 1. 构建上下文
    context = self._feed_context()  # 记忆、目标、日历、最近对话
    
    # 2. 调用 LLM
    prompt = FEED_PROMPT.format(
        name=self.profile.name,
        n=n,
        instructions=data["instructions"],
        context="\n".join(context),
        language=self.feed_language(),
    )
    response = await self.app.llm.ask_complete([Message.user(prompt)])
    
    # 3. 解析并保存
    posts = _parse_posts(response.content)
    data["posts"] = [*posts, *data["posts"]]
    self._save_feed(data)
    
    # 4. 发送推送通知
    self.push.notify(...)
```

### 4.4 Feed 聚合 API

```python
def feed(self, limit: int = 60) -> list[dict[str, Any]]:
    """聚合所有后台活动，不仅是 Feed 帖子"""
    items = []
    for t in self.threads.values():
        items.extend(self._feed_of(t))  # 从每个线程提取后台事件
    items.sort(key=lambda i: i["ts"], reverse=True)
    return items[:limit]

def _feed_of(self, t: Thread) -> list[dict[str, Any]]:
    """从线程中提取后台事件"""
    # 包括：
    # - 后台任务的结果 (background)
    # - 生成的文件 (artifact)
    # - 待审批请求 (approval)
    # - Agent 问题 (question)
```

### 4.5 API 端点

```python
GET  /api/feed              # 获取聚合的 Feed 事件
GET  /api/feed/posts        # 获取生成的帖子和配置
PUT  /api/feed/instructions # 设置 Feed 偏好
POST /api/feed/posts/refresh # 立即生成新帖子
```

---

## 五、Ideas (灵感) 后端实现

### 5.1 架构

Ideas 是 Agent 基于用户数据生成的个性化建议。

```mermaid
graph TD
    subgraph Input["输入数据"]
        Memory["记忆 (30条)"]
        Goals["活跃目标 (8个)"]
        Recent["最近对话 (8条)"]
        Profile["用户配置"]
    end

    subgraph Generation["生成逻辑"]
        Check{有足够数据?}
        Starter["STARTER_IDEAS<br/>预设模板"]
        LLM["LLM 生成<br/>refresh_ideas()"]
        Parse["解析 JSON"]
    end

    subgraph Output["输出类型"]
        Chat["chat: 一次性对话"]
        Routine["routine: 每日任务"]
        Goal["goal: 长期目标"]
    end

    Input --> Check
    Check -->|否| Starter
    Check -->|是| LLM
    LLM --> Parse --> Output

    style Input fill:#d0ebff
    style Generation fill:#d3f9d8
    style Output fill:#fff3bf
```

### 5.2 预设灵感模板

```python
# nanomuse/server/service.py
STARTER_IDEAS = [
    {
        "title": "Plan my week",
        "detail": "Tell me what's on your plate and I'll turn it into a realistic plan.",
        "prompt": "Help me plan my week. Ask me what I need to get done...",
        "area": "planning",
        "kind": "chat",
    },
    {
        "title": "A morning brief",
        "detail": "Before you leave each morning: the weather, the first thing...",
        "prompt": "Morning brief: check today's weather...",
        "area": "planning",
        "kind": "routine",
        "time": "07:30",
    },
    # ... 更多模板
]
```

### 5.3 数据结构

```python
# ideas.json 结构
{
    "generated_at": "2026-11-04T00:00:00Z",
    "source": "model" | "starter",  # 来源：LLM 生成或预设
    "ideas": [
        {
            "title": "标题 (最多8词)",
            "detail": "描述 (最多300字符)",
            "prompt": "点击后发送的消息",
            "area": "planning|research|goals|money|health|home|learning|people|files|fun",
            "kind": "chat|routine|goal",
            "time": "HH:MM (仅 routine)",
            "category": "goals 专用类别"
        }
    ]
}
```

### 5.4 生成逻辑

```python
async def refresh_ideas(self, n: int = 5) -> dict[str, Any]:
    """生成个性化灵感"""
    # 1. 收集上下文
    context_lines = []
    if self.app.memory is not None:
        for m in self.app.memory.all(limit=30):
            context_lines.append(f"- memory ({m.category}): {m.content}")
    for g in self.app.goals.list("active")[:8]:
        context_lines.append(f"- goal: {g.title} ...")
    # ... 添加最近对话
    
    # 2. 无数据时返回预设
    if not context_lines:
        data = {"generated_at": now_iso(), "source": "starter", "ideas": STARTER_IDEAS}
        self._ideas_file().write_text(json.dumps(data), "utf-8")
        return data
    
    # 3. 调用 LLM 生成
    prompt = IDEAS_PROMPT.format(
        name=self.profile.name,
        n=n,
        context="\n".join(context_lines),
        language=self.feed_language(),
    )
    response = await self.app.llm.ask_complete([Message.user(prompt)])
    ideas = _parse_ideas(response.content)
    
    # 4. 保存并返回
    data = {
        "generated_at": now_iso(),
        "source": "model" if ideas else "starter",
        "ideas": ideas or STARTER_IDEAS,
    }
    self._ideas_file().write_text(json.dumps(data), "utf-8")
    return data
```

### 5.5 API 端点

```python
GET /api/ideas            # 获取灵感列表 (?refresh=1 强制刷新)
```

---

## 六、Goals (目标) 后端实现

### 6.1 架构

Goals 是长期任务跟踪系统，支持步骤分解、进度追踪和计划调整。

```mermaid
graph TD
    subgraph Model["数据模型"]
        Goal["Goal<br/>目标"]
        Step["Step<br/>步骤"]
        Proposal["Proposal<br/>计划变更"]
    end

    subgraph Operations["操作"]
        Create["创建目标"]
        Advance["推进步骤"]
        CheckIn["签到提醒"]
        Propose["Agent 提议变更"]
    end

    subgraph Background["后台调度"]
        Scheduler["目标调度器<br/>定时推进"]
        Reminder["签到提醒<br/>check_in"]
    end

    Goal --> Step
    Goal --> Proposal
    Create --> Goal
    Advance --> Step
    CheckIn --> Reminder
    Propose --> Proposal
    Scheduler --> Advance
    Reminder --> CheckIn

    style Model fill:#d0ebff
    style Operations fill:#d3f9d8
    style Background fill:#fff3bf
```

### 6.2 数据模型

```python
# nanomuse/goals/store.py
@dataclass
class Goal:
    id: str
    title: str
    description: str
    status: str              # active | paused | done | cancelled
    created_at: str
    updated_at: str
    steps: list[Step]        # 步骤列表
    notes: str               # 备注
    category: str            # health|finance|career|learning|...
    due: str                 # 截止日期 (ISO date)
    check_in: str            # 签到频率 (daily|weekdays|weekly|monthly)
    next_check_in: str       # 下次签到时间
    proposal: dict | None    # 待审批的计划变更

@dataclass
class Step:
    id: str
    goal_id: str
    idx: int                 # 顺序
    title: str
    status: str              # pending|in_progress|done|blocked|skipped
    note: str
    updated_at: str
```

### 6.3 数据库 Schema

```sql
-- nanomuse/goals/store.py
CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'active',
    notes TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS steps (
    id TEXT PRIMARY KEY,
    goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    idx INTEGER NOT NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    note TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL
);
```

### 6.4 签到调度

```python
def next_check_in(spec: str, after: datetime | None = None) -> datetime | None:
    """计算下次签到时间"""
    parsed = parse_check_in(spec)
    if parsed is None:
        return None
    cadence, anchor, hour, minute = parsed
    now = (after or datetime.now()).astimezone()
    
    for _ in range(62):  # 扫描两个月
        candidate = datetime(day.year, day.month, day.day, hour, minute, tzinfo=now.tzinfo)
        fits = (
            cadence == "daily"
            or (cadence == "weekdays" and day.weekday() < 5)
            or (cadence == "weekly" and day.weekday() == anchor)
            or (cadence == "monthly" and day.day == (anchor or 1))
        )
        if fits and candidate > now:
            return candidate
        day += timedelta(days=1)
    return None
```

### 6.5 API 端点

```python
GET    /api/goals                        # 列出目标 (?status&category)
POST   /api/goals                        # 创建目标
GET    /api/goals/{id}                   # 获取单个目标
PATCH  /api/goals/{id}                   # 更新目标
DELETE /api/goals/{id}                   # 删除目标
POST   /api/goals/{id}/advance           # 推进到下一步
POST   /api/goals/{id}/steps             # 添加步骤
POST   /api/goals/{id}/check-in          # 签到
POST   /api/goals/{id}/proposal/accept   # 接受计划变更
DELETE /api/goals/{id}/proposal          # 拒绝计划变更
```

### 6.6 徽章数据来源

Goals 图标的徽章显示 `proposals` (待审批的计划变更数量)：

```python
proposals = state.goals.filter((g) => g.proposal && g.status !== "cancelled").length;
```

---

## 七、Library (库) 后端实现

### 7.1 架构

Library 展示 Agent 工作区中的文件，分为 Artifacts (文档) 和 Media (媒体)。

```mermaid
graph TD
    subgraph Workspace["工作区"]
        Files["文件系统<br/>workspace/"]
        Upload["上传文件"]
        Generated["Agent 生成的文件"]
    end

    subgraph Service["文件服务"]
        List["list_files()<br/>扫描目录"]
        Resolve["resolve_workspace_path()<br/>路径安全检查"]
        Classify["文件分类<br/>isMedia()"]
    end

    subgraph API["API 层"]
        GetList["GET /api/files"]
        GetFile["GET /api/files/{path}"]
        Upload["POST /api/files/upload"]
    end

    Workspace --> Service
    Service --> API

    style Workspace fill:#d0ebff
    style Service fill:#d3f9d8
    style API fill:#fff3bf
```

### 7.2 文件扫描逻辑

```python
# nanomuse/server/service.py
def list_files(self, limit: int = 200) -> list[dict[str, Any]]:
    """列出工作区中的所有文件"""
    ws = self.workspace()
    out = []
    
    if not ws.exists():
        return out
    
    for p in ws.rglob("*"):
        # 跳过隐藏文件
        if not p.is_file() or any(part.startswith(".") for part in p.relative_to(ws).parts):
            continue
        try:
            st = p.stat()
        except OSError:
            continue
        
        out.append({
            "path": p.relative_to(ws).as_posix(),
            "name": p.name,
            "size": st.st_size,
            "modified": datetime.fromtimestamp(st.st_mtime, UTC).isoformat(timespec="seconds"),
        })
        if len(out) >= 5000:
            break
    
    # 按修改时间倒序
    out.sort(key=lambda f: f["modified"], reverse=True)
    return out[:limit]

def resolve_workspace_path(self, rel: str) -> Path:
    """安全解析路径，防止目录遍历"""
    ws = self.workspace()
    target = (ws / rel).resolve()
    if target != ws and ws not in target.parents:
        raise PermissionError("path outside the workspace")
    return target
```

### 7.3 前端分类逻辑 (参考)

```typescript
// 前端根据扩展名分类
const MEDIA_EXT = new Set([
    "png", "jpg", "jpeg", "gif", "webp", "svg", "heic",  // 图片
    "mp3", "wav", "m4a", "ogg", "flac",                   // 音频
    "mp4", "mov", "webm", "mkv"                           // 视频
]);

function isMedia(name: string): boolean {
    return MEDIA_EXT.has(name.toLowerCase().split(".").pop() ?? "");
}
```

### 7.4 API 端点

```python
GET  /api/files              # 列出文件 (?limit=200)
GET  /api/files/{path}       # 获取文件内容
POST /api/files/upload       # 上传文件 (?name=)
```

---

## 八、Devices (设备) 后端实现

### 8.1 架构

Devices 通过 Hub 系统管理账户下的所有设备，支持跨设备通信。

```mermaid
graph TD
    subgraph Hub["Hub 系统"]
        Relay["Cloud Relay<br/>中继服务器"]
        Local["本地设备"]
        Remote["远程设备"]
    end

    subgraph HubService["HubService"]
        Client["HubClient<br/>WebSocket 连接"]
        Actions["动作处理<br/>shell, files, screen"]
        Tasks["任务管理<br/>跨设备任务"]
        Profile["ProfileSync<br/>配置同步"]
    end

    subgraph Communication["通信模式"]
        In["入站任务<br/>其他设备发来的请求"]
        Out["出站任务<br/>ask_device()"]
        Sync["状态同步<br/>devices 帧"]
    end

    Relay <--> Client
    Client --> Actions
    Client --> Tasks
    Client --> Profile
    Local --> In
    Local --> Out
    Remote --> Sync

    style Hub fill:#d0ebff
    style HubService fill:#d3f9d8
    style Communication fill:#fff3bf
```

### 8.2 HubService 核心

```python
# nanomuse/hub/service.py
class HubService:
    def __init__(self, svc: MuseService):
        self.svc = svc
        self.client: HubClient | None = None
        self.cloud = CloudClient(...)
        
        # 设备状态
        self._devices_seen: dict[str, bool] | None = None  # 在线状态
        
        # 跨设备任务
        self.remote_approvals: dict = {}    # 其他设备的审批
        self._relayed_approvals: dict = {}  # 本设备的审批
        
        # 配置同步
        self.profile = ProfileSync(self)
```

### 8.3 设备视图数据

```python
# nanomuse/hub/service.py
def view(self) -> dict[str, Any]:
    return {
        "enabled": self.settings.hub.enabled,
        "account": {
            "signed_in": self.signed_in,
            "email": self.settings.hub.email,
            # ...
        },
        "devices": [
            {
                "id": device["id"],
                "name": device["name"],
                "kind": device["kind"],      # desktop | phone | web
                "online": device["online"],
                "this": device["id"] == self.device_id,  # 是否当前设备
            }
            for device in self._devices
        ],
    }
```

### 8.4 跨设备任务流程

```mermaid
sequenceDiagram
    participant User as 用户
    participant Local as 本地设备
    participant Relay as Cloud Relay
    participant Remote as 远程设备

    Note over User: 在本地设备发送任务给远程设备
    User->>Local: 发送到 "厨房电脑"
    Local->>Relay: task {device: "kitchen", text: "..."}
    Relay->>Remote: 转发任务
    Remote->>Remote: 创建侧线程执行
    Remote->>Relay: events (进度、审批)
    Relay->>Local: 转发事件
    Local->>User: 显示进度

    Note over Remote: 需要审批时
    Remote->>Relay: approval request
    Relay->>Local: 转发审批请求
    Local->>User: 显示审批卡片
    User->>Local: 批准/拒绝
    Local->>Relay: approve {approved: true}
    Relay->>Remote: 转发审批结果
    Remote->>Remote: 继续执行
```

### 8.5 状态点数据来源

Devices 图标的状态点显示 `online` (在线设备数)：

```python
# 过滤条件：非当前设备、非 web 类型、在线
online = [d for d in state.hub.devices 
          if not d.this and d.kind != "web" and d.online]
```

### 8.6 API 端点

```python
GET  /api/connections          # 获取连接状态 (包括 Hub)
PUT  /api/connections/gui      # 更新 GUI 配置
# Hub 通过 WebSocket 实时通信
```

---

## 九、Settings (设置) 后端实现

### 9.1 架构

设置系统管理 Agent 配置、安全策略、连接器等。

```mermaid
graph TD
    subgraph Settings["设置类别"]
        Profile["Profile<br/>名称、头像、语调"]
        Sentinel["Sentinel<br/>安全模式、工具权限"]
        LLM["LLM<br/>模型、API Key"]
        Connectors["Connectors<br/>邮件、日历、MCP"]
        Agent["Agent<br/>语言、工作区"]
    end

    subgraph Storage["存储"]
        ConfigTOML["config.toml"]
        ConnectionsJSON["connections.json"]
        Vault["Vault<br/>密钥存储"]
    end

    subgraph API["API"]
        Get["GET /api/settings"]
        Put["PUT /api/settings"]
    end

    Settings --> Storage
    Storage --> API

    style Settings fill:#d0ebff
    style Storage fill:#d3f9d8
    style API fill:#fff3bf
```

### 9.2 Profile 数据模型

```python
# nanomuse/server/service.py
@dataclass
class Profile:
    name: str = "nanoMuse"           # Agent 名称
    avatar: str = "dragon"           # 头像类型
    emoji: str = "✨"                # 表情符号
    color: str = "#0064d4"           # 主题色
    tagline: str = ""                # 标语
    tone: str = ""                   # 语调 (formal|casual|playful|concise)
    communication: str = ""          # 沟通风格 (short|detailed|bullets)
    style: str = ""                  # 自定义风格
    user_name: str = ""              # 用户称呼
    proactivity: str = "default"     # 主动性 (off|low|default|high)
    goal_interval_minutes: int = 60  # 目标推进间隔
    quiet_hours: str = ""            # 静默时段 ("22:00-08:00")
```

### 9.3 设置视图

```python
def settings_view(self) -> dict[str, Any]:
    s = self.settings
    return {
        "version": __version__,
        "profile": self.profile.to_dict(),
        "sentinel": {
            "mode": s.sentinel.mode,           # ask | strict | auto
            "always_ask_tools": s.sentinel.always_ask_tools,
            "always_allow_tools": s.sentinel.always_allow_tools,
            "deny_tools": s.sentinel.deny_tools,
            "taint_tracking": s.sentinel.taint_tracking,
            "egress_allowlist": s.sentinel.egress_allowlist,
        },
        "sandbox": {
            "mode": s.sandbox.mode,
            "active": self.app.sandbox.active,
            "status": self.app.sandbox.status,
        },
        "llm": {
            "provider": s.llm.provider,
            "model": s.llm.model,
            "stream": s.llm.stream,
            "cloud": bool(...),
        },
        "agent": {
            "language": s.agent.language,
            "max_steps": s.agent.max_steps,
            "show_thinking": s.agent.show_thinking,
            "workspace": str(s.agent.workspace),
        },
        "connectors": {
            "email": s.connectors.email.enabled,
            "calendar": s.connectors.calendar.enabled,
            "contacts": s.connectors.contacts.enabled,
            "browser": s.browser.enabled,
            "gui": s.gui.enabled,
            "hands": s.hands.enabled,
            "mcp": [m.name for m in s.mcp.servers],
        },
        # ...
    }
```

### 9.4 API 端点

```python
GET /api/settings    # 获取所有设置
PUT /api/settings    # 更新设置
```

---

## 十、后端服务关系图

```mermaid
graph TD
    subgraph Core["核心服务"]
        MuseService["MuseService<br/>主服务协调器"]
        NanoMuseApp["NanoMuseApp<br/>应用实例"]
    end

    subgraph Agent["Agent 系统"]
        MuseAgent["MuseAgent<br/>Agent 循环"]
        Sentinel["Sentinel<br/>安全控制"]
        Tools["Tools<br/>工具集"]
    end

    subgraph Stores["数据存储"]
        MemoryStore["MemoryStore<br/>记忆"]
        GoalStore["GoalStore<br/>目标"]
        TriggerStore["TriggerStore<br/>触发器"]
        ReminderStore["ReminderStore<br/>提醒"]
    end

    subgraph Services["辅助服务"]
        HubService["HubService<br/>设备通信"]
        CodingService["CodingService<br/>代码助手"]
        PushService["PushService<br/>推送通知"]
    end

    subgraph External["外部依赖"]
        LLM["LLM<br/>语言模型"]
        SQLite["SQLite<br/>数据库"]
        FileSystem["文件系统<br/>工作区"]
        CloudRelay["Cloud Relay<br/>中继服务"]
    end

    MuseService --> NanoMuseApp
    MuseService --> HubService
    NanoMuseApp --> MuseAgent
    NanoMuseApp --> Sentinel
    MuseAgent --> Tools
    MuseAgent --> MemoryStore
    MuseAgent --> GoalStore
    MuseAgent --> TriggerStore
    MuseAgent --> ReminderStore
    MuseAgent --> LLM
    MemoryStore --> SQLite
    GoalStore --> SQLite
    TriggerStore --> SQLite
    HubService --> CloudRelay
    MuseAgent --> FileSystem

    style Core fill:#d0ebff
    style Agent fill:#d3f9d8
    style Stores fill:#fff3bf
    style Services fill:#ffe3e3
    style External fill:#e5dbff
```

---

## 十一、数据流与状态同步

### 11.1 状态更新机制

```mermaid
sequenceDiagram
    participant Service as MuseService
    participant Bus as EventBus
    participant WS as WebSocket
    participant Client as 前端

    Note over Service: 数据变更 (如目标更新)
    Service->>Bus: publish({"kind": "goals"})
    Bus->>WS: 广播事件
    WS->>Client: 推送 JSON
    
    Note over Client: 前端处理
    Client->>Client: 更新 state.goals
    Client->>Client: 重新计算徽章
    Client->>Client: 刷新 UI
```

### 11.2 EventBus 事件类型

```python
# 各类事件触发前端更新
{
    "kind": "goals"           # 目标变更 → Goals 徽章
    "kind": "feed_posts"      # Feed 更新 → Feed 徽章
    "kind": "ideas"           # 灵感更新 → Ideas 刷新
    "kind": "settings"        # 设置变更 → Settings 刷新
    "kind": "thread"          # 线程更新 → Chat 刷新
    "kind": "approval"        # 审批请求 → Chat 徽章
}
```

---

## 十二、API 端点汇总

| 功能 | 端点 | 说明 |
|------|------|------|
| **状态** | `GET /api/state` | 完整状态快照 |
| **Chat** | `GET/POST /api/threads` | 线程列表/创建 |
| | `POST /api/threads/{id}/send` | 发送消息 |
| | `POST /api/approvals/{id}` | 审批 |
| **Feed** | `GET /api/feed` | 聚合 Feed |
| | `GET /api/feed/posts` | 生成的帖子 |
| | `PUT /api/feed/instructions` | 设置偏好 |
| | `POST /api/feed/posts/refresh` | 刷新帖子 |
| **Ideas** | `GET /api/ideas` | 灵感列表 |
| **Goals** | `GET/POST /api/goals` | 目标列表/创建 |
| | `PATCH/DELETE /api/goals/{id}` | 更新/删除 |
| | `POST /api/goals/{id}/advance` | 推进 |
| | `POST /api/goals/{id}/check-in` | 签到 |
| **Library** | `GET /api/files` | 文件列表 |
| | `GET /api/files/{path}` | 文件内容 |
| | `POST /api/files/upload` | 上传 |
| **Devices** | `GET /api/connections` | 连接状态 |
| | WebSocket `/ws` | 实时通信 |
| **Settings** | `GET/PUT /api/settings` | 设置读写 |
| | `GET /api/memory` | 记忆列表 |
| | `GET /api/activity` | 活动日志 |

---

## 十三、关键实现要点

### 13.1 异步架构

```python
# 每个线程有独立的异步工作协程
@dataclass
class Thread:
    inbox: asyncio.Queue      # 消息队列
    worker: asyncio.Task      # 工作协程
    busy: bool                # 忙碌状态
```

### 13.2 安全控制

```python
# Sentinel 控制工具权限
class Sentinel:
    mode: str                    # ask | strict | auto
    always_ask_tools: list       # 总是询问的工具
    always_allow_tools: list     # 总是允许的工具
    deny_tools: list             # 禁止的工具
```

### 13.3 LLM 会话管理

```python
# 不同类型的任务使用不同的会话标识
with llm_session.run("feed"):      # Feed 生成
with llm_session.run("goal"):      # 目标推进
with llm_session.run("ideas"):     # 灵感生成
```

---

## 附录

### A. 相关源文件

| 文件 | 说明 |
|------|------|
| `nanomuse/server/service.py` | MuseService 主服务 |
| `nanomuse/server/api.py` | FastAPI 路由 |
| `nanomuse/goals/store.py` | GoalStore 目标存储 |
| `nanomuse/memory/store.py` | MemoryStore 记忆存储 |
| `nanomuse/triggers/store.py` | TriggerStore 触发器存储 |
| `nanomuse/hub/service.py` | HubService 设备通信 |
| `nanomuse/agent/core.py` | MuseAgent Agent 循环 |
| `nanomuse/config.py` | Settings 配置类 |

### B. 数据库文件

| 文件 | 内容 |
|------|------|
| `threads.db` | 线程、消息、审批 |
| `goals.db` | 目标、步骤 |
| `triggers.db` | 触发器 |
| `reminders.db` | 提醒 |
| `memory.db` | 记忆 |

### C. JSON 文件

| 文件 | 内容 |
|------|------|
| `feed_posts.json` | Feed 帖子和配置 |
| `ideas.json` | 灵感列表 |
| `connections.json` | 连接器配置 |
| `firstrun.json` | 首次运行状态 |

---

*报告完成*
