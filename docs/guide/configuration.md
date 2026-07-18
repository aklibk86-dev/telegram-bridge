# 配置说明

`config.json` 是机器人的配置文件，所有字段说明如下。

::: tip 配置方式
推荐通过 `/settings` 设置面板进行配置，所有修改实时生效。直接编辑 `config.json` 后需重启机器人或在 `/settings` 中点击「🔄 重载配置」。
:::

## 基础配置

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `bot_token` | string | ✅ | BotFather 获取的 API Token |
| `proxy` | string | ❌ | HTTP 代理地址，留空表示直连（国内服务器可设为 `http://127.0.0.1:7890`） |
| `admin_username` | string | ✅ | 管理员的 Telegram 用户名（**不要**加 `@`，不区分大小写） |

## 消息配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `auto_reply` | string | 默认自动回复文本，用户消息不匹配关键字时回复此内容；设为空字符串 `""` 则不发送自动回复 |
| `auto_reply_delete_time` | integer | 自动回复消息的自动删除时间（秒），`0` 表示不删除 |
| `welcome_message` | string | 用户首次 `/start` 时显示的欢迎消息 |

::: tip 自动回复行为
- 仅在用户消息**未匹配关键字**时发送
- 媒体消息（无 caption）不触发自动回复
- 自动回复消息**之后**，用户消息仍会转发给管理员
- 详见 [自动回复](./features/auto-reply)
:::

## 关键字配置

`keywords` 是一个对象，键为触发词（关键字），值为回复配置：

```json
{
  "keywords": {
    "帮助": {
      "reply": "这是帮助信息...",
      "buttons": [{"text": "官网", "url": "https://example.com"}]
    },
    "联系": {
      "reply": "请联系管理员 @admin",
      "buttons": []
    }
  }
}
```

每个关键字可独立配置：

| 字段 | 类型 | 说明 |
|------|------|------|
| `reply` | string | 匹配时的回复内容 |
| `buttons` | array | 附带的内联按钮（可选，可为空数组） |

### 匹配规则

- 用户消息中**包含**关键字即触发（子字符串匹配）
- **不区分大小写**
- 仅对**文字消息**或**带 caption 的媒体消息**生效
- 匹配后仍会转发给管理员（不会拦截）

## 按钮配置

| 字段 | 类型 | 说明 |
|------|------|------|
| `inline_buttons` | array | `/menu` 命令显示的按钮 |
| `auto_reply_buttons` | array | 自动回复消息附带的按钮 |
| `welcome_buttons` | array | 欢迎消息附带的按钮 |
| `broadcast_buttons` | array | 广播消息附带的按钮 |

按钮格式：

```json
[
  {"text": "按钮名称", "url": "https://example.com"}
]
```

详见 [内联按钮](./features/inline-buttons)。

## 回复键盘

`reply_keyboard` 为管理员自定义底部分行键盘：

```json
{
  "reply_keyboard": [
    ["帮助", "状态"],
    ["联系方式"]
  ]
}
```

每行一个数组，按钮按顺序排列。管理员可在聊天底部看到这些快捷按钮。

::: tip 默认键盘
如未配置 `reply_keyboard`，使用默认布局：
```
⚙️ 设置    📊 统计    👥 用户
📢 广播    ❓ 帮助    🆔 我的ID
```
:::

## 完整配置示例

```json
{
  "bot_token": "123456789:ABCdef_your_token_here",
  "proxy": "",
  "admin_username": "your_username",
  "auto_reply": "✅ 您的消息已收到，我们会尽快回复您！",
  "auto_reply_delete_time": 3,
  "welcome_message": "👋 欢迎使用机器人！\n\n您可以直接发送消息，我们会收到并回复。",
  "keywords": {
    "帮助": {
      "reply": "📋 **帮助信息**\n\n发送任意消息即可联系管理员。",
      "buttons": [
        {"text": "在线文档", "url": "https://example.com/docs"}
      ]
    },
    "价格": {
      "reply": "💰 基础套餐 $99/月",
      "buttons": [
        {"text": "查看套餐", "url": "https://example.com/pricing"}
      ]
    }
  },
  "inline_buttons": [
    {"text": "官方网站", "url": "https://example.com"},
    {"text": "联系客服", "url": "https://t.me/support"}
  ],
  "auto_reply_buttons": [
    {"text": "常见问题", "url": "https://example.com/faq"}
  ],
  "welcome_buttons": [
    {"text": "快速开始", "url": "https://example.com/start"}
  ],
  "broadcast_buttons": [
    {"text": "查看详情", "url": "https://example.com"}
  ],
  "reply_keyboard": [
    ["⚙️ 设置", "📊 统计", "👥 用户"],
    ["📢 广播", "❓ 帮助", "🆔 我的ID"]
  ]
}
```
