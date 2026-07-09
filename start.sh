#!/bin/bash
# Telegram 双向机器人 - Linux 启动脚本

cd "$(dirname "$0")"

echo "========================================"
echo "  Telegram 双向机器人"
echo "========================================"
echo ""

# 检查 Python3
if ! command -v python3 &> /dev/null; then
    echo "[错误] 未找到 python3，请先安装 Python 3.8+"
    exit 1
fi

echo "Python 版本: $(python3 --version)"

# 检查并创建虚拟环境
if [ ! -d "venv" ]; then
    echo "[1/3] 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
echo "[2/3] 检查并安装依赖..."
pip install -r requirements.txt -q

# 启动机器人
echo "[3/3] 启动机器人..."
echo ""
echo "按 Ctrl+C 可停止机器人"
echo ""
python bot.py
