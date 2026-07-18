# Linux 部署

TeleBridge 在 Linux 上提供多种部署方式。

## 方式一：一键安装脚本（推荐）

最简单的部署方式，自动完成环境检查、代码下载、依赖安装、配置和 systemd 服务注册。

```bash
curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh | bash
```

脚本特性：

- 自动检测并安装 Python 3.8+（支持 Ubuntu/Debian/CentOS/RHEL 等主流发行版）
- 自动安装 git（如未安装）
- 默认安装到 `~/telegram-bridge`，可自定义
- 交互式引导配置 Bot Token、管理员用户名、代理地址
- 自动注册并启用 `telegram-bot.service` systemd 服务
- 安装完成后自动启动

### 高级选项

下载脚本到本地后可使用以下选项：

```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh -o install.sh

# 指定安装目录
bash install.sh /opt/telegram-bot

# 更新已安装的实例（git pull + 更新依赖 + 重启服务）
bash install.sh --update

# 不配置 systemd 服务
bash install.sh --no-service

# 安装但不自动启动
bash install.sh --no-start
```

### 服务管理

一键安装配置的 systemd 服务名为 `telegram-bot`：

```bash
# 查看状态
sudo systemctl status telegram-bot

# 查看实时日志
sudo journalctl -u telegram-bot -f

# 重启
sudo systemctl restart telegram-bot

# 停止
sudo systemctl stop telegram-bot

# 取消开机自启
sudo systemctl disable telegram-bot
```

---

## 方式二：root 部署脚本

适合需要部署到 `/opt/telegram-bot` 且使用 root 运行的场景：

```bash
sudo bash deploy.sh
```

脚本会：

1. 检测 Python 版本（需要 3.8+），缺失时可选自动编译安装
2. 复制项目文件到 `/opt/telegram-bot`
3. 创建虚拟环境并安装依赖
4. 安装 `telegram-bot.service` 为 systemd 服务
5. 启动并启用服务

::: warning
`deploy.sh` 需要在项目目录中执行（即先 `git clone` 并 `cd` 到项目目录），且需要 root 权限。
:::

---

## 方式三：手动部署

### 1. 克隆代码

```bash
git clone https://github.com/aklibk86-dev/telegram-bridge.git
cd telegram-bridge
```

### 2. 创建虚拟环境并安装依赖

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. 配置 `config.json`

参考 [快速开始](../getting-started#第三步-配置与启动) 中的配置说明，填写 Bot Token 和管理员用户名。

### 4. 配置 systemd 服务（可选，推荐）

将项目复制到 `/opt/telegram-bot` 并注册服务：

```bash
# 复制到固定目录
sudo cp -r . /opt/telegram-bot

# 注册 systemd 服务
sudo cp telegram-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable telegram-bot
sudo systemctl start telegram-bot

# 查看状态
sudo systemctl status telegram-bot
sudo journalctl -u telegram-bot -f
```

`telegram-bot.service` 默认内容：

```ini
[Unit]
Description=Telegram 双向机器人
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/telegram-bot
ExecStart=/opt/telegram-bot/venv/bin/python /opt/telegram-bot/bot.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

如需使用其他用户运行，修改 `User` 字段并确保该用户对 `/opt/telegram-bot` 有读写权限。

### 5. 前台运行（调试用）

不配置 systemd 时可直接前台运行：

```bash
# 使用 start.sh 一键启动（自动激活虚拟环境）
bash start.sh

# 或手动激活并运行
source venv/bin/activate
python bot.py
```

---

## 代理配置

如服务器位于中国大陆，无法直连 `api.telegram.org`，需要在 `config.json` 中配置代理：

```json
{
  "proxy": "http://127.0.0.1:7890"
}
```

海外服务器留空即可：`"proxy": ""`。

::: tip 代理要求
机器人使用 HTTP 代理（通过 httpx）。如需使用 SOCKS5 代理，需额外安装 `httpx[socks]` 依赖，并在 `proxy` 字段填写 `socks5://127.0.0.1:1080` 格式的地址。
:::

---

## 更新机器人

### 一键脚本更新

```bash
bash install.sh --update
```

或使用环境变量 + 一行命令：

```bash
# 重新执行一键安装脚本，进入更新模式
curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh | bash -s -- --update
```

### 手动更新

```bash
cd /opt/telegram-bot   # 或你的安装目录
git pull
source venv/bin/activate
pip install -r requirements.txt   # 如果依赖有变化

# 重启服务
sudo systemctl restart telegram-bot
```
