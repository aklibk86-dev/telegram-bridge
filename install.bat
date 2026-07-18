@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
title TeleBridge 一键安装

REM ============================================================
REM  TeleBridge - 一键安装脚本（Windows）
REM ------------------------------------------------------------
REM  用法：
REM    1) PowerShell 一键安装（推荐）：
REM       irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.bat | cmd
REM
REM    2) 下载后双击运行 install.bat
REM
REM    3) 命令行运行：
REM       install.bat [安装目录]
REM ============================================================

set "REPO_URL=https://github.com/aklibk86-dev/telegram-bridge.git"
set "REPO_BRANCH=main"
set "INSTALL_DIR=%USERPROFILE%\telegram-bridge"

REM 解析参数
if not "%~1"=="" (
    if /i not "%~1"=="--help" if /i not "%~1"=="-h" (
        set "INSTALL_DIR=%~1"
    ) else (
        echo 用法: install.bat [安装目录]
        exit /b 0
    )
)

echo.
echo ============================================================
echo    TeleBridge - Telegram 双向机器人 一键安装
echo    仓库: https://github.com/aklibk86-dev/telegram-bridge
echo ============================================================
echo.

REM ---------- 1. 检查 Python ----------
echo === 第 1 步：检查 Python 环境 ===

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 未检测到 Python，请先安装 Python 3.8+
    echo         下载地址: https://www.python.org/downloads/
    echo         安装时请勾选 "Add Python to PATH"
    echo.
    pause
    exit /b 1
)

for /f "delims=" %%i in ('python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2^>nul') do set "PY_VER=%%i"

if not defined PY_VER (
    echo [ERROR] 无法获取 Python 版本，请确认 Python 安装正确。
    pause
    exit /b 1
)

echo [OK] 检测到 Python %PY_VER%

REM 检查版本 >= 3.8.0
for /f "tokens=1,2,3 delims=." %%a in ("%PY_VER%") do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
)

if %PY_MAJOR% LSS 3 (
    echo [ERROR] Python 版本过低（%PY_VER%），需要 3.8.0+
    echo         下载地址: https://www.python.org/downloads/
    pause
    exit /b 1
)
if %PY_MAJOR% EQU 3 if %PY_MINOR% LSS 8 (
    echo [ERROR] Python 版本过低（%PY_VER%），需要 3.8.0+
    echo         下载地址: https://www.python.org/downloads/
    pause
    exit /b 1
)

REM ---------- 2. 检查 git ----------
echo.
echo === 第 2 步：检查 git ===

where git >nul 2>&1
if errorlevel 1 (
    echo [WARN] 未检测到 git，尝试使用 ZIP 下载方式...
    set "USE_ZIP=1"
) else (
    set "USE_ZIP=0"
    echo [OK] git 已就绪
)

REM ---------- 3. 下载/更新代码 ----------
echo.
echo === 第 3 步：获取代码 ===

if exist "%INSTALL_DIR%\.git" (
    echo [INFO] 目录已存在且为 git 仓库: %INSTALL_DIR%
    set /p "PULL_CONFIRM=是否拉取最新代码？(y/N): "
    if /i "!PULL_CONFIRM!"=="y" (
        cd /d "%INSTALL_DIR%"
        git fetch --quiet origin
        git reset --hard "origin/%REPO_BRANCH%" >nul 2>&1
        if errorlevel 1 git pull --ff-only
        echo [OK] 代码已更新
    ) else (
        echo [INFO] 保留现有代码
        cd /d "%INSTALL_DIR%"
    )
) else (
    if exist "%INSTALL_DIR%" (
        dir /a /b "%INSTALL_DIR%" 2>nul | findstr "." >nul
        if not errorlevel 1 (
            echo [WARN] 目标目录非空: %INSTALL_DIR%
            set /p "CLEAR_CONFIRM=是否清空并重新克隆？(y/N): "
            if /i "!CLEAR_CONFIRM!"=="y" (
                rmdir /s /q "%INSTALL_DIR%"
            ) else (
                set "INSTALL_DIR=%INSTALL_DIR%-%RANDOM%"
                echo [WARN] 改用新目录: %INSTALL_DIR%
            )
        )
    )

    if "!USE_ZIP!"=="1" (
        echo [INFO] 使用 ZIP 方式下载...
        REM 使用 PowerShell 下载并解压
        powershell -NoProfile -Command ^
            "$ProgressPreference='SilentlyContinue';" ^
            "$url='https://github.com/aklibk86-dev/telegram-bridge/archive/refs/heads/%REPO_BRANCH%.zip';" ^
            "$tmp='$env:TEMP\telegram-bridge.zip';" ^
            "Invoke-WebRequest -Uri $url -OutFile $tmp;" ^
            "Expand-Archive -Path $tmp -DestinationPath '$env:TEMP\telegram-bridge-extract' -Force;" ^
            "if (Test-Path '%INSTALL_DIR%') { Remove-Item -Recurse -Force '%INSTALL_DIR%' }" ^
            "Move-Item '$env:TEMP\telegram-bridge-extract\telegram-bridge-%REPO_BRANCH%' '%INSTALL_DIR%';" ^
            "Remove-Item $tmp -Force;" ^
            "Remove-Item -Recurse -Force '$env:TEMP\telegram-bridge-extract'"
        if errorlevel 1 (
            echo [ERROR] 下载失败，请检查网络或手动克隆仓库。
            pause
            exit /b 1
        )
        cd /d "%INSTALL_DIR%"
        echo [OK] 代码下载完成
    ) else (
        echo [INFO] 克隆仓库到: %INSTALL_DIR%
        git clone --depth 1 -b "%REPO_BRANCH%" "%REPO_URL%" "%INSTALL_DIR%"
        if errorlevel 1 (
            echo [ERROR] 克隆失败，请检查网络连接。
            pause
            exit /b 1
        )
        cd /d "%INSTALL_DIR%"
        echo [OK] 代码克隆完成
    )
)

REM ---------- 4. 创建虚拟环境并安装依赖 ----------
echo.
echo === 第 4 步：创建虚拟环境并安装依赖 ===

if not exist "venv" (
    python -m venv venv
    if errorlevel 1 (
        echo [ERROR] 创建虚拟环境失败
        pause
        exit /b 1
    )
)

call venv\Scripts\activate.bat

echo [INFO] 升级 pip...
python -m pip install --upgrade pip -q

echo [INFO] 安装依赖...
pip install -r requirements.txt -q
if errorlevel 1 (
    echo [ERROR] 依赖安装失败
    pause
    exit /b 1
)
echo [OK] 依赖安装完成

REM ---------- 5. 配置文件 ----------
echo.
echo === 第 5 步：配置机器人 ===

REM 读取现有配置作为默认值
set "CURRENT_TOKEN="
set "CURRENT_PROXY="
set "CURRENT_ADMIN="
if exist "config.json" (
    for /f "delims=" %%i in ('python -c "import json;print(json.load(open('config.json',encoding='utf-8')).get('bot_token',''))" 2^>nul') do set "CURRENT_TOKEN=%%i"
    for /f "delims=" %%i in ('python -c "import json;print(json.load(open('config.json',encoding='utf-8')).get('proxy',''))" 2^>nul') do set "CURRENT_PROXY=%%i"
    for /f "delims=" %%i in ('python -c "import json;print(json.load(open('config.json',encoding='utf-8')).get('admin_username',''))" 2^>nul') do set "CURRENT_ADMIN=%%i"
)

set "NEED_CONFIG=1"
if not "%CURRENT_TOKEN%"=="" if not "%CURRENT_TOKEN%"=="YOUR_BOT_TOKEN_HERE" (
    set /p "RECONF=已存在配置，是否重新配置？(y/N): "
    if /i not "!RECONF!"=="y" set "NEED_CONFIG=0"
)

if "!NEED_CONFIG!"=="1" (
    echo.
    echo 请按提示输入配置信息：
    echo   - Bot Token: 从 @BotFather 获取的 Token
    echo   - 管理员用户名: 你的 Telegram 用户名（不带 @）
    echo   - 代理地址: 海外服务器留空，国内服务器填写本地代理（如 http://127.0.0.1:7890）
    echo.

    :ask_token
    set "BOT_TOKEN="
    set /p "BOT_TOKEN=请输入 Bot Token（从 @BotFather 获取）: "
    if "!BOT_TOKEN!"=="" (
        echo [WARN] Token 不能为空，请重新输入
        goto ask_token
    )
    REM 简单校验 Token 格式：包含冒号
    echo !BOT_TOKEN! | findstr /r "^[0-9]*:[A-Za-z0-9_-]*$" >nul
    if errorlevel 1 (
        echo [WARN] Token 格式看起来不正确（应为 123456:ABCxxx 格式），请重新输入
        goto ask_token
    )

    if "!CURRENT_ADMIN!"=="" (
        set /p "ADMIN_USERNAME=管理员用户名（不带 @）: "
    ) else (
        set /p "ADMIN_USERNAME=管理员用户名（不带 @）[!CURRENT_ADMIN!]: "
        if "!ADMIN_USERNAME!"=="" set "ADMIN_USERNAME=!CURRENT_ADMIN!"
    )

    if "!CURRENT_PROXY!"=="" (
        set /p "PROXY_URL=代理地址（海外留空）: "
    ) else (
        set /p "PROXY_URL=代理地址（海外留空）[!CURRENT_PROXY!]: "
        if "!PROXY_URL!"=="" set "PROXY_URL=!CURRENT_PROXY!"
    )

    REM 使用 Python 安全地更新 config.json
    python -c "import json;cfg=json.load(open('config.json',encoding='utf-8')) if __import__('os').path.exists('config.json') else {};cfg['bot_token']='!BOT_TOKEN!';cfg['admin_username']='!ADMIN_USERNAME!';cfg['proxy']='!PROXY_URL!';cfg.setdefault('auto_reply','✅ 您的消息已收到，我们会尽快回复您！');cfg.setdefault('auto_reply_delete_time',3);cfg.setdefault('welcome_message','👋 欢迎使用机器人！\n\n您可以直接发送消息，我们会收到并回复。');cfg.setdefault('keywords',{});cfg.setdefault('inline_buttons',[]);cfg.setdefault('auto_reply_buttons',[]);cfg.setdefault('welcome_buttons',[]);cfg.setdefault('broadcast_buttons',[]);cfg.setdefault('reply_keyboard',[]);json.dump(cfg,open('config.json','w',encoding='utf-8'),ensure_ascii=False,indent=2);print('config.json 已写入')"
    echo [OK] 配置已保存到 config.json
) else (
    echo [OK] 保留现有配置
)

REM ---------- 6. 启动 ----------
echo.
echo === 第 6 步：启动机器人 ===

echo [INFO] 直接启动（前台运行，按 Ctrl+C 停止）...
echo.
python bot.py

echo.
echo ============================================================
echo    TeleBridge 安装完成！
echo ============================================================
echo.
echo 安装目录:  %INSTALL_DIR%
echo.
echo 后续启动:
echo   双击 start.bat
echo   或命令行:
echo     cd /d %INSTALL_DIR%
echo     call venv\Scripts\activate.bat
echo     python bot.py
echo.
echo 后续操作:
echo   1. 用管理员账号给机器人发送 /start 完成管理员注册
echo   2. 发送 /settings 打开交互式设置面板
echo   3. 修改 config.json 后重启机器人生效
echo.
echo 文档: https://github.com/aklibk86-dev/telegram-bridge
echo 交流群: https://t.me/kqxw_chat
echo ============================================================
echo.
pause
