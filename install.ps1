# ============================================================
#  TeleBridge - 一键安装脚本（Windows PowerShell）
# ------------------------------------------------------------
#  用法：
#    1) PowerShell 一键安装（推荐）：
#       irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
#
#    2) 下载后运行：
#       powershell -ExecutionPolicy Bypass -File install.ps1
#
#    3) 指定安装目录（下载运行时）：
#       powershell -ExecutionPolicy Bypass -File install.ps1 -InstallDir "D:\mybot"
#
#    4) 通过 irm | iex 传参：先设环境变量再执行
#       $env:TB_INSTALL_DIR = "D:\mybot"; irm ... | iex
#       $env:TB_UPDATE = "1"; irm ... | iex    # 更新模式
#       $env:TB_NO_START = "1"; irm ... | iex  # 不自动启动
# ============================================================

param(
    [string]$InstallDir = "$env:USERPROFILE\telegram-bridge"
)

# 强制使用 UTF-8 输出，避免中文乱码
$OutputEncoding = [System.Text.Encoding]::UTF8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { [Console]::InputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# 解决 TLS 问题（旧版 PowerShell 默认 TLS 1.0 导致 GitHub 下载失败）
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {}

# 从环境变量读取选项（供 irm | iex 使用）
$NoStart = ($env:TB_NO_START -eq "1") -or ($PSBoundParameters.ContainsKey("NoStart"))
$Update  = ($env:TB_UPDATE -eq "1") -or ($PSBoundParameters.ContainsKey("Update"))
if ($env:TB_INSTALL_DIR) { $InstallDir = $env:TB_INSTALL_DIR }

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/aklibk86-dev/telegram-bridge.git"
$RepoBranch = "main"
$MinPyVersion = [version]"3.8.0"

# ---------- 辅助函数 ----------
function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Step { param([string]$msg) Write-Host "`n=== $msg ===" -ForegroundColor Magenta }

function Test-Command {
    param([string]$cmd)
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Get-PythonInfo {
    foreach ($bin in @("python", "python3", "py")) {
        if (Test-Command $bin) {
            try {
                $verStr = & $bin -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null
                if ($verStr) {
                    $ver = [version]$verStr.Trim()
                    return @{ Binary = $bin; Version = $ver; VersionStr = $verStr.Trim() }
                }
            } catch {}
        }
    }
    return $null
}

# ---------- 横幅 ----------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   TeleBridge - Telegram 双向机器人 一键安装" -ForegroundColor Cyan
Write-Host "   仓库: https://github.com/aklibk86-dev/telegram-bridge" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 1. 检查 Python ----------
Write-Step "第 1 步：检查 Python 环境"

$pyInfo = Get-PythonInfo
if (-not $pyInfo) {
    Write-Err "未检测到 Python，请先安装 Python 3.8+"
    Write-Host "  下载地址: https://www.python.org/downloads/"
    Write-Host "  安装时请勾选 'Add Python to PATH'"
    exit 1
}

if ($pyInfo.Version -lt $MinPyVersion) {
    Write-Err "Python 版本过低（$($pyInfo.VersionStr)），需要 $MinPyVersion+"
    Write-Host "  下载地址: https://www.python.org/downloads/"
    exit 1
}

$PyBin = $pyInfo.Binary
Write-Ok "检测到 Python $($pyInfo.VersionStr)（$PyBin）"

# ---------- 2. 检查 git ----------
Write-Step "第 2 步：检查 git"

$UseZip = $false
if (-not (Test-Command "git")) {
    Write-Warn "未检测到 git，将使用 ZIP 方式下载"
    $UseZip = $true
} else {
    Write-Ok "git 已就绪"
}

# ---------- 3. 下载/更新代码 ----------
Write-Step "第 3 步：获取代码"

if (Test-Path "$InstallDir\.git") {
    if ($Update) {
        Write-Info "更新已存在的安装: $InstallDir"
        Push-Location $InstallDir
        git fetch --quiet origin
        git reset --hard "origin/$RepoBranch" 2>$null
        if ($LASTEXITCODE -ne 0) { git pull --ff-only }
        Write-Ok "代码已更新到最新版本"
        Pop-Location
    } else {
        Write-Warn "目录已存在且为 git 仓库: $InstallDir"
        $pullConfirm = Read-Host "是否拉取最新代码？(y/N)"
        if ($pullConfirm -match "^[yY]$") {
            Push-Location $InstallDir
            git fetch --quiet origin
            git reset --hard "origin/$RepoBranch" 2>$null
            if ($LASTEXITCODE -ne 0) { git pull --ff-only }
            Write-Ok "代码已更新"
            Pop-Location
        } else {
            Write-Info "保留现有代码"
        }
    }
} else {
    # 目录非空处理
    if ((Test-Path $InstallDir) -and (Get-ChildItem $InstallDir -Force -ErrorAction SilentlyContinue)) {
        Write-Warn "目标目录非空: $InstallDir"
        $clearConfirm = Read-Host "是否清空并重新下载？(y/N)"
        if ($clearConfirm -match "^[yY]$") {
            Remove-Item -Recurse -Force $InstallDir
        } else {
            $InstallDir = "$InstallDir-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Write-Warn "改用新目录: $InstallDir"
        }
    }

    if ($UseZip) {
        Write-Info "使用 ZIP 方式下载..."
        $zipUrl = "https://github.com/aklibk86-dev/telegram-bridge/archive/refs/heads/$RepoBranch.zip"
        $tmpZip = Join-Path $env:TEMP "telegram-bridge.zip"
        $extractDir = Join-Path $env:TEMP "telegram-bridge-extract"

        $oldProgress = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
            if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
            Expand-Archive -Path $tmpZip -DestinationPath $extractDir -Force
            $innerDir = Join-Path $extractDir "telegram-bridge-$RepoBranch"
            if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
            Move-Item $innerDir $InstallDir
            Write-Ok "代码下载完成"
        } catch {
            Write-Err "下载失败: $_"
            Write-Host "  请检查网络连接或手动克隆仓库。"
            exit 1
        } finally {
            $ProgressPreference = $oldProgress
            Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
            Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue
        }
    } else {
        Write-Info "克隆仓库到: $InstallDir"
        git clone --depth 1 -b $RepoBranch $RepoUrl $InstallDir
        if ($LASTEXITCODE -ne 0) {
            Write-Err "克隆失败，请检查网络连接。"
            exit 1
        }
        Write-Ok "代码克隆完成"
    }
}

Set-Location $InstallDir

# ---------- 4. 创建虚拟环境并安装依赖 ----------
Write-Step "第 4 步：创建虚拟环境并安装依赖"

Write-Info "使用 Python: $PyBin ($(& $PyBin --version 2>&1))"

if (-not (Test-Path "venv")) {
    & $PyBin -m venv venv
    if ($LASTEXITCODE -ne 0) {
        Write-Err "创建虚拟环境失败"
        exit 1
    }
}

# 激活虚拟环境
$activateScript = Join-Path $InstallDir "venv\Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    & $activateScript
}

Write-Info "升级 pip..."
& python -m pip install --upgrade pip -q

Write-Info "安装依赖..."
pip install -r requirements.txt -q
if ($LASTEXITCODE -ne 0) {
    Write-Err "依赖安装失败"
    exit 1
}
Write-Ok "依赖安装完成"

# ---------- 5. 配置文件 ----------
Write-Step "第 5 步：配置机器人"

# 读取现有配置作为默认值
$currentToken = ""
$currentProxy = ""
$currentAdmin = ""
if (Test-Path "config.json") {
    try {
        $cfg = Get-Content "config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
        $currentToken = $cfg.bot_token
        $currentProxy = $cfg.proxy
        $currentAdmin = $cfg.admin_username
    } catch {}
}

$needConfig = $true
if ($currentToken -and $currentToken -ne "YOUR_BOT_TOKEN_HERE") {
    $reconf = Read-Host "已存在配置，是否重新配置？(y/N)"
    if ($reconf -notmatch "^[yY]$") { $needConfig = $false }
}

if ($needConfig) {
    Write-Host ""
    Write-Host "请按提示输入配置信息："
    Write-Host "  - Bot Token: 从 @BotFather 获取的 Token"
    Write-Host "  - 管理员用户名: 你的 Telegram 用户名（不带 @）"
    Write-Host "  - 代理地址: 海外服务器留空，国内服务器填写本地代理（如 http://127.0.0.1:7890）"
    Write-Host ""

    # Bot Token 输入（带校验）
    $botToken = ""
    do {
        $botToken = Read-Host "请输入 Bot Token（从 @BotFather 获取）"
        if (-not $botToken) {
            Write-Warn "Token 不能为空，请重新输入"
        } elseif ($botToken -notmatch "^\d+:[A-Za-z0-9_-]+$") {
            Write-Warn "Token 格式看起来不正确（应为 123456:ABCxxx 格式），请重新输入"
            $botToken = ""
        }
    } until ($botToken)

    # 管理员用户名
    if ($currentAdmin) {
        $adminInput = Read-Host "管理员用户名（不带 @）[$currentAdmin]"
        $adminUsername = if ($adminInput) { $adminInput } else { $currentAdmin }
    } else {
        $adminUsername = Read-Host "管理员用户名（不带 @）"
    }

    # 代理地址
    if ($currentProxy) {
        $proxyInput = Read-Host "代理地址（海外留空）[$currentProxy]"
        $proxyUrl = if ($proxyInput) { $proxyInput } else { $currentProxy }
    } else {
        $proxyUrl = Read-Host "代理地址（海外留空）"
    }

    # 使用 PowerShell 原生 JSON 处理写入 config.json
    $configPath = Join-Path (Get-Location) "config.json"

    # 读取现有配置（PSCustomObject）
    $cfgObj = $null
    if (Test-Path $configPath) {
        try {
            $cfgObj = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $cfgObj = $null
        }
    }
    if (-not $cfgObj) { $cfgObj = [PSCustomObject]@{} }

    # 更新核心字段
    $cfgObj | Add-Member -NotePropertyName "bot_token" -NotePropertyValue $botToken -Force
    $cfgObj | Add-Member -NotePropertyName "admin_username" -NotePropertyValue $adminUsername -Force
    $cfgObj | Add-Member -NotePropertyName "proxy" -NotePropertyValue $proxyUrl -Force

    # 确保必要字段存在
    $defaults = @{
        auto_reply              = "✅ 您的消息已收到，我们会尽快回复您！"
        auto_reply_delete_time  = 3
        welcome_message         = "👋 欢迎使用机器人！`n`n您可以直接发送消息，我们会收到并回复。"
        keywords                = @{}
        inline_buttons          = @()
        auto_reply_buttons      = @()
        welcome_buttons         = @()
        broadcast_buttons       = @()
        reply_keyboard          = @()
    }
    foreach ($key in $defaults.Keys) {
        if (-not ($cfgObj.PSObject.Properties.Name -contains $key)) {
            $cfgObj | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key]
        }
    }

    # 写入 JSON（UTF-8 无 BOM，保留中文）
    $jsonStr = $cfgObj | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($configPath, $jsonStr, (New-Object System.Text.UTF8Encoding $false))

    Write-Ok "配置已保存到 config.json"
} else {
    Write-Ok "保留现有配置"
}

# ---------- 6. 启动 ----------
Write-Step "第 6 步：启动机器人"

if (-not $NoStart) {
    Write-Info "直接启动（前台运行，按 Ctrl+C 停止）..."
    Write-Host ""
    & python bot.py
} else {
    Write-Info "已跳过自动启动"
}

# ---------- 完成 ----------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   TeleBridge 安装完成！" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "安装目录:  $InstallDir"
Write-Host ""
Write-Host "后续启动:"
Write-Host "  双击 start.bat"
Write-Host "  或命令行:"
Write-Host "    cd $InstallDir"
Write-Host "    .\venv\Scripts\Activate.ps1"
Write-Host "    python bot.py"
Write-Host ""
Write-Host "后续操作:"
Write-Host "  1. 用管理员账号给机器人发送 /start 完成管理员注册"
Write-Host "  2. 发送 /settings 打开交互式设置面板"
Write-Host "  3. 修改 config.json 后重启机器人生效"
Write-Host ""
Write-Host "文档: https://github.com/aklibk86-dev/telegram-bridge"
Write-Host "交流群: https://t.me/kqxw_chat"
Write-Host "============================================================"
