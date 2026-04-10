---
title: "接入方式"
description: "客户可以通过哪些方式使用 Knowledge Hub。"
status: "public"
---

Knowledge Hub 可以通过 Web Chat、Web Workspace 和 API 三种方式使用。对外客户介绍站点推荐使用 Web Chat。

## Web Chat

Web Chat 面向最终用户。它适合用于：

- 产品文档查询
- API 文档问答
- 客户自助支持
- 对外 Demo
- 销售和售前资料展示

Web Chat 的重点是低摩擦访问。用户不需要理解后台配置，只需要阅读文档或直接提问。

## Web Workspace

Web Workspace 面向内部团队。它适合用于：

- 创建知识空间
- 上传文档
- 选择参与问答的信源
- 保存对话产出的笔记
- 管理空间成员和访问范围

它不适合作为公开客户入口，因为它包含更多管理和协作能力。

## API

API 适合把 Knowledge Hub 接入其他业务系统，例如：

- 企业微信客服
- 销售助手
- 内部运营系统
- 客户门户
- 自动化问答流程

API 接入时应使用受限凭据，并绑定租户、项目、权限和限流策略。

## 推荐对外架构

公开访问建议采用：

```text
客户浏览器
  -> web-chat
  -> 受限后端代理或只读 API Key
  -> Knowledge Hub 项目
  -> 公开文档集合
```

不要把管理端能力暴露给外部客户。
