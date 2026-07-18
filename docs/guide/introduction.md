# 简介

**TeleBridge** (`/ˈtɛliˌbrɪdʒ/`) 是一个全功能的 Telegram 双向沟通机器人，用 Python 编写。

## 它做什么？

TeleBridge 充当普通用户与管理员之间的桥梁：

1. **用户** 向机器人发送消息
2. **机器人** 自动将消息转发给管理员
3. **管理员** 回复转发的消息
4. **机器人** 将回复精准送达原始用户

```
用户                机器人                管理员
 │                    │                    │
 ├── 发送消息 ───────►│                    │
 │                    ├── 转发消息 ───────►│
 │                    │                    │
 │                    │◄── 回复消息 ───────┤
 │◄── 送达回复 ───────┤                    │
```

## 核心特性

| 特性 | 说明 |
|------|------|
| 双向通讯 | 普通用户 ↔ 管理员的实时消息中转 |
| 关键字自动回复 | 可配置触发词 + 自定义回复内容 |
| 广播消息 | 向所有注册用户群发通知 |
| 内联按钮 | 菜单/自动回复/欢迎/广播均可独立配置 URL 按钮 |
| 媒体转发 | 图片、视频、文档、音频、语音、动图、贴纸全支持 |
| 交互式设置 | 全部通过 Telegram 聊天完成，无需编辑文件 |
| 底部键盘 | 管理员可自定义快捷回复键盘布局 |
| 代理支持 | 为需要代理的网络环境提供 HTTP 代理配置 |
| 一键安装 | 提供 Linux/macOS/Windows 一键安装脚本 |

## 快速上手

只需一行命令即可完成安装：

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
```

详见 [快速开始](./getting-started)。

## 技术栈

- **Python** 3.8+
- **[python-telegram-bot](https://github.com/python-telegram-bot/python-telegram-bot)** 21.0+ (底层使用 `httpx`)
- **数据存储**: JSON 文件（`users.json` + `config.json`）
- **部署方式**: 一键脚本、原生 Python、Docker、systemd

## 项目结构

```
telegram-bridge/
├── bot.py                  # 主程序
├── config.json             # 配置文件
├── requirements.txt        # Python 依赖
├── install.sh              # Linux/macOS 一键安装
├── install.ps1             # Windows 一键安装（PowerShell）
├── install.bat             # Windows 一键安装（批处理）
├── deploy.sh               # Linux root 部署脚本
├── start.sh / start.bat    # 启动脚本
├── telegram-bot.service    # systemd 服务文件
├── docker-compose.yml      # Docker Compose 配置
├── Dockerfile              # Docker 镜像构建
├── data/                   # 运行时数据
│   ├── users.json          # 用户数据
│   └── bot.log             # 运行日志
└── docs/                   # 文档源码（VitePress）
```

## 适用场景

- **客服系统**：用户咨询问题，管理员在线解答
- **反馈收集**：用户提交反馈，管理员统一处理
- **匿名沟通**：保护用户隐私，管理员看不到用户的手机号等信息
- **通知广播**：向所有用户发送重要通知或更新

## 许可证

基于 MIT 许可协议发布，详见 [LICENSE](https://github.com/aklibk86-dev/telegram-bridge/blob/main/LICENSE)。
