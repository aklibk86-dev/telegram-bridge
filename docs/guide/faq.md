# 常见问题

## 机器人没有响应 / 网络超时

如果机器人启动后没有响应，通常是网络问题：

**国内服务器：**
- 确保 `config.json` 中配置了代理：`"proxy": "http://127.0.0.1:7890"`
- 检查代理是否正常运行
- 检查代理地址是否正确，端口是否开放

**海外服务器：**
- 确保 `proxy` 字段为空：`"proxy": ""`
- 检查服务器能否访问 `api.telegram.org`：
  ```bash
  curl -I https://api.telegram.org
  ```

**查看日志定位问题：**

```bash
# systemd 部署
sudo journalctl -u telegram-bot -f

# 手动运行：查看终端输出或 data/bot.log
tail -f data/bot.log
```

## 如何注册为管理员？

TeleBridge **不需要密码**，注册管理员的流程：

1. 在 Telegram 中为自己设置用户名（设置 → 用户名）
2. 在 `config.json` 的 `admin_username` 字段填入该用户名（**不带 `@`**）
3. 启动机器人后，用你的账号向机器人发送 `/start`
4. 机器人会自动识别你为管理员，并显示「🔐 您已以管理员身份登录」

::: tip 用户名匹配规则
- 不区分大小写（`Admin` 和 `admin` 等价）
- 用户名是 Telegram 的 `@username`，不是昵称（first name）
- 修改 `config.json` 后需重启机器人才能生效
:::

## 修改配置后需要重启吗？

- 通过 `/settings` 面板修改的配置 **实时生效**，无需重启
- 直接编辑 `config.json` 文件后，**需要重启机器人**才能生效

## 如何查看自己的用户名？

在 Telegram 中：

1. 打开 **设置**，查看「用户名」字段
2. 如果未设置，点击设置一个唯一的用户名
3. 或在任意聊天中发送 `/id` 给 [@userinfobot](https://t.me/userinfobot) 查看完整信息

## 如何添加更多管理员？

目前设计为单管理员模式。如需多管理员，可以通过修改 `bot.py` 中的 `is_admin` 函数实现，例如支持一个管理员用户名列表。

## 数据文件在哪？

- **用户数据**：`data/users.json`
- **日志文件**：`data/bot.log`
- **配置文件**：`config.json`（项目根目录）

::: tip Docker 部署
Docker 部署时，`data/` 目录挂载到容器内 `/app/data`，`config.json` 只读挂载。
:::

## Docker 部署修改配置后无法生效？

Docker 部署中 `config.json` 是只读挂载的，修改后需要重启容器：

```bash
docker compose restart
```

## 如何更新机器人？

**一键脚本更新（推荐）：**

```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh | bash -s -- --update

# Windows PowerShell
$env:TB_UPDATE = "1"
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
```

**手动更新：**

```bash
cd <你的安装目录>
git pull
source venv/bin/activate       # Windows: .\venv\Scripts\Activate.ps1
pip install -r requirements.txt   # 如依赖有变化
sudo systemctl restart telegram-bot   # Linux systemd 部署
```

## 如何备份？

只需备份以下文件即可完整恢复：

- `config.json` — 所有配置
- `data/users.json` — 用户数据和管理员 chat_id

```bash
# 备份
cp config.json config.json.bak
cp data/users.json data/users.json.bak

# 恢复（先停止机器人，恢复文件后重启）
```

## 关键字匹配规则是什么？

- 用户消息中**包含**关键字即触发（不区分大小写）
- 匹配后发送关键字配置的回复内容
- 关键字匹配后，消息**仍会转发给管理员**（不会拦截）
- 仅对**文字消息**或**带 caption 的媒体消息**生效

详见 [自动回复](./features/auto-reply)。

## 媒体消息会触发关键字吗？

- 纯媒体消息（无 caption）：**不触发**关键字匹配，直接转发给管理员
- 带文字说明的媒体消息（有 caption）：**会触发**关键字匹配

详见 [媒体转发](./features/media-forwarding)。

## 如何关闭自动回复？

将 `auto_reply` 字段设置为空字符串：

```json
{
  "auto_reply": ""
}
```

或在 `/settings` → 自动回复 中清空内容。空字符串时不会发送自动回复消息。

## 自动回复的删除计时器怎么用？

设置 `auto_reply_delete_time`（单位：秒），自动回复消息会在指定时间后自动删除：

- 设置为 `10`：10 秒后删除
- 设置为 `0`：不删除（默认）
- 适用于临时通知场景，减少聊天界面干扰

::: warning 删除权限
机器人只能删除自己发送的消息。删除失败（如权限不足）不会报错，消息会保留。
:::

## 机器人发送广播很慢？

Telegram API 有频率限制（约每秒 30 条消息）。大量用户时广播需要一些时间，这是正常现象。建议：

- 分批广播，避免一次发送过多
- 广播内容尽量精简
- 避免高峰时段发送

## 如何完全卸载？

**Linux：**

```bash
# 停止并删除 systemd 服务
sudo systemctl stop telegram-bot
sudo systemctl disable telegram-bot
sudo rm /etc/systemd/system/telegram-bot.service
sudo systemctl daemon-reload

# 删除安装目录
rm -rf ~/telegram-bridge   # 或你的安装目录
```

**Windows：**

1. 通过任务管理器结束 `python.exe` 或 `pythonw.exe` 进程
2. 如配置了开机自启，删除 `shell:startup` 中的 `bot.vbs`
3. 删除安装目录

::: tip 保留数据
如需保留用户数据和配置，卸载前先备份 `config.json` 和 `data/users.json`。
:::
