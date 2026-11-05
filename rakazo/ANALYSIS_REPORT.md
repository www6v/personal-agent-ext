# Rakazo 项目分析报告

> 分析日期: 2026-11-04  
> 项目版本: 0.1.0 (Beta)  
> 源码位置: `rakazo-main/`

---

## 一、项目概述

### 1.1 项目定位

**Rakazo** 是一个开源的 AI Agent 平台，专注于提供持久化的 AI 队友（Persistent Teammates）。它是 Grok Bot、Meta Muse、OpenAI Dots、Claude Duet 等产品的开源、自托管替代品。

**核心理念：**
- **拥有你的 AI 队友**: 用户完全控制自己的 AI 助手
- **持久化状态**: Bot 有独立的对话、记忆、例程和历史
- **自托管优先**: 完整核心产品可在用户自己的基础设施上运行
- **提供商中立**: 不强制绑定任何特定 LLM 或服务商

### 1.2 项目信息

| 属性 | 详情 |
|------|------|
| **开源协议** | Apache-2.0 |
| **主要语言** | TypeScript |
| **作者** | elie222 |
| **GitHub** | https://github.com/elie222/rakazo |
| **官网** | https://rakazo.com |
| **状态** | Beta |
| **包管理器** | pnpm 9.15.0 |
| **Node.js** | ^22.22.2 \|\| ^24.0.0 \|\| >=26.0.0 |

### 1.3 支持平台

| 平台 | 技术栈 | 说明 |
|------|--------|------|
| **Web** | React 19 + Vite | 主要界面 |
| **Desktop** | Electron | 桌面应用 |
| **iOS** | Expo | iPhone 应用 |
| **Android** | Expo | Android 应用 |

---

## 二、项目架构

### 2.1 系统架构图

```mermaid
graph TB
    subgraph Clients["客户端层"]
        Web["Web App<br/>(React 19 + Vite)"]
        Desktop["Desktop App<br/>(Electron)"]
        Mobile["Mobile App<br/>(Expo)"]
        WWW["Marketing Site<br/>(Astro)"]
    end

    subgraph Backend["后端服务层"]
        API["API Server<br/>(Hono + oRPC)"]
        Worker["Worker<br/>(Graphile Worker)"]
        Auth["Auth Service<br/>(Better Auth)"]
    end

    subgraph Data["数据层"]
        Postgres["PostgreSQL<br/>(Prisma ORM)"]
        Storage["Object Storage"]
    end

    subgraph Sandbox["沙箱/计算层"]
        Docker["Docker<br/>(本地)"]
        E2B["E2B<br/>(远程)"]
        Daytona["Daytona"]
        CreateOS["CreateOS"]
        Boat["Boat"]
        Railway["Railway"]
    end

    subgraph External["外部服务"]
        LLM["LLM 提供商<br/>(OpenRouter, OpenAI...)"]
        Voice["语音服务<br/>(ElevenLabs, Cartesia...)"]
        Integrations["集成服务<br/>(Composio, Pipedream)"]
        MCP["MCP 服务器"]
    end

    Web --> API
    Desktop --> API
    Mobile --> API
    WWW -.->|独立部署| Web

    API --> Postgres
    API --> Worker
    API --> Auth
    Worker --> Postgres
    Worker --> Sandbox

    API --> LLM
    API --> Voice
    API --> Integrations
    API --> MCP

    Sandbox --> Docker
    Sandbox --> E2B
    Sandbox --> Daytona
    Sandbox --> CreateOS
    Sandbox --> Boat
    Sandbox --> Railway

    style Clients fill:#d0ebff
    style Backend fill:#d3f9d8
    style Data fill:#fff3bf
    style Sandbox fill:#ffe3e3
    style External fill:#f3d9fa
```

### 2.2 Monorepo 结构

```mermaid
graph TD
    Root["rakazo/"] --> Apps["apps/<br/>应用程序"]
    Root --> Packages["packages/<br/>共享包"]
    Root --> Infra["infra/<br/>基础设施"]
    Root --> Scripts["scripts/<br/>脚本"]

    Apps --> WebApp["web/<br/>Web 应用"]
    Apps --> DesktopApp["desktop/<br/>Electron 桌面"]
    Apps --> MobileApp["mobile/<br/>Expo 移动端"]
    Apps --> ApiApp["api/<br/>API 服务"]
    Apps --> WorkerApp["worker/<br/>后台任务"]
    Apps --> WwwApp["www/<br/>营销网站"]

    Packages --> Core["core/<br/>核心逻辑"]
    Packages --> Contracts["contracts/<br/>类型契约"]
    Packages --> DB["db/<br/>数据库"]
    Packages --> Auth2["auth/<br/>认证"]
    Packages --> Memory["memory/<br/>记忆系统"]
    Packages --> UIWeb["ui-web/<br/>UI 组件"]
    Packages --> UITokens["ui-tokens/<br/>设计令牌"]
    Packages --> ChatUI["chat-ui/<br/>聊天 UI"]
    Packages --> Adapters["adapters/<br/>适配器"]
    Packages --> Testkit["testkit/<br/>测试工具"]

    Infra --> Compose["compose/<br/>Docker Compose"]
    Infra --> Sandboxes["sandboxes/<br/>沙箱配置"]
    Infra --> Railway2["railway/<br/>Railway 部署"]
    Infra --> Systemd["systemd/<br/>Systemd 服务"]

    style Root fill:#4dabf7
    style Apps fill:#51cf66
    style Packages fill:#ffd43b
    style Infra fill:#ff922b
```

### 2.3 核心包关系图

```mermaid
graph LR
    subgraph Contracts["契约层"]
        Types["类型定义"]
        RPC["RPC 契约"]
        Events["事件契约"]
    end

    subgraph Core["核心层"]
        Agent["Agent 逻辑"]
        Approval["审批系统"]
        Memory2["记忆"]
        Skills["技能"]
        BuiltinTools["内置工具"]
    end

    subgraph Data2["数据层"]
        Prisma["Prisma Schema"]
        Migrations["数据库迁移"]
    end

    subgraph Adapters2["适配层"]
        SandboxAdapter["沙箱适配器"]
        ModelAdapter["模型适配器"]
        VoiceAdapter["语音适配器"]
        IntegrationAdapter["集成适配器"]
    end

    subgraph UI["UI 层"]
        Tokens["设计令牌"]
        Components["UI 组件"]
        ChatUI2["聊天组件"]
    end

    Contracts --> Core
    Contracts --> Adapters2
    Core --> Data2
    Core --> Adapters2
    Core --> UI
    Data2 --> Adapters2

    style Contracts fill:#d0ebff
    style Core fill:#d3f9d8
    style Data2 fill:#fff3bf
    style Adapters2 fill:#ffe3e3
    style UI fill:#f3d9fa
```

---

## 三、核心功能

### 3.1 功能架构图

```mermaid
mindmap
  root((Rakazo))
    持久化 Bot
      独立对话
      持久记忆
      例程任务
      历史记录
    语音模式
      语音回复
      语音输入
      语音通话
      多供应商支持
    计算资源
      Team Computers
      Private Computers
      浏览器访问
      终端访问
      文件访问
      桌面访问
    Bot 协作
      Bot 委托
      子代理
      并行任务
    集成
      Composio
      Pipedream
      MCP 服务器
      OpenAPI
      Treg
    沙箱提供商
      Docker
      E2B
      Daytona
      CreateOS
      Boat
      Railway
    自托管
      完全可控
      数据隔离
      自带模型
```

### 3.2 Bot 生命周期

```mermaid
stateDiagram-v2
    [*] --> Created: 创建 Bot
    Created --> Idle: 初始化完成
    
    Idle --> Running: 用户发送消息
    Idle --> Scheduled: 设置例程
    
    Running --> Processing: 开始处理
    Processing --> ToolUse: 需要工具
    Processing --> Thinking: 思考中
    Processing --> Asking: 需要审批
    
    ToolUse --> Processing: 工具返回
    Thinking --> Processing: 思考完成
    Asking --> Processing: 审批通过
    Asking --> Blocked: 审批拒绝
    
    Blocked --> Processing: 重新提交
    Processing --> Responding: 生成回复
    Responding --> Running: 继续任务
    Responding --> Idle: 任务完成
    
    Scheduled --> Running: 触发例程
    
    Idle --> [*]: 删除 Bot
    Blocked --> [*]: 删除 Bot
```

### 3.3 审批流程

```mermaid
flowchart TD
    Start([Bot 请求操作]) --> CheckMode{审批模式}
    
    CheckMode -->|Never Ask| AutoAllow[自动允许]
    CheckMode -->|Auto| AutoCheck{AI 审批检查}
    CheckMode -->|Ask| ManualAsk[请求用户审批]
    
    AutoCheck -->|安全操作| AutoAllow
    AutoCheck -->|需要确认| ManualAsk
    AutoCheck -->|风险操作| ManualAsk
    
    ManualAsk --> ShowCard[显示审批卡片]
    ShowCard --> UserDecision{用户决定}
    
    UserDecision -->|批准| Allow[允许执行]
    UserDecision -->|拒绝| Block[拒绝执行]
    UserDecision -->|添加到允许列表| AllowAndRemember[允许并记住]
    UserDecision -->|添加到阻止列表| BlockAndRemember[阻止并记住]
    
    AutoAllow --> Execute[执行操作]
    Allow --> Execute
    AllowAndRemember --> UpdateLists[更新审批列表]
    UpdateLists --> Execute
    
    Block --> NotifyBot[通知 Bot]
    BlockAndRemember --> UpdateLists2[更新审批列表]
    UpdateLists2 --> NotifyBot
    NotifyBot --> End([结束])
    
    Execute --> End
    
    style Start fill:#4dabf7
    style End fill:#51cf66
    style Block fill:#ff6b6b
    style NotifyBot fill:#ffd43b
```

### 3.4 沙箱/计算资源管理

```mermaid
flowchart LR
    subgraph Providers["沙箱提供商"]
        Docker["Docker<br/>(本地)"]
        E2B2["E2B<br/>(云端)"]
        Daytona2["Daytona"]
        CreateOS2["CreateOS"]
        Boat2["Boat"]
        Railway3["Railway"]
    end

    subgraph ComputerTypes["计算机类型"]
        Team["Team Computer<br/>共享资源"]
        Private["Private Computer<br/>隔离资源"]
    end

    subgraph Resources["资源"]
        Browser["浏览器"]
        Terminal["终端"]
        Files["文件系统"]
        Desktop2["桌面环境"]
    end

    subgraph Features["特性"]
        Persistence["持久化状态"]
        Checkpoint["浏览器检查点"]
        Takeover["用户接管"]
        LazyStart["懒启动"]
        AutoRelease["自动释放"]
    end

    Providers --> ComputerTypes
    ComputerTypes --> Resources
    Resources --> Features
    
    style Providers fill:#ffe3e3
    style ComputerTypes fill:#d0ebff
    style Resources fill:#d3f9d8
    style Features fill:#f3d9fa
```

---

## 四、核心流程

### 4.1 消息处理流程

```mermaid
sequenceDiagram
    participant User as 用户
    participant Client as 客户端
    participant API as API 服务
    participant Agent as Agent
    participant LLM as LLM
    participant Tools as 工具
    participant Sandbox as 沙箱
    participant DB as 数据库

    User->>Client: 发送消息
    Client->>API: POST /rpc/chat
    API->>DB: 保存消息
    API->>Agent: 启动 Agent
    
    loop Agent 循环
        Agent->>Agent: 构建提示词
        Agent->>LLM: 请求响应
        LLM-->>Agent: 返回响应/工具调用
        
        alt 工具调用
            Agent->>API: 请求工具执行
            API->>Tools: 执行工具
            
            alt 需要沙箱
                Tools->>Sandbox: 在沙箱中执行
                Sandbox-->>Tools: 返回结果
            end
            
            Tools-->>API: 工具结果
            API->>DB: 记录结果
            API-->>Agent: 返回结果
        else 直接响应
            Agent-->>API: 返回响应
        end
    end
    
    API->>DB: 保存响应
    API-->>Client: 流式响应
    Client-->>User: 显示回复
```

### 4.2 Bot 委托流程

```mermaid
sequenceDiagram
    participant MainBot as 主 Bot
    participant API as API
    participant SubBot as 子 Bot/代理
    participant Tools as 工具
    participant Result as 结果

    MainBot->>API: 请求委托任务
    API->>API: 创建子任务
    API->>SubBot: 启动子 Bot
    
    SubBot->>SubBot: 分析任务
    SubBot->>Tools: 执行任务
    
    loop 执行循环
        Tools-->>SubBot: 返回结果
        SubBot->>SubBot: 判断是否完成
        
        alt 未完成
            SubBot->>Tools: 继续执行
        else 需要主 Bot 决策
            SubBot->>API: 请求决策
            API->>MainBot: 转发问题
            MainBot-->>API: 决策结果
            API-->>SubBot: 返回决策
        else 完成
            SubBot->>Result: 生成结果
        end
    end
    
    Result->>API: 提交结果
    API->>MainBot: 返回结果
    MainBot->>MainBot: 处理结果
```

### 4.3 记忆系统流程

```mermaid
flowchart TD
    subgraph Input["输入来源"]
        Conversation["对话内容"]
        UserInput["用户显式记忆"]
        Tools["工具结果"]
    end

    subgraph Processing["处理流程"]
        Extract["提取事实"]
        Summarize["总结内容"]
        Embed["生成向量"]
        Dedupe["去重"]
    end

    subgraph Storage["存储"]
        ShortTerm["短期记忆"]
        LongTerm["长期记忆"]
        VectorDB["向量存储"]
    end

    subgraph Retrieval["检索"]
        Query["查询"]
        Semantic["语义搜索"]
        Keyword["关键词搜索"]
        Rank["排序"]
    end

    Input --> Extract
    Extract --> Summarize
    Summarize --> Embed
    Embed --> Dedupe
    
    Dedupe --> ShortTerm
    Dedupe --> LongTerm
    Dedupe --> VectorDB
    
    Query --> Semantic
    Query --> Keyword
    Semantic --> Rank
    Keyword --> Rank
    Rank --> Context[注入上下文]
    
    ShortTerm --> Retrieval
    LongTerm --> Retrieval
    VectorDB --> Retrieval
    
    style Input fill:#d0ebff
    style Processing fill:#fff3bf
    style Storage fill:#d3f9d8
    style Retrieval fill:#f3d9fa
```

---

## 五、技术栈详解

### 5.1 前端技术栈

```mermaid
graph TB
    subgraph Web["Web 应用"]
        React["React 19"]
        Vite["Vite"]
        Tailwind["Tailwind CSS"]
        ShadcnUI["shadcn/ui"]
        BaseUI["Base UI"]
    end

    subgraph Desktop["桌面应用"]
        Electron["Electron"]
        ElectronHost["Electron 主进程"]
        Renderer["渲染进程"]
    end

    subgraph Mobile["移动应用"]
        Expo["Expo"]
        ExpoRouter["Expo Router"]
        ExpoUI["Expo UI"]
        Native["原生组件"]
    end

    subgraph Shared["共享"]
        UITokens["ui-tokens<br/>设计令牌"]
        UIWeb["ui-web<br/>Web 组件"]
        ChatUI2["chat-ui<br/>聊天组件"]
    end

    Web --> Shared
    Desktop --> Web
    Desktop --> Shared
    Mobile --> Shared
    
    style Web fill:#d0ebff
    style Desktop fill:#d3f9d8
    style Mobile fill:#fff3bf
    style Shared fill:#f3d9fa
```

### 5.2 后端技术栈

```mermaid
graph TB
    subgraph Server["服务器"]
        Hono["Hono<br/>HTTP 框架"]
        ORPC["oRPC<br/>类型安全 RPC"]
        Graphile["Graphile Worker<br/>任务队列"]
    end

    subgraph Data2["数据"]
        Postgres2["PostgreSQL<br/>主数据库"]
        Prisma2["Prisma<br/>ORM"]
        VectorExt["pgvector<br/>向量扩展"]
    end

    subgraph Auth2["认证"]
        BetterAuth["Better Auth<br/>认证框架"]
        Passkeys["Passkeys<br/>无密码认证"]
        SSO["SSO<br/>单点登录"]
    end

    subgraph Security["安全"]
        Encryption["内容加密"]
        RLS["行级安全"]
        AuditLog["审计日志"]
    end

    Server --> Data2
    Server --> Auth2
    Auth2 --> Security
    Data2 --> Security
    
    style Server fill:#d0ebff
    style Data2 fill:#d3f9d8
    style Auth2 fill:#fff3bf
    style Security fill:#ffe3e3
```

### 5.3 沙箱提供商对比

| 提供商 | 类型 | 特点 | 适用场景 |
|--------|------|------|----------|
| **Docker** | 本地 | 免费、完全控制 | 开发、私有部署 |
| **E2B** | 云端 | 快速启动、隔离 | 生产环境 |
| **Daytona** | 云端 | 开发环境 | 开发协作 |
| **CreateOS** | 云端 | 桌面环境 | 需要 GUI |
| **Boat** | 云端 | 持久化 | 长期任务 |
| **Railway** | 云端 | 集成部署 | Railway 用户 |

---

## 六、部署架构

### 6.1 自托管部署图

```mermaid
graph TB
    subgraph VPS["VPS / 服务器"]
        subgraph DockerCompose["Docker Compose"]
            API2["API 服务"]
            Worker2["Worker"]
            Web2["Web 应用"]
            Postgres3["PostgreSQL"]
            Supervisor["沙箱监管器"]
        end
        
        subgraph BotContainers["Bot 容器"]
            Bot1["Bot 1<br/>独立网络"]
            Bot2["Bot 2<br/>独立网络"]
            Bot3["Bot N<br/>独立网络"]
        end
        
        Caddy["Caddy<br/>TLS 终止"]
    end

    subgraph ExternalServices["外部服务"]
        LLM2["LLM API"]
        Voice2["语音服务"]
        Integrations2["集成服务"]
    end

    Internet([互联网]) --> Caddy
    Caddy --> Web2
    Caddy --> API2
    
    API2 --> Postgres3
    API2 --> Worker2
    Worker2 --> Supervisor
    
    Supervisor --> Bot1
    Supervisor --> Bot2
    Supervisor --> Bot3
    
    API2 --> ExternalServices
    
    Bot1 -.->|MCP| ExternalServices
    Bot2 -.->|MCP| ExternalServices
    
    style VPS fill:#f8f9fa
    style DockerCompose fill:#e9ecef
    style BotContainers fill:#d0ebff
    style ExternalServices fill:#f3d9fa
```

### 6.2 开发环境结构

```mermaid
flowchart LR
    subgraph Dev["开发环境"]
        subgraph Backend2["后端开发"]
            Node["Node.js 22+"]
            PNPM["pnpm 9"]
            TypeScript2["TypeScript 7"]
            Biome["Biome<br/>代码检查"]
        end
        
        subgraph Database["数据库"]
            PostgresDev["PostgreSQL<br/>(Docker)"]
            PrismaDev["Prisma<br/>Schema"]
        end
        
        subgraph Testing["测试"]
            Vitest["Vitest"]
            Testkit2["Testkit"]
            Playwright["Playwright"]
        end
    end

    subgraph CI2["CI/CD"]
        GitHubActions["GitHub Actions"]
        Checks["代码检查"]
        Tests["测试"]
        Build2["构建"]
        Deploy["部署"]
    end

    Dev --> CI2
    
    Backend2 --> GitHubActions
    Database --> GitHubActions
    Testing --> GitHubActions
    
    GitHubActions --> Checks
    Checks --> Tests
    Tests --> Build2
    Build2 --> Deploy
    
    style Dev fill:#d3f9d8
    style CI2 fill:#fff3bf
```

---

## 七、数据模型

### 7.1 核心实体关系图

```mermaid
erDiagram
    USER ||--o{ SPACE : owns
    USER ||--o{ BOT : creates
    SPACE ||--o{ BOT : contains
    
    BOT ||--o{ MESSAGE : has
    BOT ||--o{ MEMORY : stores
    BOT ||--o{ ROUTINE : schedules
    BOT ||--o{ COMPUTER : uses
    
    COMPUTER ||--o{ BROWSER_STATE : has
    COMPUTER ||--o{ FILE : contains
    
    MESSAGE ||--o{ ATTACHMENT : has
    MESSAGE ||--o{ TOOL_CALL : contains
    
    USER {
        string id PK
        string email
        string name
        timestamp created_at
    }
    
    SPACE {
        string id PK
        string name
        string owner_id FK
        timestamp created_at
    }
    
    BOT {
        string id PK
        string name
        string space_id FK
        string avatar_id
        jsonb settings
        timestamp created_at
    }
    
    MESSAGE {
        string id PK
        string bot_id FK
        string role
        text content
        jsonb metadata
        timestamp created_at
    }
    
    MEMORY {
        string id PK
        string bot_id FK
        text content
        vector embedding
        timestamp created_at
    }
    
    COMPUTER {
        string id PK
        string bot_id FK
        string provider
        string status
        jsonb config
    }
    
    TOOL_CALL {
        string id PK
        string message_id FK
        string tool_name
        jsonb args
        jsonb result
        string status
    }
```

### 7.2 配置管理流程

```mermaid
flowchart TD
    subgraph ConfigSources["配置来源"]
        EnvVars["环境变量"]
        SettingsUI["设置界面"]
        Defaults["默认值"]
    end

    subgraph ConfigTypes["配置类型"]
        ServerConfig["服务器配置<br/>(管理员)"]
        AccountConfig["账户配置<br/>(用户)"]
        SpaceConfig["空间配置<br/>(覆盖)"]
        BotConfig["Bot 配置<br/>(个性化)"]
    end

    subgraph ConfigItems["配置项"]
        ModelSettings["模型设置"]
        VoiceSettings["语音设置"]
        ApprovalSettings["审批设置"]
        IntegrationSettings["集成设置"]
    end

    ConfigSources --> ConfigTypes
    ConfigTypes --> ConfigItems
    
    ServerConfig -->|全局默认| ModelSettings
    AccountConfig -->|账户级| ModelSettings
    SpaceConfig -->|空间覆盖| ModelSettings
    BotConfig -->|Bot 个性化| ModelSettings
    
    style ConfigSources fill:#d0ebff
    style ConfigTypes fill:#d3f9d8
    style ConfigItems fill:#fff3bf
```

---

## 八、与竞品对比

### 8.1 架构对比图

```mermaid
graph TB
    subgraph MetaMuse["Meta Muse"]
        MM_Cloud["云端 VM"]
        MM_Meta["Meta AI"]
        MM_Client["客户端"]
        MM_Client --> MM_Cloud
        MM_Cloud --> MM_Meta
    end

    subgraph ClaudeDuet["Claude Duet"]
        CD_Cloud["Anthropic 云"]
        CD_Claude["Claude"]
        CD_Client["客户端"]
        CD_Client --> CD_Cloud
        CD_Cloud --> CD_Claude
    end

    subgraph RakazoCompare["Rakazo"]
        R_SelfHost["自托管"]
        R_AnyLLM["任意 LLM"]
        R_MultiClient["多端"]
        R_LocalComp["本地计算"]
        
        R_MultiClient --> R_SelfHost
        R_SelfHost --> R_AnyLLM
        R_SelfHost --> R_LocalComp
    end

    style MetaMuse fill:#ffe3e3
    style ClaudeDuet fill:#ffe3e3
    style RakazoCompare fill:#d3f9d8
```

### 8.2 功能对比表

| 特性 | Meta Muse | Claude Duet | Rakazo |
|------|-----------|-------------|--------|
| **开源** | ❌ | ❌ | ✅ Apache-2.0 |
| **自托管** | ❌ | ❌ | ✅ |
| **模型选择** | Meta AI | Claude | 任意 LLM |
| **数据控制** | 云端 | 云端 | 用户控制 |
| **持久化 Bot** | ✅ | ✅ | ✅ |
| **语音** | ✅ | ✅ | ✅ 多供应商 |
| **桌面控制** | ❌ | ✅ | ✅ |
| **浏览器** | ❌ | ✅ | ✅ |
| **多端** | ✅ | ✅ | ✅ Web/Desktop/Mobile |
| **Bot 委托** | ❌ | ❌ | ✅ |
| **集成** | 有限 | MCP | Composio + Pipedream + MCP |
| **沙箱选择** | 单一 | 单一 | Docker/E2B/Daytona/... |

---

## 九、开发指南

### 9.1 项目结构

```
rakazo-main/
├── apps/                    # 应用程序
│   ├── api/                # API 服务 (Hono)
│   ├── web/                # Web 应用 (React + Vite)
│   ├── desktop/            # Electron 桌面应用
│   ├── mobile/             # Expo 移动应用
│   ├── worker/             # 后台任务 (Graphile)
│   └── www/                # 营销网站 (Astro)
├── packages/               # 共享包
│   ├── core/              # 核心业务逻辑
│   ├── contracts/         # 类型契约
│   ├── db/                # Prisma Schema
│   ├── auth/              # 认证逻辑
│   ├── memory/            # 记忆系统
│   ├── adapters/          # 外部服务适配器
│   ├── ui-web/            # Web UI 组件
│   ├── ui-tokens/         # 设计令牌
│   ├── chat-ui/           # 聊天 UI 组件
│   └── testkit/           # 测试工具
├── infra/                  # 基础设施
│   ├── compose/           # Docker Compose 配置
│   ├── sandboxes/         # 沙箱镜像
│   ├── railway/           # Railway 部署
│   └── systemd/           # Systemd 服务
├── scripts/                # 构建脚本
├── docs/                   # 文档
└── examples/               # 示例
```

### 9.2 开发命令

```bash
# 安装依赖
pnpm install

# 构建沙箱镜像
pnpm sandbox:build

# 启动开发环境
pnpm dev

# 代码检查
pnpm lint
pnpm check

# 测试
pnpm test                    # 单元测试
pnpm test:integration        # 集成测试
pnpm test:e2e               # E2E 测试

# 桌面应用开发
pnpm --filter @rakazo/desktop dev

# 数据库
pnpm db:generate            # 生成 Prisma 客户端
pnpm db:migrate             # 运行迁移

# 构建
pnpm build
```

### 9.3 添加新适配器

```mermaid
flowchart LR
    subgraph Steps["开发步骤"]
        Step1["1. 定义契约<br/>contracts/"]
        Step2["2. 实现适配器<br/>adapters/"]
        Step3["3. 注册提供商<br/>composition root"]
        Step4["4. 添加测试<br/>testkit/"]
    end

    subgraph Requirements["要求"]
        R1["提供商中立接口"]
        R2["离线测试"]
        R3["动态加载"]
        R4["无供应商名称泄漏"]
    end

    Steps --> Requirements
    
    style Steps fill:#d0ebff
    style Requirements fill:#d3f9d8
```

---

## 十、路线图

### 10.1 发展规划

```mermaid
gantt
    title Rakazo 发展规划
    dateFormat  YYYY-MM-DD
    section 已完成
    Beta 发布              :done, 2026-01-01, 2026-10-01
    多沙箱提供商支持       :done, 2026-06-01, 2026-09-01
    语音模式               :done, 2026-07-01, 2026-10-01
    
    section 进行中
    稳定版本准备           :active, 2026-10-01, 60d
    更多集成               :active, 2026-10-01, 90d
    性能优化               :active, 2026-10-01, 45d
    
    section 规划中
    1.0 稳定版             :2026-12-01, 60d
    插件市场               :2027-01-01, 90d
    企业功能               :2027-02-01, 120d
```

### 10.2 功能优先级

```mermaid
quadrantChart
    title 功能优先级矩阵
    x-axis 低影响 --> 高影响
    y-axis 高成本 --> 低成本
    quadrant-1 优先做
    quadrant-2 计划做
    quadrant-3 稍后做
    quadrant-4 观望
    稳定性: [0.9, 0.8]
    更多集成: [0.7, 0.6]
    性能优化: [0.8, 0.5]
    插件市场: [0.6, 0.3]
    企业功能: [0.5, 0.2]
    AI 审批: [0.8, 0.7]
```

---

## 十一、总结与建议

### 11.1 SWOT 分析

```mermaid
graph TB
    subgraph SWOT["SWOT 分析"]
        subgraph S["优势"]
            S1[完全开源 Apache-2.0]
            S2[自托管、数据可控]
            S3[提供商中立]
            S4[Monorepo 架构清晰]
            S5[多沙箱提供商]
        end
        
        subgraph W["劣势"]
            W1[仍在 Beta]
            W2[复杂度高]
            W3[依赖较多外部服务]
        end
        
        subgraph O["机会"]
            O1[AI Agent 市场增长]
            O2[数据隐私需求]
            O3[企业自托管需求]
        end
        
        subgraph T["威胁"]
            T1[大厂竞争]
            T2[技术栈复杂]
            T3[社区规模]
        end
    end
    
    style S fill:#d3f9d8
    style W fill:#fff3bf
    style O fill:#d0ebff
    style T fill:#ffe3e3
```

### 11.2 项目亮点

1. **真正的开源替代**: Apache-2.0 协议，可商用
2. **完整的自托管方案**: 不需要任何外部服务即可运行
3. **提供商中立**: 不绑定任何 LLM 或沙箱提供商
4. **持久化 Bot**: 真正的 AI 队友，不是一次性对话
5. **多端统一**: Web/Desktop/Mobile 共享核心逻辑

### 11.3 集成建议

对于个人代理扩展项目 (`personal-agent-ext`)，可以借鉴：

1. **Monorepo 架构**: 使用 packages 分离关注点
2. **契约优先设计**: contracts 包定义清晰的接口
3. **适配器模式**: adapters 包实现提供商中立
4. **审批系统**: 三模式审批 (Never/Auto/Ask)
5. **沙箱抽象**: 统一的沙箱接口支持多提供商

### 11.4 关键文件索引

| 功能 | 文件路径 | 说明 |
|------|----------|------|
| API 入口 | `apps/api/src/` | Hono + oRPC |
| 核心逻辑 | `packages/core/src/` | Agent、审批、技能 |
| 类型契约 | `packages/contracts/src/` | 共享类型定义 |
| 数据库 | `packages/db/` | Prisma Schema |
| 适配器 | `packages/adapters/src/` | 外部服务适配 |
| UI 组件 | `packages/ui-web/` | shadcn/ui 组件 |
| 沙箱配置 | `infra/sandboxes/` | Docker 镜像 |
| 部署配置 | `infra/compose/` | Docker Compose |

---

## 附录

### A. 相关资源

| 资源 | 链接 |
|------|------|
| GitHub | https://github.com/elie222/rakazo |
| 官网 | https://rakazo.com |
| Discord | https://discord.gg/RWwKa2Sn7h |
| App Store | https://apps.apple.com/app/rakazo/id6801531099 |
| Google Play | https://play.google.com/store/apps/details?id=com.rakazo.app |

### B. 技术依赖

| 类别 | 技术 |
|------|------|
| **前端框架** | React 19, Vite, Tailwind CSS |
| **桌面** | Electron |
| **移动端** | Expo |
| **后端** | Hono, oRPC |
| **数据库** | PostgreSQL, Prisma |
| **认证** | Better Auth |
| **任务队列** | Graphile Worker |
| **代码质量** | Biome, TypeScript |
| **测试** | Vitest, Playwright |
| **构建** | Turbo, pnpm |

### C. 致谢

- PromptLayer
- Inbox Zero
- ConnectorMap
- CodeRabbit
- Greptile
- Snyk

---

*报告完成 - 包含 Mermaid 架构图、流程图、时序图、ER 图等可视化内容*
