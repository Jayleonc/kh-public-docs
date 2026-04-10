---
title: "RAG 检索设计与 Agent 协作"
description: "Knowledge Hub 如何设计检索底盘，以及它和 Agent 如何分工。"
status: "public"
---

Knowledge Hub 当前的问答入口已经演进到 Agent-first 形态，但这并不意味着 RAG 退居次要位置。对企业知识平台来说，Agent 负责决策，RAG 负责取证；如果检索底盘不扎实，后面的多轮推理、全文阅读和引用回传都会失去基础。

## RAG 在系统里的位置

Knowledge Hub 当前将 RAG 封装成 `search_knowledge_base` 工具供 Agent 调用，而没有把它单独作为聊天入口暴露出去。这样设计的好处是：

- 检索层专注于找证据，不承担上层对话编排
- Agent 可以按需组合检索、全文阅读、目录浏览和澄清
- 检索接口仍然保持明确的参数边界，便于治理和调优

在这套分工里，RAG 解决的问题仍然很明确：把正确的片段、路径和引用交给上层。

## 1. 检索入口为什么要有明确参数合约

`search_knowledge_base` 当前不是只收一个自然语言 query。工具参数里至少区分了这些信息：

- `semantic_query`：用于向量语义检索的纯净查询
- `keywords`：错误码、版本号、专有名词、英文标识符这类必须精确命中的内容
- `strategy`：`semantic / keyword / hybrid`
- `document_ids`：将范围收紧到特定文档
- `directory`：限定某个 VFS 路径前缀

这个设计背后的想法很直接：企业知识检索不能只停留在“扔一句话进去看看能不能搜到”。有些信息适合做语义理解，有些信息必须走精确匹配。如果这层参数合约不清楚，后面的策略选择和召回质量都会很被动。

## 2. 内容进入索引前，如何切分很关键

Knowledge Hub 当前对 Markdown 文档默认启用 Header 语义切分。源码里的默认参数是：

- `chunk_size = 1000`
- `chunk_overlap = 200`
- `UseHeaderSplitting = true`
- `MaxSectionSize = 4000`

这一层的核心目标，是同时保留两种信息，而不是单纯追求更碎的切片：

- 适合向量检索的片段粒度
- 文档原本的章节层级和结构路径

对于 Git 来源或 Markdown 文档，系统会保留 `HeaderPath`；对于其他来源，再回退到字符切分。这样做的原因很现实：企业文档通常带有目录、章节和小节脉络，如果切分时把这些信息完全丢掉，后面很难回答“这段话属于哪一章”“应该跳回哪一节继续看”。

## 3. 检索不是一个策略，至少是三种

Knowledge Hub 当前支持三种基础检索策略：

- `semantic`：向量语义检索，底层使用 pgvector 的余弦距离
- `keyword`：关键词检索，优先使用 PGroonga，失败时回退到 `pg_trgm + ILIKE`
- `hybrid`：同时执行向量检索和关键词检索，再做融合

混合检索当前采用 RRF 融合，并对精确命中做额外加分。这个设计解决的是典型的企业知识问题：

- 语义检索擅长理解意思
- 关键词检索擅长命中错误码、版本号、术语和固定写法
- 混合检索用于同时兼顾召回率和准确性

这也是为什么工具参数里要单独拆出 `keywords`。如果把所有信息都塞进一个 query，检索层就很难区分“要理解语义”和“必须命中原词”。

## 4. 元数据为什么决定检索系统能不能长期演进

Knowledge Hub 的片段结果当前会携带一组比较完整的结构信息，例如：

- `project_id`
- `document_id`
- `source_type`
- `ref_id`
- `project_node_id`
- `vfs_path`
- `header_path`
- `structure_path`
- `project_node_materialized_path`
- `project_node_human_path`

这些字段的意义很大：

- `project_id` 让结果天然落在知识空间里
- `source_type` 和 `ref_id` 负责溯源
- `project_node_id` 和 `vfs_path` 负责把结果接回目录树和文档
- `header_path` 和 `structure_path` 负责把片段接回章节位置
- 路径语义字段可以继续参与过滤、PathBoost 和导航

如果片段只剩“文本 + 相似度”，系统很快会退化成一个向量垃圾桶。能不能过滤、能不能跳转、能不能回源、能不能和目录联动，几乎都取决于这层元数据合约。

## 5. 检索结果为什么还要做上下文扩展

Knowledge Hub 当前不会无脑把所有片段都扩成大上下文。系统内部有一个检索侧的 `IntentDetector`，会把问题分成：

- `code`
- `howto`
- `concept`
- `factoid`

当前策略是：

- `howto` 和 `concept` 允许扩展兄弟上下文
- `code` 和 `factoid` 保持收敛

在实现上，系统会按 `position` 拉取命中片段前后邻居，窗口默认是前后各 1 段，并受 `context_max_chars` 等参数约束。这样做的原因很简单：概念解释和步骤型问题通常需要上下文，错误码查询和代码定位则更适合保持精准。

## 6. 权限必须下沉到检索阶段

Knowledge Hub 的检索层当前会从上下文中拿到 `KnowledgeSpace`，再把 ACL 条件直接带进查询 scope。实现上采用的是 fail-safe 原则：

- 没有 `KnowledgeSpace`，直接拒绝
- 没有权限上下文，查询返回空集
- 实时使用 `document.access_policy` 做过滤

这意味着权限不依赖回答阶段“自觉克制”，而是在召回阶段就把结果收紧。对企业平台来说，这一点比某个检索技巧更关键。

## 7. 路径过滤和 Project / VFS 为什么要进入检索

Knowledge Hub 当前支持路径前缀过滤，也会在查询中把 `document`、`project`、`project_node` 一起 JOIN 进来。这层设计的价值在于，系统在找片段时并没有丢掉知识组织结构。

这样带来的直接能力包括：

- 项目内搜索
- 目录范围收紧
- 结果回跳到具体文档和节点
- PathBoost 这类路径语义增强
- 与 Git 路径、VFS 路径和前端树结构保持一致

对文档型知识平台来说，路径和组织结构本身就是检索质量的一部分。

## 8. 引用回传为什么是检索链路的一部分

Knowledge Hub 当前通过 `CitationCollector` 在 Tool 执行过程中旁路收集结构化引用，再由上层会话和前端消费。这意味着检索层输出的，不只是文本片段，还有可以回到原文的证据数据。

这样设计有两个好处：

- 回答能附带结构化引用，而不是事后再猜
- Agent 即使通过工具接口只能返回字符串，引用信息也不会丢

对企业知识场景来说，引用属于检索结果的一部分，不是附属功能。

## 9. Agent 和 RAG 是怎样协作的

Knowledge Hub 当前的协作方式可以概括成这样：

1. Agent 判断当前问题是否需要检索
2. RAG 根据 `semantic_query / keywords / strategy / path_filter` 执行受限检索
3. 检索返回片段、路径、结构信息和引用
4. 如果片段不足，Agent 再调用 `read_document` 回到全文
5. 最终回答基于检索证据和全文内容组织出来

这套分工里，Agent 负责“下一步做什么”，RAG 负责“把什么证据交出来”。两层边界清晰，平台才更容易演进。

## 为什么这一页很关键

Knowledge Hub 当前已经不缺“会调用工具的 Agent”。更关键的是，这个 Agent 背后站着一套怎样的检索底盘。RAG 的切分、策略、元数据、权限、路径和引用如果不扎实，问答层再灵活，也只是在包装一条不稳定的底层链路。
