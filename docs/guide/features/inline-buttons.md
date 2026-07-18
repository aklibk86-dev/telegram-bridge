# 内联按钮

TeleBridge 支持在多个作用域配置 URL 内联按钮，增强消息交互性。

## 按钮作用域

| 作用域 | 配置字段 | 显示位置 |
|--------|----------|----------|
| 菜单 | `inline_buttons` | `/menu` 命令回复中 |
| 自动回复 | `auto_reply_buttons` | 默认自动回复消息中 |
| 欢迎 | `welcome_buttons` | 用户 `/start` 的欢迎消息中 |
| 广播 | `broadcast_buttons` | 广播消息中 |
| 关键字 | `keywords[key].buttons` | 该关键字触发后的回复中 |

## 按钮格式

每个按钮是一个 JSON 对象：

```json
{
  "text": "显示文本",
  "url": "https://example.com"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `text` | string | 按钮上显示的文本 |
| `url` | string | 点击按钮后打开的 URL |

::: warning URL 限制
- URL 必须以 `http://` 或 `https://` 开头
- Telegram 仅支持 URL 类型的内联按钮（不支持 callback 按钮）
- URL 会在 Telegram 内置浏览器中打开
:::

## 通过 `/settings` 管理按钮

按钮管理按作用域分散在设置面板的不同入口：

| 作用域 | 设置入口 |
|--------|----------|
| 菜单按钮 | `/settings` → 📋 查看当前配置（菜单按钮暂无独立编辑入口） |
| 自动回复按钮 | `/settings` → ✏️ 自动回复 → 按钮管理 |
| 欢迎消息按钮 | `/settings` → 👋 欢迎消息 → 按钮管理 |
| 广播消息按钮 | `/settings` → 📢 广播通知 → 按钮管理 |
| 关键字按钮 | `/settings` → 🔑 关键词管理 → 🔧 管理关键词 → 选择关键字 → 按钮管理 |

每个作用域的按钮管理都支持：

- **📋 查看按钮**：显示当前所有按钮
- **➕ 添加 URL 按钮**：依次输入按钮文本和 URL
- **➖ 删除按钮**：选择要删除的按钮序号
- **🗑️ 清空按钮**：删除该作用域的所有按钮

## 配置示例

```json
{
  "inline_buttons": [
    {"text": "官方网站", "url": "https://example.com"},
    {"text": "联系客服", "url": "https://t.me/support"}
  ],
  "auto_reply_buttons": [
    {"text": "常见问题", "url": "https://example.com/faq"}
  ],
  "welcome_buttons": [
    {"text": "快速开始", "url": "https://example.com/start"},
    {"text": "使用指南", "url": "https://example.com/guide"}
  ],
  "broadcast_buttons": [
    {"text": "查看详情", "url": "https://example.com"}
  ],
  "keywords": {
    "帮助": {
      "reply": "这是帮助信息...",
      "buttons": [
        {"text": "在线文档", "url": "https://example.com/docs"}
      ]
    }
  }
}
```

## 按钮数量限制

Telegram 对内联按钮的限制：

- 每行最多 8 个按钮
- 每条消息最多 100 个按钮
- 建议每行 1-3 个按钮，总按钮数不超过 10 个，保证良好的显示效果
