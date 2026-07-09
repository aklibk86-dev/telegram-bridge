# TeleBridge - Telegram 双向机器人

> **TeleBridge** /ˈtɛliˌbrɪdʒ/ — 连接用户与管理员的 Telegram 沟通桥梁

一个功能完整的 Telegram 双向通信机器人，支持用户与管理员之间的实时消息转发、关键词自动回复、广播通知，以及完全可视化的交互式设置面板。

💬 **交流群组**：[https://t.me/kqxw_chat](https://t.me/kqxw_chat)

## 功能概览

| 功能 | 说明 |
|------|------|
| 双向通信 | 用户消息自动转发给管理员，管理员可直接回复 |
| 自动回复 | 用户发送消息时自动回复预设内容（可附带按钮） |
| 关键词回复 | 匹配关键词自动回复对应内容（每个关键词可独立附带按钮） |
| 广播通知 | 管理员向所有用户群发消息（可附带按钮） |
| 消息按钮 | 自动回复/欢迎消息/广播/关键词均可设置独立的 URL 内联按钮 |
| 底部键盘 | 管理员可自定义底部持久键盘 |
| 交互式设置 | 所有配置均可在 Telegram 对话中完成，无需编辑文件 |

## 项目结构

```
telebridge/
├── bot.py              # 主程序（全部功能）
├── config.json         # 配置文件（运行时可动态修改）
├── requirements.txt    # Python 依赖
├── start.bat           # Windows 启动脚本
├── start.sh            # Linux 手动启动脚本
├── deploy.sh           # Linux 一键部署脚本
├── telegram-bot.service # systemd 服务配置
├── Dockerfile          # Docker 镜像构建文件
├── docker-compose.yml  # Docker Compose 编排文件
├── .dockerignore
├── .gitignore
└── README.md           # 本文档
```

运行时自动生成：

```
users.json              # 用户数据（自动创建，勿提交）
bot.log                 # 运行日志（自动创建）
```

## 快速开始

### 1. 获取 Bot Token

在 Telegram 中搜索 [@BotFather](https://t.me/BotFather)，发送 `/newbot` 创建机器人，获取 Token。

### 2. 配置 config.json

```json
{
    "bot_token": "123456789:ABCdefGhIJKlmNoPQRsTUVwxyz",  // 替换为你的 Token
    "proxy": "",                                            // 代理地址，海外服务器留空
    "admin_username": "你的用户名"                           // 不带 @的管理员用户名
}
```

**代理说明：**

| 服务器位置 | proxy 设置 |
|-----------|-----------|
| 海外服务器 | `""` （留空，直连） |
| 国内服务器 | `"http://127.0.0.1:7890"` （你的本地代理地址） |

### 3. 安装依赖

```bash
pip install -r requirements.txt
```

### 4. 启动机器人

**Windows：**
```bash
python bot.py
# 或双击 start.bat
```

**Linux：**
```bash
python3 bot.py
# 或
bash start.sh
```

### 5. 注册管理员

启动后在 Telegram 中用管理员账号给机器人发送 `/start`，机器人会自动识别并注册管理员。

## Linux 部署

### 一键部署

```bash
sudo bash deploy.sh
```

自动完成：安装 Python → 部署到 `/opt/telegram-bot` → 创建虚拟环境 → 安装依赖 → 配置开机自启 → 启动服务。

### 手动部署

```bash
# 安装依赖
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 配置 systemd 服务
sudo cp telegram-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable telegram-bot
sudo systemctl start telegram-bot
```

### 服务管理

```bash
systemctl status telegram-bot    # 查看状态
systemctl start telegram-bot     # 启动
systemctl stop telegram-bot      # 停止
systemctl restart telegram-bot   # 重启
journalctl -u telegram-bot -f    # 实时日志
```

## Docker 部署

### 快速启动

```bash
# 1. 编辑配置文件
vim config.json    # 替换 bot_token 和 admin_username

# 2. 构建并启动
docker compose up -d --build
```

### 管理命令

```bash
docker compose up -d             # 启动
docker compose down              # 停止
docker compose restart           # 重启（修改 config.json 后执行）
docker compose logs -f           # 查看实时日志
docker compose ps                # 查看状态
```

### 数据持久化

Docker 部署的数据存储在 `./data/` 目录：

```
data/
├── users.json    # 用户数据
└── bot.log       # 运行日志
```

修改 `config.json` 后执行 `docker compose restart` 即可生效。

## 使用指南

### 管理员命令

| 命令 | 功能 |
|------|------|
| `/start` | 启动机器人，注册管理员 |
| `/settings` | 打开交互式设置面板 |
| `/menu` | 显示功能菜单（内联按钮） |
| `/broadcast <消息>` | 广播消息给所有用户 |
| `/stats` | 查看用户统计 |
| `/users` | 查看用户列表 |
| `/reply <用户ID> <消息>` | 回复指定用户 |
| `/id` | 查看自己的 Chat ID |
| `/help` | 查看帮助 |

### 快捷回复

管理员直接**回复**机器人转发的消息，即可回复对应用户，无需输入 ID。

### 交互式设置

发送 `/settings` 打开设置面板，可设置以下内容：

**自动回复设置**
- 编辑自动回复文字
- 为自动回复添加/删除/清空 URL 内联按钮
- 设置自动回复消息的自动删除时间（0=关闭，1-86400秒）

**欢迎消息设置**
- 编辑欢迎消息文字
- 为欢迎消息添加/删除/清空 URL 内联按钮

**广播通知设置**
- 发送广播消息
- 为广播消息添加/删除/清空 URL 内联按钮

**关键词管理**
- 查看/添加/删除/清空关键词
- 管理关键词：编辑回复文字、为每个关键词独立添加/删除/清空 URL 按钮

**底部键盘管理**
- 查看/添加/清空底部键盘行
- 恢复默认键盘

### 用户端体验

普通用户不显示底部键盘和菜单按钮，体验为纯对话模式：
1. 发送消息 → 触发关键词匹配（有则回复关键词内容+按钮）
2. 未匹配关键词 → 回复自动回复内容（+按钮）
3. 消息同时转发给管理员
4. 管理员回复后，用户收到回复

## 配置文件说明

### config.json 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `bot_token` | string | Bot Token（从 BotFather 获取） |
| `proxy` | string | 代理地址，留空则直连 |
| `admin_username` | string | 管理员用户名（不带 @） |
| `auto_reply` | string | 自动回复内容 |
| `auto_reply_delete_time` | int | 自动回复删除时间（秒），0=不自动删除 |
| `welcome_message` | string | 欢迎消息内容 |
| `keywords` | object | 关键词字典，键为触发词，值为 `{reply, buttons}` |
| `inline_buttons` | array | `/menu` 菜单的内联按钮 |
| `auto_reply_buttons` | array | 自动回复附带的内联按钮 |
| `welcome_buttons` | array | 欢迎消息附带的内联按钮 |
| `broadcast_buttons` | array | 广播消息附带的内联按钮 |
| `reply_keyboard` | array | 管理员底部键盘布局 |

### 按钮格式

```json
[
    {"text": "按钮显示文字", "url": "https://example.com"}
]
```

### 关键词格式

```json
{
    "你好": {
        "reply": "您好！很高兴见到您",
        "buttons": [
            {"text": "访问官网", "url": "https://example.com"}
        ]
    }
}
```

## 技术栈

- **Python 3.8+**
- **python-telegram-bot 21.0+** （Telegram Bot API 框架）
- **httpx** （HTTP 客户端，支持代理）

## 常见问题

### Q: 启动报错 TimedOut

代理未配置或代理地址错误。检查 `config.json` 中的 `proxy` 字段，确保代理可用。海外服务器设为 `""`。

### Q: 管理员收不到用户消息

管理员需先发送 `/start` 给机器人完成注册。用 `/stats` 检查是否已注册。

### Q: 修改配置后不生效

通过 `/settings` 修改的配置实时生效。手动编辑 `config.json` 后需重启机器人，或在设置面板点"重载配置"。

### Q: 如何查看自己的用户名

在 Telegram 设置中查看，或给机器人发送 `/id`。`config.json` 中的 `admin_username` 不带 `@` 符号。
