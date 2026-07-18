# Docker 部署

使用 Docker 可以快速部署 TeleBridge，无需手动配置 Python 环境。

## 前提条件

- 已安装 Docker 和 Docker Compose
- 项目根目录下存在 `config.json` 配置文件

## 部署步骤

### 1. 克隆代码

```bash
git clone https://github.com/aklibk86-dev/telegram-bridge.git
cd telegram-bridge
```

### 2. 配置 `config.json`

编辑项目根目录下的 `config.json`，填入 Bot Token 和管理员用户名：

```json
{
  "bot_token": "123456789:ABCdef_your_token_here",
  "proxy": "",
  "admin_username": "your_telegram_username",
  "auto_reply": "✅ 您的消息已收到，我们会尽快回复您！",
  "welcome_message": "👋 欢迎使用机器人！"
}
```

::: tip 配置说明
详见 [配置说明](../configuration)。其他可选字段可通过 `/settings` 在 Telegram 中后续配置。
:::

### 3. 创建数据目录

```bash
mkdir -p data
```

`data/` 目录用于持久化用户数据和日志。

### 4. 构建并启动服务

```bash
docker compose up -d --build
```

首次构建会下载 Python 3.11 镜像并安装依赖，可能需要几分钟。

### 5. 查看日志

```bash
docker compose logs -f
```

看到 `Bot started` 即表示启动成功。按 `Ctrl+C` 退出日志查看（不会停止容器）。

### 6. 验证运行

在 Telegram 中向机器人发送 `/start`，如能收到欢迎消息即部署成功。

## 目录结构

```
telegram-bridge/
├── docker-compose.yml      # Docker Compose 配置
├── Dockerfile              # 镜像构建文件
├── bot.py                  # 主程序
├── config.json             # 配置文件（挂载为只读）
├── requirements.txt        # Python 依赖
└── data/                   # 持久化数据
    ├── users.json          # 用户数据
    └── bot.log             # 运行日志
```

## 数据持久化

`docker-compose.yml` 中的挂载配置：

```yaml
volumes:
  - ./data:/app/data              # 数据目录（可读写）
  - ./config.json:/app/config.json:ro   # 配置文件（只读）
```

- `./data` 挂载到容器内 `/app/data`，保存用户数据和日志
- `config.json` 以只读方式挂载，容器内无法修改
- 删除容器后数据不会丢失（保存在宿主机 `./data` 目录）

## 服务管理

```bash
# 查看状态
docker compose ps

# 查看实时日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 停止并删除容器（保留数据）
docker compose down

# 停止并删除容器和镜像
docker compose down --rmi local
```

## 修改配置后生效

Docker 部署中 `config.json` 是只读挂载，修改后需要重启容器：

```bash
# 1. 编辑 config.json
# 2. 重启容器
docker compose restart
```

::: tip 使用 /settings 面板
通过 `/settings` 面板修改的配置会写入 `config.json` 并实时生效，**无需重启容器**。但如果通过宿主机编辑 `config.json`，需要重启容器才能让容器内进程读取新内容。
:::

## 更新机器人

```bash
# 拉取最新代码
git pull

# 重新构建并启动
docker compose up -d --build
```

## 自定义配置

### 修改时区

`docker-compose.yml` 默认使用 `Asia/Shanghai` 时区。如需修改：

```yaml
environment:
  - TZ=America/Los_Angeles
  - PYTHONUNBUFFERED=1
```

### 修改容器名

默认容器名为 `telebridge`，如需修改：

```yaml
services:
  telebridge:
    container_name: my-telegram-bot
```

### 使用代理

在 `config.json` 中配置代理即可，Docker 容器会使用该代理：

```json
{
  "proxy": "http://host.docker.internal:7890"
}
```

::: warning 代理地址
- Docker 容器内 `127.0.0.1` 指向容器自身，不是宿主机
- 如代理运行在宿主机上，使用 `host.docker.internal`（Linux 需添加 `--add-host=host.docker.internal:host-gateway`）
- 或使用宿主机的局域网 IP（如 `192.168.1.100:7890`）
:::
