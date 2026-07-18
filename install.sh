#!/bin/bash
# ============================================================
#  TeleBridge - 一键安装脚本（Linux / macOS）
# ------------------------------------------------------------
#  用法：
#    1) curl 一键安装（推荐）：
#       curl -fsSL https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh | bash
#
#    2) 下载后运行：
#       bash install.sh [安装目录] [选项]
#
#  选项（仅下载运行时可用）：
#    安装目录        默认：$HOME/telegram-bridge
#    --no-service    不安装 systemd 开机自启服务
#    --no-start      安装完成后不自动启动
#    --update        更新已存在的安装（git pull + 依赖更新）
# ============================================================

set -e

REPO_URL="https://github.com/aklibk86-dev/telegram-bridge.git"
REPO_BRANCH="main"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.sh"
SERVICE_NAME="telegram-bot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# ---------- 管道模式处理 ----------
# 当通过 curl|bash 管道执行时，bash 的 stdin 是管道（脚本内容），
# 交互式 read 无法从终端读取用户输入。
# 解决方案：检测到管道模式时，把脚本下载到临时文件，
# 用 /dev/tty 作为 stdin 重新执行，这样既能完整读取脚本，又能交互输入。
if [ ! -t 0 ] && [ -p /dev/stdin ]; then
    TMP_SCRIPT="$(mktemp /tmp/telebridge-install.XXXXXX.sh 2>/dev/null || mktemp)"
    trap 'rm -f "$TMP_SCRIPT"' EXIT INT TERM
    # 尝试用 curl 下载，失败则用 wget
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$SCRIPT_RAW_URL" -o "$TMP_SCRIPT"; then
            echo "[ERROR] 下载安装脚本失败，请检查网络连接。" >&2
            rm -f "$TMP_SCRIPT"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -qO "$TMP_SCRIPT" "$SCRIPT_RAW_URL"; then
            echo "[ERROR] 下载安装脚本失败，请检查网络连接。" >&2
            rm -f "$TMP_SCRIPT"
            exit 1
        fi
    else
        echo "[ERROR] 未找到 curl 或 wget，无法继续。" >&2
        rm -f "$TMP_SCRIPT"
        exit 1
    fi
    # 用 /dev/tty 作为 stdin 重新执行，并把命令行参数透传
    exec bash "$TMP_SCRIPT" "$@" </dev/tty
fi

# 默认参数
INSTALL_DIR="${HOME}/telegram-bridge"
INSTALL_SERVICE=1
AUTO_START=1
UPDATE_MODE=0

# 解析命令行参数（仅当脚本被直接执行而非管道执行时有效）
if [ $# -gt 0 ]; then
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-service) INSTALL_SERVICE=0; shift ;;
            --no-start)   AUTO_START=0; shift ;;
            --update)     UPDATE_MODE=1; shift ;;
            --help|-h)
                sed -n '2,20p' "$0" 2>/dev/null || true
                exit 0
                ;;
            *)
                if [[ "$1" != -* ]]; then
                    INSTALL_DIR="$1"
                fi
                shift
                ;;
        esac
    done
fi

# ---------- 颜色输出 ----------
if [ -t 1 ]; then
    C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'; C_RESET='\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_RESET=''
fi

info()  { printf "${C_BLUE}[INFO]${C_RESET} %s\n"  "$*"; }
ok()    { printf "${C_GREEN}[OK]${C_RESET} %s\n"    "$*"; }
warn()  { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$*"; }
err()   { printf "${C_RED}[ERROR]${C_RESET} %s\n"   "$*" >&2; }
step()  { printf "\n${C_CYAN}=== %s ===${C_RESET}\n" "$*"; }

# ---------- 横幅 ----------
cat <<'EOF'

============================================================
   TeleBridge - Telegram 双向机器人 一键安装
   仓库: https://github.com/aklibk86-dev/telegram-bridge
============================================================

EOF

# ---------- 工具函数 ----------
command_exists() { command -v "$1" >/dev/null 2>&1; }

detect_package_manager() {
    if command_exists apt-get; then echo "apt-get"
    elif command_exists yum;    then echo "yum"
    elif command_exists dnf;    then echo "dnf"
    elif command_exists brew;   then echo "brew"
    else echo "unknown"
    fi
}

get_python_version() {
    for bin in python3 python; do
        if command_exists "$bin"; then
            "$bin" -c 'import sys; v=sys.version_info; print(f"{v.major}.{v.minor}.{v.micro}")' 2>/dev/null && return
        fi
    done
}

version_ge() {
    # version_ge <actual> <min>  →  实际版本 >= 最低版本
    local a="${1#v}" b="${2#v}"
    a="${a%%-*}"; b="${b%%-*}"
    local IFS=.
    local i a1=($a) b1=($b)
    for ((i=0; i<${#b1[@]}; i++)); do
        local x=${a1[i]:-0} y=${b1[i]:-0}
        if (( x > y )); then return 0; fi
        if (( x < y )); then return 1; fi
    done
    return 0
}

MIN_PY="3.8.0"

# ---------- 1. 检查并安装 Python ----------
step "第 1 步：检查 Python 环境"

PY_BIN=""
PY_VER=$(get_python_version)

if [ -n "$PY_VER" ]; then
    if version_ge "$PY_VER" "$MIN_PY"; then
        ok "检测到 Python ${PY_VER}"
        # 选择 python3 优先
        if command_exists python3; then PY_BIN="python3"
        else PY_BIN="python"; fi
    else
        warn "Python 版本过低: ${PY_VER}，需要 >= ${MIN_PY}"
    fi
fi

if [ -z "$PY_BIN" ]; then
    info "未检测到满足要求的 Python，尝试自动安装..."
    PM=$(detect_package_manager)
    case "$PM" in
        apt-get)
            export DEBIAN_FRONTEND=noninteractive
            sudo -n apt-get update -y >/dev/null 2>&1 || sudo apt-get update -y
            sudo apt-get install -y python3 python3-venv python3-pip
            ;;
        yum|dnf)
            sudo "$PM" install -y python3 python3-pip
            ;;
        brew)
            brew install python
            ;;
        *)
            err "无法自动安装 Python。请手动安装 Python ${MIN_PY}+ 后重试。"
            err "下载地址: https://www.python.org/downloads/"
            exit 1
            ;;
    esac
    PY_BIN="python3"
    PY_VER=$(get_python_version)
    if [ -z "$PY_VER" ] || ! version_ge "$PY_VER" "$MIN_PY"; then
        err "Python 安装失败或版本仍过低。请手动安装 Python ${MIN_PY}+。"
        exit 1
    fi
    ok "Python ${PY_VER} 安装完成"
fi

# 检查 venv 模块
if ! "$PY_BIN" -c "import venv" 2>/dev/null; then
    warn "缺少 venv 模块，尝试安装..."
    PM=$(detect_package_manager)
    case "$PM" in
        apt-get) sudo apt-get install -y python3-venv ;;
        yum|dnf) sudo "$PM" install -y python3-venv 2>/dev/null || true ;;
    esac
fi

# 检查 git
if ! command_exists git; then
    info "安装 git..."
    PM=$(detect_package_manager)
    case "$PM" in
        apt-get) sudo apt-get install -y git ;;
        yum|dnf) sudo "$PM" install -y git ;;
        brew)    brew install git ;;
        *)
            err "未检测到 git，请手动安装后重试。"
            exit 1
            ;;
    esac
fi
ok "git 已就绪"

# ---------- 2. 下载/更新代码 ----------
step "第 2 步：获取代码"

if [ -d "${INSTALL_DIR}/.git" ]; then
    if [ "$UPDATE_MODE" -eq 1 ]; then
        info "更新已存在的安装: ${INSTALL_DIR}"
        cd "$INSTALL_DIR"
        git fetch --quiet origin
        git reset --hard "origin/${REPO_BRANCH}" >/dev/null 2>&1 || git pull --ff-only
        ok "代码已更新到最新版本"
    else
        warn "目录已存在且为 git 仓库: ${INSTALL_DIR}"
        read -r -p "是否拉取最新代码？(y/N): " pull_confirm
        if [[ "$pull_confirm" =~ ^[Yy]$ ]]; then
            cd "$INSTALL_DIR"
            git fetch --quiet origin
            git reset --hard "origin/${REPO_BRANCH}" >/dev/null 2>&1 || git pull --ff-only
            ok "代码已更新"
        else
            info "保留现有代码"
            cd "$INSTALL_DIR"
        fi
    fi
else
    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
        warn "目标目录非空: ${INSTALL_DIR}"
        read -r -p "是否清空并重新克隆？(y/N): " clear_confirm
        if [[ "$clear_confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            INSTALL_DIR="${INSTALL_DIR}-$(date +%s)"
            warn "改用新目录: ${INSTALL_DIR}"
        fi
    fi

    info "克隆仓库到: ${INSTALL_DIR}"
    git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    ok "代码克隆完成"
fi

# ---------- 3. 创建虚拟环境并安装依赖 ----------
step "第 3 步：创建虚拟环境并安装依赖"

info "使用 Python: ${PY_BIN} ($("${PY_BIN}" --version 2>&1))"

if [ ! -d "venv" ]; then
    "$PY_BIN" -m venv venv
fi

# shellcheck disable=SC1091
source venv/bin/activate

info "升级 pip..."
pip install --upgrade pip -q

info "安装依赖..."
pip install -r requirements.txt -q
ok "依赖安装完成"

# ---------- 4. 配置文件 ----------
step "第 4 步：配置机器人"

# 交互式收集配置（非交互模式下跳过，保留默认值）
ask() {
    # ask "提示文字" "默认值" → 输出到 stdout
    local prompt="$1" default="${2:-}" input
    if [ -t 0 ]; then
        if [ -n "$default" ]; then
            read -r -p "${prompt} [${default}]: " input
            echo "${input:-$default}"
        else
            read -r -p "${prompt}: " input
            echo "$input"
        fi
    else
        # 非交互模式（如 curl | bash 末尾未带 -t）
        echo "$default"
    fi
}

ask_token() {
    local token=""
    if [ -t 0 ]; then
        while true; do
            read -r -p "请输入 Bot Token（从 @BotFather 获取）: " token
            if [ -z "$token" ]; then
                warn "Token 不能为空，请重新输入"
            elif [[ ! "$token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
                warn "Token 格式看起来不正确（应为 123456:ABCxxx 格式），请重新输入"
            else
                break
            fi
        done
    fi
    echo "$token"
}

# 读取现有配置作为默认值
CURRENT_TOKEN=""
CURRENT_PROXY=""
CURRENT_ADMIN=""
if [ -f "config.json" ]; then
    CURRENT_TOKEN=$(python3 -c "import json;print(json.load(open('config.json')).get('bot_token',''))" 2>/dev/null || echo "")
    CURRENT_PROXY=$(python3 -c "import json;print(json.load(open('config.json')).get('proxy',''))" 2>/dev/null || echo "")
    CURRENT_ADMIN=$(python3 -c "import json;print(json.load(open('config.json')).get('admin_username',''))" 2>/dev/null || echo "")
fi

# 是否需要重新配置
NEED_CONFIG=1
if [ -n "$CURRENT_TOKEN" ] && [ "$CURRENT_TOKEN" != "YOUR_BOT_TOKEN_HERE" ]; then
    if [ -t 0 ]; then
        read -r -p "已存在配置，是否重新配置？(y/N): " reconf
        [[ "$reconf" =~ ^[Yy]$ ]] || NEED_CONFIG=0
    else
        NEED_CONFIG=0
    fi
fi

if [ "$NEED_CONFIG" -eq 1 ]; then
    echo ""
    echo "请按提示输入配置信息："
    echo "  - Bot Token: 从 @BotFather 获取的 Token"
    echo "  - 管理员用户名: 你的 Telegram 用户名（不带 @）"
    echo "  - 代理地址: 海外服务器留空，国内服务器填写本地代理（如 http://127.0.0.1:7890）"
    echo ""

    BOT_TOKEN=$(ask_token)
    ADMIN_USERNAME=$(ask "管理员用户名（不带 @）" "$CURRENT_ADMIN")
    PROXY_URL=$(ask "代理地址（海外留空）" "$CURRENT_PROXY")

    # 使用 Python 安全地更新 config.json
    python3 - <<PYEOF
import json, sys
cfg = {}
try:
    with open('config.json', 'r', encoding='utf-8') as f:
        cfg = json.load(f)
except Exception:
    cfg = {}

cfg['bot_token'] = """${BOT_TOKEN}"""
cfg['admin_username'] = """${ADMIN_USERNAME}"""
cfg['proxy'] = """${PROXY_URL}"""

# 确保必要字段存在
cfg.setdefault('auto_reply', '✅ 您的消息已收到，我们会尽快回复您！')
cfg.setdefault('auto_reply_delete_time', 3)
cfg.setdefault('welcome_message', '👋 欢迎使用机器人！\n\n您可以直接发送消息，我们会收到并回复。')
cfg.setdefault('keywords', {})
cfg.setdefault('inline_buttons', [])
cfg.setdefault('auto_reply_buttons', [])
cfg.setdefault('welcome_buttons', [])
cfg.setdefault('broadcast_buttons', [])
cfg.setdefault('reply_keyboard', [])

with open('config.json', 'w', encoding='utf-8') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
print('config.json 已写入')
PYEOF
    ok "配置已保存到 config.json"
else
    ok "保留现有配置"
fi

# ---------- 5. systemd 服务（仅 Linux）----------
IS_LINUX=0
if [ -f /proc/version ] && grep -qi linux /proc/version 2>/dev/null; then
    IS_LINUX=1
fi
# 更可靠的判断
if [ "$(uname -s 2>/dev/null)" = "Linux" ]; then
    IS_LINUX=1
fi

if [ "$INSTALL_SERVICE" -eq 1 ] && [ "$IS_LINUX" -eq 1 ] && command_exists systemctl; then
    step "第 5 步：配置 systemd 开机自启"

    if [ "$EUID" -ne 0 ]; then
        info "安装 systemd 服务需要 root 权限，将使用 sudo"
        if ! sudo -n true 2>/dev/null; then
            warn "可能需要输入 sudo 密码"
        fi
        SUDO="sudo"
    else
        SUDO=""
    fi

    ABS_DIR="$(pwd)"
    SERVICE_CONTENT="[Unit]
Description=TeleBridge - Telegram 双向机器人
After=network.target

[Service]
Type=simple
User=$(id -un)
WorkingDirectory=${ABS_DIR}
ExecStart=${ABS_DIR}/venv/bin/python ${ABS_DIR}/bot.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target"

    echo "$SERVICE_CONTENT" | $SUDO tee "$SERVICE_FILE" >/dev/null
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    ok "systemd 服务已安装: ${SERVICE_NAME}"
    SERVICE_INSTALLED=1
else
    if [ "$INSTALL_SERVICE" -eq 1 ]; then
        warn "当前环境不支持 systemd（非 Linux 或无 systemctl），跳过开机自启配置"
    fi
    SERVICE_INSTALLED=0
fi

# ---------- 6. 启动 ----------
step "第 6 步：启动机器人"

if [ "$AUTO_START" -eq 1 ]; then
    if [ "$SERVICE_INSTALLED" -eq 1 ]; then
        $SUDO systemctl restart "$SERVICE_NAME"
        sleep 2
        if $SUDO systemctl is-active --quiet "$SERVICE_NAME"; then
            ok "机器人已启动并运行中"
        else
            warn "服务启动可能失败，请查看日志：journalctl -u ${SERVICE_NAME} -f"
        fi
    else
        info "直接启动（前台运行，按 Ctrl+C 停止）..."
        echo ""
        python bot.py || warn "机器人退出"
    fi
else
    info "已跳过自动启动"
fi

# ---------- 完成 ----------
cat <<EOF

============================================================
   ✅ TeleBridge 安装完成！
============================================================

安装目录:  ${INSTALL_DIR}
EOF

if [ "$SERVICE_INSTALLED" -eq 1 ]; then
cat <<EOF

服务管理:
  启动:      sudo systemctl start ${SERVICE_NAME}
  停止:      sudo systemctl stop ${SERVICE_NAME}
  重启:      sudo systemctl restart ${SERVICE_NAME}
  查看状态:  sudo systemctl status ${SERVICE_NAME}
  查看日志:  sudo journalctl -u ${SERVICE_NAME} -f
EOF
else
cat <<EOF

启动机器人:
  cd ${INSTALL_DIR}
  source venv/bin/activate
  python bot.py

或使用启动脚本:
  bash ${INSTALL_DIR}/start.sh
EOF
fi

cat <<EOF

后续操作:
  1. 用管理员账号给机器人发送 /start 完成管理员注册
  2. 发送 /settings 打开交互式设置面板
  3. 修改配置后重启服务生效

文档: https://github.com/aklibk86-dev/telegram-bridge
交流群: https://t.me/kqxw_chat

============================================================
EOF
