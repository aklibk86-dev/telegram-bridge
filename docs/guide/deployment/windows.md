# Windows 部署

TeleBridge 在 Windows 上提供多种部署方式。

## 前提条件

- Python 3.8 或更高版本（[下载地址](https://www.python.org/downloads/)，安装时勾选 "Add Python to PATH"）

---

## 方式一：PowerShell 一键安装（推荐）

在 PowerShell 中执行一行命令即可完成安装：

```powershell
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
```

脚本特性：

- 自动检测 Python 3.8+ 环境
- 自动克隆仓库（无 git 时自动回退到 ZIP 下载）
- 创建虚拟环境并安装依赖
- 交互式引导配置 Bot Token、管理员用户名、代理地址
- 配置完成后自动启动机器人
- PowerShell 原生支持 UTF-8，中文显示无乱码

### 高级选项

下载 `install.ps1` 后可使用以下选项：

```powershell
# 下载脚本
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 -OutFile install.ps1

# 指定安装目录
powershell -ExecutionPolicy Bypass -File install.ps1 -InstallDir "D:\mybot"

# 通过 irm | iex 传参（先设环境变量）
$env:TB_INSTALL_DIR = "D:\mybot"
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex

# 更新模式（git pull + 更新依赖）
$env:TB_UPDATE = "1"
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex

# 安装但不自动启动
$env:TB_NO_START = "1"
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
```

::: tip 执行策略
如下载脚本后无法运行，提示执行策略限制，请使用：
```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```
:::

### 后续启动

安装完成后，可通过以下方式启动机器人：

```powershell
cd $env:USERPROFILE\telegram-bridge   # 或你指定的安装目录
.\venv\Scripts\Activate.ps1
python bot.py
```

或直接双击项目目录中的 `start.bat`。

---

## 方式二：批处理脚本（双击运行）

如果不熟悉 PowerShell，可下载 [install.bat](https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.bat) 后双击运行。

::: warning
`install.bat` 通过 `irm | cmd` 管道执行时可能出现中文乱码或交互输入失效，**推荐使用 PowerShell 脚本** `install.ps1`。下载后双击运行 `install.bat` 是安全的。
:::

---

## 方式三：手动部署

### 1. 下载项目

```powershell
git clone https://github.com/aklibk86-dev/telegram-bridge.git
cd telegram-bridge
```

或直接下载 [ZIP 压缩包](https://github.com/aklibk86-dev/telegram-bridge/archive/refs/heads/main.zip) 并解压。

### 2. 创建虚拟环境并安装依赖

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 3. 配置 `config.json`

参考 [快速开始](../getting-started#第三步-配置与启动) 中的配置说明，填写 Bot Token 和管理员用户名。

### 4. 启动机器人

```powershell
python bot.py
```

或双击 `start.bat`。

---

## 开机自启

Windows 不支持 systemd，可通过以下方式实现开机自启：

### 方法一：启动文件夹（推荐，简单）

1. 创建一个 `bot.vbs` 文件，内容如下：

```vb
Set WinScriptHost = CreateObject("WScript.Shell")
WinScriptHost.Run Chr(34) & "C:\path\to\telegram-bridge\start.bat" & Chr(34), 0
Set WinScriptHost = Nothing
```

将 `C:\path\to\telegram-bridge` 替换为你的实际安装路径。

2. 按 `Win + R` 打开运行窗口，输入 `shell:startup` 回车

3. 将 `bot.vbs` 文件复制到打开的启动文件夹中

重启后机器人会自动在后台启动，无控制台窗口。

### 方法二：任务计划程序（更可控）

1. 打开「任务计划程序」（`taskschd.msc`）
2. 创建基本任务，名称填 `TeleBridge`
3. 触发器选择「当我登录时」
4. 操作选择「启动程序」
5. 程序路径填 `C:\path\to\telegram-bridge\start.bat`
6. 起始位置填 `C:\path\to\telegram-bridge`
7. 完成后可在任务计划程序中管理此任务

### 方法三：后台运行（不开机自启）

使用 `pythonw.exe` 在后台运行（不显示控制台窗口）：

```powershell
.\venv\Scripts\pythonw.exe bot.py
```

结束进程时需通过任务管理器查找 `pythonw.exe` 结束。

---

## 代理配置

如需要代理，在 `config.json` 中设置：

```json
{
  "proxy": "http://127.0.0.1:7890"
}
```

海外服务器留空即可：`"proxy": ""`。

---

## 更新机器人

### 一键脚本更新

```powershell
$env:TB_UPDATE = "1"
irm https://raw.githubusercontent.com/aklibk86-dev/telegram-bridge/main/install.ps1 | iex
```

### 手动更新

```powershell
cd $env:USERPROFILE\telegram-bridge   # 或你的安装目录
git pull
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt   # 如果依赖有变化

# 重启：先结束当前运行的 bot.py 进程，再重新启动
python bot.py
```
