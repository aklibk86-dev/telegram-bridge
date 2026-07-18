# 快速开始

TeleBridge 提供两种安装方式：**一键安装脚本**（推荐）和**手动安装**。

## 前提条件

- Python 3.8 或更高版本
- 一个 Telegram 机器人 Token（通过 [@BotFather](https://t.me/BotFather) 创建）
- 一个 Telegram 账号（用作管理员，需在 Telegram 中设置好用户名）

## 第一步：获取 Bot Token

1. 在 Telegram 中打开 [@BotFather](https://t.me/BotFather)
2. 发送 `/newbot`，按提示输入机器人名称和用户名
3. 创建成功后，保存获得的 API Token（格式类似 `123456789:ABCdef...`）

::: tip 设置 Telegram 用户名
管理员账号需要设置 Telegram 用户名（非昵称）。打开 Telegram → 设置 → 用户名，设置一个唯一的用户名（如 `my_admin_name`），后续配置中会用到，**不要带 `@` 前缀**。
:::

---

## 方式一：一键安装（推荐）

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh | bash
```

### Windows（PowerShell）

```powershell
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
```

脚本会自动完成：

1. 检查 Python 3.8+ 环境
2. 克隆仓库（Windows 无 git 时自动回退 ZIP 下载）
3. 创建虚拟环境并安装依赖
4. 交互式引导配置 Bot Token、管理员用户名、代理地址
5. Linux 下自动配置 systemd 开机自启服务
6. 启动机器人

::: details 安装脚本高级选项

**Linux/macOS**（先下载到本地）：
```bash
# 指定安装目录
bash install.sh /opt/telegram-bot

# 更新已安装的实例（git pull + 更新依赖）
bash install.sh --update

# 不配置 systemd 服务
bash install.sh --no-service

# 不自动启动
bash install.sh --no-start
```

**Windows**（下载 `install.ps1` 后）：
```powershell
# 指定安装目录
powershell -ExecutionPolicy Bypass -File install.ps1 -InstallDir "D:\mybot"

# 通过 irm | iex 传参（先设环境变量）
$env:TB_INSTALL_DIR = "D:\mybot"; irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex

# 更新模式
$env:TB_UPDATE = "1"; irm ... | iex
```
:::

安装完成后，直接跳到 [第四步：注册管理员](#第四步-注册管理员)。

---

## 方式二：手动安装

### 第二步：下载项目

```bash
git clone https://github.com/aklibk86-dev/telegram-bridge.git
cd telegram-bridge
```

### 第三步：配置与启动

**创建虚拟环境并安装依赖：**

```bash
# Linux/macOS
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Windows
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

**配置 `config.json`：**

编辑项目根目录下的 `config.json`，填入 Bot Token 和你的管理员用户名：

```json
{
  "bot_token": "123456789:ABCdef_your_token_here",
  "proxy": "",
  "admin_username": "your_telegram_username",
  "auto_reply": "✅ 您的消息已收到，我们会尽快回复您！",
  "auto_reply_delete_time": 3,
  "welcome_message": "👋 欢迎使用机器人！\n\n您可以直接发送消息，我们会收到并回复。"
}
```

| 字段 | 说明 |
|------|------|
| `bot_token` | BotFather 获取的 API Token |
| `proxy` | HTTP 代理地址，海外服务器留空；国内服务器填如 `http://127.0.0.1:7890` |
| `admin_username` | 你的 Telegram 用户名，**不要**加 `@` 前缀 |

::: tip 后续配置
其他可选字段（`keywords`、`inline_buttons` 等）可后续通过 `/settings` 面板在 Telegram 中配置，无需手动编辑文件。详见 [配置说明](./configuration)。
:::

**启动机器人：**

```bash
python bot.py
```

看到日志输出 `Bot started` 即表示启动成功。

---

## 第四步：注册管理员

1. 在 Telegram 中找到你刚创建的机器人
2. 发送 `/start`
3. 如果你的 Telegram 用户名与 `config.json` 中的 `admin_username` 一致，机器人会自动识别你为管理员，并显示「🔐 您已以管理员身份登录」
4. 管理员注册完成，现在你可以接收并回复用户消息了

::: warning 注册失败的排查
- 确保你的 Telegram 用户名已设置（设置 → 用户名）
- 确保 `config.json` 中的 `admin_username` 与你的用户名完全一致（不区分大小写，不带 `@`）
- 修改 `config.json` 后需重启机器人才能生效
:::

## 第五步：验证运行

1. 用**另一个** Telegram 账号向机器人发送消息
2. 管理员账号应收到转发的消息（包含用户信息和消息内容）
3. 在 Telegram 中**回复**这条转发的消息（点击消息后选择「回复」）
4. 用户应收到管理员的回复内容

## 下一步

- 查看 [功能介绍](./features/two-way-messaging) 了解双向通讯的完整流程
- 使用 `/settings` 命令配置关键字、自动回复、内联按钮等
- 查看 [管理员命令](./admin-commands) 了解所有可用命令
- 如需开机自启，参考 [Linux 部署](./deployment/linux) 或 [Windows 部署](./deployment/windows)
