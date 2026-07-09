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

# 检查 Python3
if ! command -v python3 &> /dev/null; then
    echo "[1/4] 安装 Python3..."
    if command -v apt &> /dev/null; then
        apt update && apt install -y python3 python3-venv python3-pip
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-venv
    else
        echo "❌ 无法自动安装 Python3，请手动安装"
        exit 1
    fi
fi
echo "✅ Python3: $(python3 --version)"

# 创建目录
echo "[2/4] 部署文件到 ${BOT_DIR}..."
mkdir -p "$BOT_DIR"
cp -r bot.py config.json requirements.txt start.sh "$BOT_DIR/"

# 创建虚拟环境并安装依赖
echo "[3/4] 创建虚拟环境并安装依赖..."
cd "$BOT_DIR"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt -q

# 安装 systemd 服务
echo "[4/4] 配置开机自启服务..."
cp telegram-bot.service /etc/systemd/system/ 2>/dev/null || true
systemctl daemon-reload
systemctl enable telegram-bot
systemctl start telegram-bot

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
