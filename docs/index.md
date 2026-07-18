---
layout: home

hero:
  name: TeleBridge
  text: Telegram 双向沟通机器人
  tagline: 简单、高效的用户与管理员双向消息中转桥接工具
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/getting-started
    - theme: alt
      text: 查看源码
      link: https://github.com/aklibk86-dev/telegram-bridge

features:
  - title: 双向通讯
    details: 用户发送消息给机器人，自动转发给管理员；管理员可直接回复，消息精准送达对应用户。
  - title: 关键字自动回复
    details: 支持自定义触发词与回复内容，可为每个关键字独立配置内联按钮。
  - title: 广播消息
    details: 一键向所有注册用户发送广播通知，支持附带自定义内联按钮。
  - title: 内联按钮
    details: 菜单、自动回复、欢迎语、广播消息均可独立配置 URL 内联按钮。
  - title: 媒体转发
    details: 完整支持图片、视频、文档、音频、语音、动画、贴纸等多种媒体类型。
  - title: 全交互设置
    details: 通过 Telegram 聊天即可完成全部配置，无需编辑任何文件。
---

## 一键安装

**Linux / macOS：**

```bash
curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh | bash
```

**Windows（PowerShell）：**

```powershell
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
```

脚本会自动完成环境检查、代码下载、依赖安装、配置引导和服务注册，无需任何手动操作。详见 [快速开始](./guide/getting-started)。

## 核心功能

- **🔄 双向通讯** — 用户 ↔ 管理员的实时消息中转，管理员直接回复转发消息即可送达用户
- **🤖 关键字自动回复** — 配置触发词，自动回复常见问题，减轻管理员负担
- **📢 广播通知** — 向所有注册用户群发重要通知或更新
- **🔘 内联按钮** — 在菜单、自动回复、欢迎语、广播中添加 URL 按钮
- **📷 媒体转发** — 图片、视频、文档、音频、语音、动图、贴纸全支持
- **⚙️ 交互式设置** — 全部配置通过 Telegram 聊天完成，实时生效，无需重启
- **⌨️ 自定义键盘** — 管理员可配置底部快捷回复键盘
- **🌐 代理支持** — 内置 HTTP 代理配置，适配国内服务器

## 快速导航

- [简介](./guide/introduction) — 了解 TeleBridge 的功能和架构
- [快速开始](./guide/getting-started) — 一键安装或手动部署
- [配置说明](./guide/configuration) — `config.json` 字段详解
- [功能介绍](./guide/features/two-way-messaging) — 双向通讯、自动回复、广播等
- [部署方式](./guide/deployment/linux) — Linux、Windows、Docker
- [管理员命令](./guide/admin-commands) — 所有可用命令
- [常见问题](./guide/faq) — 故障排查与使用技巧

## 技术栈

- **Python** 3.8+
- **[python-telegram-bot](https://github.com/python-telegram-bot/python-telegram-bot)** 21.0+
- **数据存储**：JSON 文件（`users.json` + `config.json`）
- **部署方式**：一键脚本、原生 Python、Docker、systemd

## 交流与反馈

- **GitHub**：[aklibk86-dev/telegram-bridge](https://github.com/aklibk86-dev/telegram-bridge)
- **交流群组**：[@kqxw_chat](https://t.me/kqxw_chat)
- **问题反馈**：[提交 Issue](https://github.com/aklibk86-dev/telegram-bridge/issues)

## 许可证

基于 MIT 许可协议发布，详见 [LICENSE](https://github.com/aklibk86-dev/telegram-bridge/blob/main/LICENSE)。
