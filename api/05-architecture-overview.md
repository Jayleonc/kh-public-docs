---
title: "架构概览"
description: "Knowledge Hub 的系统层次和核心模块。"
status: "public"
---

Knowledge Hub 的核心思路很明确：把企业知识系统拆成几个边界清晰的层，每一层只负责自己那部分问题。这样系统既能服务公开访问，也能长期演进。

## 整体链路

```text
文档源头
  -> Git Sync / Upload / Editor
  -> Document 服务
  -> 解析、分块、向量化
  -> RAG 检索层
  -> Agent 决策层
  -> Web Chat / Workspace / API
```

在这条链路里，Agent 负责“下一步怎么做”，RAG 负责“去哪里找证据”，ACL 和 RBAC 负责“当前请求能使用哪些资料”。

## 前端入口

### Web Chat

面向外部客户和最终用户，承担阅读、问答、引用查看和公开访问。

### Workspace

面向内部业务与运营团队，承担知识空间管理、文档接入、协作和内部问答。

### Admin

面向管理员，负责租户、权限、配置、审计和系统治理。

## 后端核心模块

### Project

Project 是知识空间的组织中心。它负责：

- 维护项目边界
- 绑定虚拟文件树
- 关联文档与路径
- 承接资源级访问策略

Project 这层存在以后，系统可以把“知识属于哪个空间”说清楚，权限和检索范围也更容易稳定。

### Document

Document 模块负责文档接入、解析状态、内容存储和结构映射。这里有一个很重要的设计：文档状态和索引状态是分开的。

当前源码里的文档处理状态包括：

```text
waiting -> processing -> parsing_completed -> indexing -> completed
```

索引一致性则单独维护：

```text
synced / stale / pending
```

这样做的好处是，系统能区分“文档内容是否解析完成”和“索引是否需要刷新”这两件不同的事。

### RAG

RAG 层负责纯检索工作，包括：

- 向量检索和关键词检索
- 结果重排与上下文扩展
- 路径过滤和检索范围限制
- 引用片段组织

当前版本使用 PostgreSQL + pgvector 作为向量承载层。这个选型的优点是业务数据和向量数据可以共享事务语义、运维面更收敛、成本更可控。代价也很明确：如果未来数据规模和检索复杂度继续上升，专用向量引擎会提供更大的调优空间。

### Agent

Agent 是当前知识问答主入口。源码里采用的是 `OpenAIFunctionsAgent + Executor`，并限制 `maxIterations=5`。这意味着系统允许多轮工具调用，但不会无限循环。

当前主执行链挂载的工具集有 4 个：

- `search_knowledge_base`
- `get_folder_info`
- `ask_user_clarification`
- `read_document`

工具面保持克制很重要。工具越多，Agent 的自由度越大，失控成本也越高。Knowledge Hub 当前更强调受控、可解释和可观测。

### ACL / RBAC

RBAC 负责动作权限，ACL 负责资源可见性。Knowledge Hub 的 ACL 服务采用 deny-by-default，缺少关键上下文或策略解析失败时直接拒绝。

更关键的是，ACL 不只作用在页面层。当前检索范围构造会把 `KnowledgeSpace` 转成数据库查询 scope，让无权内容在召回阶段就被排除。

### Orchestrator

Orchestrator 是跨模块协调层。它的价值在于守住一些系统级约束，比如：

- 上传时同时校验项目绑定和权限
- Git 绑定项目收紧直接上传能力
- 多模块操作保持一致性
- 目录与文档关系变更时，触发后续治理任务

这层会让代码多一层协调成本，但能换来更稳的系统边界。

### Worker

后台 Worker 负责把重任务从同步链路里拿出去，包括：

- `RAGIndexer`：文档分块和向量化
- `SummaryWorker`：摘要更新
- `VFSPathSync`：目录路径变化后的同步
- `OrphanCleaner`：孤儿资源清理

这套 Worker 设计让文档接入、结构调整和索引刷新可以异步推进。

## 为什么架构会演进成今天这样

Knowledge Hub 的演进方向很清晰：把决策权往 Agent 提升，把 RAG 收敛成检索能力，把权限和治理压进基础设施层。这样可以更好地处理复杂问答、路径导航、全文精读和权限边界。

这套架构接受了几个明确代价：

- Agent 模式的延迟和成本会高于固定流水线
- 模块分层和状态机让实现复杂度上升
- 对 Prompt、工具边界和观测链路的要求更高

这些代价换来的，是更强的复杂问题处理能力，以及更稳的企业知识治理能力。
