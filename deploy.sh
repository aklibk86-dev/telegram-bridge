#!/bin/bash
# Telegram 双向机器人 - Linux 一键部署脚本
# 用法: bash deploy.sh

set -e

BOT_DIR="/opt/telegram-bot"

echo "========================================"
echo "  Telegram 双向机器人 - 部署脚本"
echo "========================================"
echo ""

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 用户或 sudo 执行: sudo bash deploy.sh"
    exit 1
fi

# ============================================
# Python3 版本检测与安装
# 要求：Python 3.8+
# ============================================
MIN_PY_MAJOR=3
MIN_PY_MINOR=8

get_python_version() {
    python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null
}

version_too_low() {
    local ver="$1"
    local major="${ver%%.*}"
    local minor="${ver#*.}"
    minor="${minor%%.*}"
    if [ "$major" -lt "$MIN_PY_MAJOR" ]; then
        return 0
    fi
    if [ "$major" -eq "$MIN_PY_MAJOR" ] && [ "$minor" -lt "$MIN_PY_MINOR" ]; then
        return 0
    fi
    return 1
}

detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# 安装编译依赖
install_build_deps() {
    local pm="$1"
    echo ">>> 安装编译依赖..."
    case "$pm" in
        apt)
            apt update -y
            apt install -y wget build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
                libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev \
                libbz2-dev liblzma-dev uuid-dev
            ;;
        yum|dnf)
            $pm install -y wget gcc make zlib-devel ncurses-devel gdbm-devel \
                nss-devel openssl-devel readline-devel libffi-devel sqlite-devel \
                bzip2-devel xz-devel uuid-devel
            ;;
    esac
}

# 从源码编译安装 Python
install_python_from_source() {
    local target_version="$1"
    local pm
    pm=$(detect_package_manager)

    install_build_deps "$pm"

    echo ">>> 下载 Python ${target_version} 源码..."
    cd /tmp
    wget -q "https://www.python.org/ftp/python/${target_version}/Python-${target_version}.tgz"

    echo ">>> 解压..."
    tar -xzf "Python-${target_version}.tgz"
    cd "Python-${target_version}"

    echo ">>> 编译安装（可能需要几分钟）..."
    ./configure --enable-optimizations --prefix=/usr/local -q
    make -j"$(nproc)" -s
    make altinstall -s

    cd /tmp
    rm -rf "Python-${target_version}" "Python-${target_version}.tgz"

    # 创建 python3 软链接指向新版本
    ln -sf /usr/local/bin/python${target_version%.*} /usr/local/bin/python3
    ln -sf /usr/local/bin/pip${target_version%.*} /usr/local/bin/pip3

    echo ">>> Python ${target_version} 安装完成"
}

# 获取最新稳定版 Python 版本号
get_latest_python_version() {
    local version
    version=$(wget -qO- "https://www.python.org/downloads/" 2>/dev/null | \
        grep -oP 'Download Python \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -z "$version" ]; then
        version="3.12.4"
    fi
    echo "$version"
}

# --- 主逻辑开始 ---

if ! command -v python3 &> /dev/null; then
    echo "[1/5] 系统未安装 Python3，正在安装..."
    pm=$(detect_package_manager)
    case "$pm" in
        apt)
            apt update && apt install -y python3 python3-venv python3-pip
            ;;
        yum|dnf)
            $pm install -y python3 python3-venv
            ;;
        *)
            echo "❌ 无法识别包管理器，请手动安装 Python 3.8+"
            exit 1
            ;;
    esac
fi

# 检查版本
CURRENT_PY_VER=$(get_python_version)
echo "[1/5] 检测到 Python 版本: ${CURRENT_PY_VER}"

if version_too_low "$CURRENT_PY_VER"; then
    echo ""
    echo "⚠️  Python 版本过低！"
    echo "    当前版本: ${CURRENT_PY_VER}"
    echo "    最低要求: ${MIN_PY_MAJOR}.${MIN_PY_MINOR}+"
    echo ""

    LATEST_PY_VER=$(get_latest_python_version)
    echo "    可升级到最新稳定版: ${LATEST_PY_VER}"
    echo ""

    read -p "是否升级 Python 到最新版本 ${LATEST_PY_VER}？(y/N): " upgrade_confirm
    if [[ "$upgrade_confirm" != [yY] && "$upgrade_confirm" != [yY][eE][sS] ]]; then
        echo "❌ Python 版本过低，无法继续部署。请手动升级 Python 后重试。"
        echo "   升级方法："
        echo "   1. 源码编译: wget https://www.python.org/ftp/python/${LATEST_PY_VER}/Python-${LATEST_PY_VER}.tgz"
        echo "   2. 或使用 pyenv: curl https://pyenv.run | bash"
        exit 1
    fi

    echo ""
    echo ">>> 开始升级 Python..."
    echo ">>> 步骤 1/3: 卸载旧版本 Python..."
    pm=$(detect_package_manager)
    case "$pm" in
        apt)
            apt remove -y python3 python3-pip 2>/dev/null || true
            apt autoremove -y 2>/dev/null || true
            ;;
        yum|dnf)
            $pm remove -y python3 python3-pip 2>/dev/null || true
            ;;
    esac
    echo ">>> 旧版本已卸载"

    echo ""
    echo ">>> 步骤 2/3: 编译安装 Python ${LATEST_PY_VER}..."
    install_python_from_source "$LATEST_PY_VER"

    echo ""
    echo ">>> 步骤 3/3: 验证安装..."
    # 确保 /usr/local/bin 优先
    export PATH="/usr/local/bin:$PATH"
    if ! /usr/local/bin/python3 --version &> /dev/null; then
        echo "❌ Python 安装失败，请手动安装 Python ${MIN_PY_MAJOR}.${MIN_PY_MINOR}+"
        exit 1
    fi

    NEW_PY_VER=$(/usr/local/bin/python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    echo "✅ Python 已升级到: ${NEW_PY_VER}"

    # 添加环境变量提示
    if ! grep -q "/usr/local/bin" /etc/profile.d/python3.sh 2>/dev/null; then
        echo 'export PATH="/usr/local/bin:$PATH"' > /etc/profile.d/python3.sh
        chmod +x /etc/profile.d/python3.sh
        echo ">>> 已添加 /usr/local/bin 到系统 PATH"
    fi
else
    echo "✅ Python 版本满足要求"
fi

# 创建目录
echo "[2/5] 部署文件到 ${BOT_DIR}..."
mkdir -p "$BOT_DIR"
cp -r bot.py config.json requirements.txt start.sh "$BOT_DIR/"

# 创建虚拟环境并安装依赖
echo "[3/5] 创建虚拟环境并安装依赖..."
cd "$BOT_DIR"
# 优先使用 /usr/local/bin/python3（源码安装的新版本）
PYTHON3_BIN=$(command -v python3)
if [ -x /usr/local/bin/python3 ]; then
    PYTHON3_BIN=/usr/local/bin/python3
fi
echo ">>> 使用: ${PYTHON3_BIN} ($(${PYTHON3_BIN} --version))"
${PYTHON3_BIN} -m venv venv
source venv/bin/activate
pip install -r requirements.txt -q

# 安装 systemd 服务
echo "[4/5] 配置开机自启服务..."
# 更新 service 文件中的 Python 路径
sed -i "s|ExecStart=.*|ExecStart=${BOT_DIR}/venv/bin/python bot.py|" /etc/systemd/system/telegram-bot.service 2>/dev/null || true
cp telegram-bot.service /etc/systemd/system/ 2>/dev/null || true
systemctl daemon-reload
systemctl enable telegram-bot
systemctl start telegram-bot

echo ""
echo "[5/5] 部署完成！"

echo ""
echo "========================================"
echo "  ✅ 部署完成！"
echo "========================================"
echo ""
echo "常用命令："
echo "  查看状态:  systemctl status telegram-bot"
echo "  启动:      systemctl start telegram-bot"
echo "  停止:      systemctl stop telegram-bot"
echo "  重启:      systemctl restart telegram-bot"
echo "  查看日志:  journalctl -u telegram-bot -f"
echo ""
echo "⚠️  注意："
echo "  1. 如果服务器在国内，需修改 ${BOT_DIR}/config.json 中的 proxy"
echo "  2. 如果服务器在海外，将 proxy 设为空字符串 \"\""
echo "  3. 修改配置后需重启: systemctl restart telegram-bot"
