@echo off
chcp 65001 >nul 2>&1
title Telegram 双向机器人

echo ========================================
echo   Telegram 双向机器人
echo ========================================
echo.

:: 检查 Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请先安装 Python 3.8+
    pause
    exit /b 1
)

:: 安装依赖
echo [1/2] 检查并安装依赖...
pip install -r requirements.txt -q

:: 启动机器人
echo [2/2] 启动机器人...
echo.
echo 按 Ctrl+C 可停止机器人
echo.
python bot.py

pause
