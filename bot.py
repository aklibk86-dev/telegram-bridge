#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Telegram 双向机器人（交互式设置版）
=====================================
功能：
  1. 双向通信 - 用户消息转发给管理员，管理员可回复
  2. 消息按钮 - InlineKeyboard 消息内联按钮（菜单/自动回复/欢迎/广播各自独立）
  3. 底部按钮 - ReplyKeyboard 底部持久键盘
  4. 自动回复 - 每条用户消息自动回复（可附带内联按钮）
  5. 关键词回复 - 关键词触发自动回复
  6. 广播通知 - 管理员广播消息给所有用户（可附带内联按钮）
  7. 交互式设置 - 管理员可在 Telegram 中直接设置所有配置
"""

import json
import os
import logging
import asyncio
from datetime import datetime
from collections import OrderedDict

from telegram import (
    Update,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    ReplyKeyboardMarkup,
    ReplyKeyboardRemove,
)
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    ContextTypes,
    filters,
)
from telegram.request import HTTPXRequest
from telegram.constants import ParseMode

# ==================== 路径配置 ====================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Docker 环境使用 /app/data 目录持久化数据，本地环境使用项目目录
DATA_DIR = os.environ.get("DATA_DIR", BASE_DIR)
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR, exist_ok=True)
CONFIG_FILE = os.path.join(BASE_DIR, "config.json")
USERS_FILE = os.path.join(DATA_DIR, "users.json")
LOG_FILE = os.path.join(DATA_DIR, "bot.log")

# ==================== JSON 工具 ====================

def load_json(path, default=None):
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return default
    return default

def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def load_config():
    return load_json(CONFIG_FILE, {})

def save_config(cfg):
    save_json(CONFIG_FILE, cfg)

def load_users():
    data = load_json(USERS_FILE, None)
    if data is None:
        return {"users": {}, "admin_chat_id": None}
    if "users" not in data:
        data["users"] = {}
    if "admin_chat_id" not in data:
        data["admin_chat_id"] = None
    return data

# ==================== 动态配置读取 ====================

def get_config():
    return load_config()

def get_auto_reply():
    return get_config().get("auto_reply", "")

def get_welcome_message():
    return get_config().get("welcome_message", "👋 欢迎使用！")

def get_keywords():
    return get_config().get("keywords", {})

def get_kw_reply(kw, key):
    """获取关键词的回复文字（兼容旧格式）"""
    val = kw.get(key, "")
    if isinstance(val, dict):
        return val.get("reply", "")
    return val

def get_kw_buttons(kw, key):
    """获取关键词的按钮列表（兼容旧格式）"""
    val = kw.get(key, "")
    if isinstance(val, dict):
        return val.get("buttons", [])
    return []

def set_kw_data(kw, key, reply=None, buttons=None):
    """设置关键词的回复和按钮"""
    old_val = kw.get(key, {})
    if isinstance(old_val, str):
        old_val = {"reply": old_val, "buttons": []}
    elif not isinstance(old_val, dict):
        old_val = {}
    if reply is not None:
        old_val["reply"] = reply
    if buttons is not None:
        old_val["buttons"] = buttons
    kw[key] = old_val
    return kw

def get_reply_keyboard_config():
    return get_config().get("reply_keyboard", [])

# --- 按钮作用域管理 ---
# scope → config 字段名
BUTTON_SCOPES = {
    "menu": "inline_buttons",          # /menu 菜单按钮
    "auto_reply": "auto_reply_buttons", # 自动回复按钮
    "welcome": "welcome_buttons",       # 欢迎消息按钮
    "broadcast": "broadcast_buttons",   # 广播消息按钮
}

SCOPE_LABELS = {
    "menu": "📋 菜单按钮",
    "auto_reply": "✏️ 自动回复按钮",
    "welcome": "👋 欢迎消息按钮",
    "broadcast": "📢 广播消息按钮",
}

def get_buttons(scope):
    """获取指定作用域的按钮列表"""
    field = BUTTON_SCOPES.get(scope, "inline_buttons")
    return get_config().get(field, [])

def save_buttons(scope, buttons):
    """保存指定作用域的按钮列表"""
    cfg = get_config()
    field = BUTTON_SCOPES.get(scope, "inline_buttons")
    cfg[field] = buttons
    save_config(cfg)

# 不变的配置（启动时读取一次）
_config_init = load_config()
BOT_TOKEN = _config_init.get("bot_token", "")
PROXY_URL = _config_init.get("proxy", "")
ADMIN_USERNAME = _config_init.get("admin_username", "").lstrip("@")

# ==================== 日志配置 ====================

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
    ],
)
logger = logging.getLogger("TelegramBot")

# ==================== 内存状态 ====================

forward_tracker = OrderedDict()
MAX_TRACKER_SIZE = 1000

# ==================== 工具函数 ====================

def is_admin(update: Update) -> bool:
    user = update.effective_user
    if not user:
        return False
    if user.username and user.username.lower() == ADMIN_USERNAME.lower():
        return True
    users_data = load_users()
    saved_id = users_data.get("admin_chat_id")
    if saved_id and str(update.effective_chat.id) == str(saved_id):
        return True
    return False

def register_user(update: Update):
    user = update.effective_user
    if not user:
        return
    users_data = load_users()
    user_id = str(user.id)
    is_new = user_id not in users_data["users"]
    users_data["users"][user_id] = {
        "username": user.username or "",
        "first_name": user.first_name or "",
        "last_name": user.last_name or "",
        "joined_at": users_data["users"].get(user_id, {}).get(
            "joined_at", datetime.now().isoformat()
        ),
        "last_active": datetime.now().isoformat(),
    }
    if user.username and user.username.lower() == ADMIN_USERNAME.lower():
        if users_data.get("admin_chat_id") != update.effective_chat.id:
            users_data["admin_chat_id"] = update.effective_chat.id
            logger.info(f"管理员已注册: chat_id={update.effective_chat.id}")
    save_json(USERS_FILE, users_data)
    if is_new:
        logger.info(f"新用户: {user.first_name} (@{user.username}) ID={user_id}")

def track_forward(message_id: int, user_chat_id: int):
    forward_tracker[message_id] = user_chat_id
    while len(forward_tracker) > MAX_TRACKER_SIZE:
        forward_tracker.popitem(last=False)

def get_reply_keyboard():
    kb = get_reply_keyboard_config()
    if not kb:
        return None
    return ReplyKeyboardMarkup(kb, resize_keyboard=True)

def build_kb_from_buttons(buttons):
    """从按钮列表构建 InlineKeyboardMarkup"""
    if not buttons:
        return None
    keyboard = []
    row = []
    for btn in buttons:
        if "url" in btn:
            row.append(InlineKeyboardButton(text=btn["text"], url=btn["url"]))
        elif "callback" in btn:
            row.append(InlineKeyboardButton(text=btn["text"], callback_data=btn["callback"][:64]))
        if len(row) >= 2:
            keyboard.append(row)
            row = []
    if row:
        keyboard.append(row)
    return InlineKeyboardMarkup(keyboard) if keyboard else None

def build_inline_keyboard():
    """构建 /menu 用的内联键盘"""
    return build_kb_from_buttons(get_buttons("menu"))

def build_auto_reply_kb():
    return build_kb_from_buttons(get_buttons("auto_reply"))

def build_welcome_kb():
    return build_kb_from_buttons(get_buttons("welcome"))

def build_broadcast_kb():
    return build_kb_from_buttons(get_buttons("broadcast"))

# ==================== 设置菜单构建器 ====================

def settings_main_kb():
    keyboard = [
        [InlineKeyboardButton("✏️ 自动回复", callback_data="set_auto_reply"),
         InlineKeyboardButton("👋 欢迎消息", callback_data="set_welcome")],
        [InlineKeyboardButton("🔑 关键词管理", callback_data="set_keywords"),
         InlineKeyboardButton("⌨️ 底部键盘", callback_data="set_keyboard")],
        [InlineKeyboardButton("📢 广播通知", callback_data="set_broadcast"),
         InlineKeyboardButton("📋 查看当前配置", callback_data="set_view")],
        [InlineKeyboardButton("🔄 重载配置", callback_data="set_reload"),
         InlineKeyboardButton("❌ 关闭设置", callback_data="set_close")],
    ]
    return InlineKeyboardMarkup(keyboard)

def keywords_kb():
    keyboard = [
        [InlineKeyboardButton("📋 查看关键词", callback_data="kw_view"),
         InlineKeyboardButton("➕ 添加关键词", callback_data="kw_add")],
        [InlineKeyboardButton("🔧 管理关键词", callback_data="kw_manage"),
         InlineKeyboardButton("➖ 删除关键词", callback_data="kw_del")],
        [InlineKeyboardButton("🗑️ 清空关键词", callback_data="kw_clear")],
        [InlineKeyboardButton("⬅️ 返回设置", callback_data="set_back")],
    ]
    return InlineKeyboardMarkup(keyboard)

def keyword_manage_kb(index):
    """单个关键词管理页：编辑回复 + 按钮管理"""
    kw = get_keywords()
    keys = list(kw.keys())
    if index < 0 or index >= len(keys):
        return None
    key = keys[index]
    btn_count = len(get_kw_buttons(kw, key))
    keyboard = [
        [InlineKeyboardButton("✏️ 编辑回复文字", callback_data=f"kw_edit_reply_{index}")],
        [InlineKeyboardButton(f"📋 查看按钮（{btn_count}个）", callback_data=f"kw_view_btn_{index}"),
         InlineKeyboardButton("➕ 添加URL按钮", callback_data=f"kw_add_url_{index}")],
        [InlineKeyboardButton("➖ 删除按钮", callback_data=f"kw_del_btn_{index}"),
         InlineKeyboardButton("🗑️ 清空按钮", callback_data=f"kw_clear_btn_{index}")],
        [InlineKeyboardButton("⬅️ 返回关键词管理", callback_data="kw_manage")],
    ]
    return InlineKeyboardMarkup(keyboard)

def message_settings_kb(scope):
    """消息设置页：编辑文字 + URL按钮管理（统一用于 自动回复/欢迎/广播）"""
    label = SCOPE_LABELS.get(scope, scope)
    btn_count = len(get_buttons(scope))
    keyboard = [
        [InlineKeyboardButton(f"✏️ 编辑{label}文字", callback_data=f"msg_edit_{scope}")],
        [InlineKeyboardButton(f"📋 查看按钮（{btn_count}个）", callback_data=f"msg_view_btn_{scope}"),
         InlineKeyboardButton("➕ 添加URL按钮", callback_data=f"msg_add_url_{scope}")],
        [InlineKeyboardButton("➖ 删除按钮", callback_data=f"msg_del_btn_{scope}"),
         InlineKeyboardButton("🗑️ 清空按钮", callback_data=f"msg_clear_btn_{scope}")],
        [InlineKeyboardButton("⬅️ 返回设置", callback_data="set_back")],
    ]
    return InlineKeyboardMarkup(keyboard)

def keyboard_kb():
    keyboard = [
        [InlineKeyboardButton("📋 查看底部键盘", callback_data="kb_view"),
         InlineKeyboardButton("➕ 添加按钮行", callback_data="kb_add")],
        [InlineKeyboardButton("🗑️ 清空键盘", callback_data="kb_clear"),
         InlineKeyboardButton("🔄 恢复默认", callback_data="kb_default")],
        [InlineKeyboardButton("⬅️ 返回设置", callback_data="set_back")],
    ]
    return InlineKeyboardMarkup(keyboard)

# ==================== 基本命令处理 ====================

async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if is_admin(update):
        text = get_welcome_message()
        text += "\n\n🔐 您已以管理员身份登录。\n💡 发送 /settings 可打开设置面板。"
        await update.message.reply_text(
            text, reply_markup=get_reply_keyboard(), parse_mode=ParseMode.HTML
        )
    else:
        await update.message.reply_text(
            get_welcome_message(),
            reply_markup=build_welcome_kb(),
            parse_mode=ParseMode.HTML,
        )

async def cmd_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if is_admin(update):
        text = (
            "🔐 <b>管理员帮助</b>\n\n"
            "<b>命令列表：</b>\n"
            "/start - 启动机器人\n"
            "/help - 查看帮助\n"
            "/menu - 打开菜单\n"
            "/settings - ⚙️ 交互式设置面板\n"
            "/broadcast &lt;消息&gt; - 广播给所有用户\n"
            "/stats - 查看统计\n"
            "/users - 查看用户列表\n"
            "/reply &lt;用户ID&gt; &lt;消息&gt; - 回复指定用户\n"
            "/id - 查看你的 Chat ID\n\n"
            "💡 <b>快捷回复：</b>直接回复转发过来的消息即可回复对应用户。"
        )
    else:
        text = "💬 您可以直接发送消息与我们对话。"
    await update.message.reply_text(text, parse_mode=ParseMode.HTML)

async def cmd_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if is_admin(update):
        await update.message.reply_text(
            "📋 <b>功能菜单</b>\n\n请点击下方按钮选择功能：",
            reply_markup=build_inline_keyboard(), parse_mode=ParseMode.HTML,
        )
    else:
        await update.message.reply_text("💬 请直接发送消息与我们对话。")

async def cmd_settings(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if not is_admin(update):
        await update.message.reply_text("⚠️ 此命令仅限管理员使用。")
        return
    context.user_data.pop("awaiting", None)
    context.user_data.pop("temp", None)
    await update.message.reply_text(
        "⚙️ <b>设置面板</b>\n\n请选择要设置的项：",
        reply_markup=settings_main_kb(), parse_mode=ParseMode.HTML,
    )

async def cmd_broadcast(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if not is_admin(update):
        await update.message.reply_text("⚠️ 此命令仅限管理员使用。")
        return
    if not context.args:
        await update.message.reply_text(
            "📢 <b>广播通知</b>\n\n用法：<code>/broadcast 消息内容</code>",
            parse_mode=ParseMode.HTML,
        )
        return
    await do_broadcast(update, context, " ".join(context.args))

async def do_broadcast(update_or_query, context, msg):
    users_data = load_users()
    status_msg = await context.bot.send_message(
        chat_id=update_or_query.effective_chat.id,
        text="📢 正在发送广播消息..."
    )
    kb = build_broadcast_kb()
    ok, fail = 0, 0
    for uid in list(users_data["users"].keys()):
        try:
            await context.bot.send_message(
                chat_id=int(uid),
                text=f"📢 <b>广播通知</b>\n\n{msg}",
                parse_mode=ParseMode.HTML,
                reply_markup=kb,
            )
            ok += 1
            await asyncio.sleep(0.05)
        except Exception as e:
            logger.warning(f"广播失败 {uid}: {e}")
            fail += 1
    await status_msg.edit_text(
        f"✅ <b>广播完成</b>\n\n📊 成功：{ok} 人\n❌ 失败：{fail} 人",
        parse_mode=ParseMode.HTML,
    )

async def cmd_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if not is_admin(update):
        await update.message.reply_text("⚠️ 此命令仅限管理员使用。")
        return
    users_data = load_users()
    await update.message.reply_text(
        f"📊 <b>统计信息</b>\n\n👥 总用户数：{len(users_data['users'])}\n"
        f"🤖 机器人状态：运行中\n🕐 当前时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        parse_mode=ParseMode.HTML,
    )

async def cmd_users(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if not is_admin(update):
        await update.message.reply_text("⚠️ 此命令仅限管理员使用。")
        return
    users_data = load_users()
    if not users_data["users"]:
        await update.message.reply_text("📭 暂无用户。")
        return
    lines = ["👥 <b>用户列表</b>\n"]
    for uid, info in users_data["users"].items():
        name = info.get("first_name", "?")
        uname = info.get("username", "")
        tag = f" @{uname}" if uname else ""
        lines.append(f"• {name}{tag} <code>{uid}</code>")
    await update.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)

async def cmd_reply(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    if not is_admin(update):
        await update.message.reply_text("⚠️ 此命令仅限管理员使用。")
        return
    if len(context.args) < 2:
        await update.message.reply_text(
            "💬 <b>回复用户</b>\n\n用法：<code>/reply 用户ID 消息内容</code>",
            parse_mode=ParseMode.HTML,
        )
        return
    uid = context.args[0]
    msg = " ".join(context.args[1:])
    try:
        await context.bot.send_message(
            chat_id=int(uid), text=f"💬 <b>管理员回复</b>\n\n{msg}", parse_mode=ParseMode.HTML
        )
        await update.message.reply_text("✅ 消息已发送。")
    except Exception as e:
        await update.message.reply_text(f"❌ 发送失败：{e}")

async def cmd_id(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    user = update.effective_user
    await update.message.reply_text(
        f"🆔 你的 Chat ID: <code>{update.effective_chat.id}</code>\n"
        f"👤 用户 ID: <code>{user.id}</code>",
        parse_mode=ParseMode.HTML,
    )

async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    context.user_data.pop("awaiting", None)
    context.user_data.pop("temp", None)
    await update.message.reply_text(
        "已取消当前操作并移除底部键盘。发送 /menu 可恢复菜单。",
        reply_markup=ReplyKeyboardRemove(),
    )

# ==================== 回调处理 ====================

async def on_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data

    # 非管理员拦截设置类操作
    admin_prefixes = ("set_", "kw_", "btn_", "kb_")
    if data.startswith(admin_prefixes) and not is_admin(update):
        await query.message.reply_text("⚠️ 此功能仅限管理员使用。")
        return

    # === 用户功能按钮 ===
    if data == "contact_support":
        await query.message.reply_text(
            "📞 <b>联系客服</b>\n\n您可以直接发送消息，我们会收到并回复您。",
            parse_mode=ParseMode.HTML,
        )
        return
    if data == "show_help":
        await query.message.reply_text(
            "❓ <b>帮助</b>\n\n您可以发送任何消息，我们会收到并回复。",
            parse_mode=ParseMode.HTML,
        )
        return
    if data == "show_menu":
        await query.message.reply_text(
            "📋 <b>功能菜单</b>\n\n请点击下方按钮：",
            reply_markup=build_inline_keyboard(), parse_mode=ParseMode.HTML,
        )
        return
    if data == "about":
        await query.message.reply_text(
            "ℹ️ <b>关于</b>\n\n这是一个 Telegram 双向通信机器人。\n支持双向消息、关键词回复、广播通知等功能。",
            parse_mode=ParseMode.HTML,
        )
        return

    # === 设置主菜单导航 ===
    if data == "set_close":
        context.user_data.pop("awaiting", None)
        context.user_data.pop("temp", None)
        await query.message.edit_text("✅ 设置面板已关闭。")
        return
    if data == "set_back":
        context.user_data.pop("awaiting", None)
        context.user_data.pop("temp", None)
        await query.message.edit_text(
            "⚙️ <b>设置面板</b>\n\n请选择要设置的项：",
            reply_markup=settings_main_kb(), parse_mode=ParseMode.HTML,
        )
        return
    if data == "set_reload":
        context.user_data.pop("awaiting", None)
        context.user_data.pop("temp", None)
        await query.message.reply_text("✅ 配置已从文件重新加载。所有设置即时生效。")
        return

    if data == "set_view":
        cfg = get_config()
        text = (
            "📋 <b>当前配置</b>\n\n"
            f"<b>✏️ 自动回复：</b>\n<code>{cfg.get('auto_reply', '(空)')}</code>\n"
            f"  🔘 按钮：{len(get_buttons('auto_reply'))} 个\n\n"
            f"<b>👋 欢迎消息：</b>\n<code>{cfg.get('welcome_message', '(空)')}</code>\n"
            f"  🔘 按钮：{len(get_buttons('welcome'))} 个\n\n"
            f"<b>🔑 关键词数量：</b>{len(cfg.get('keywords', {}))} 个\n"
            f"<b>📢 广播按钮：</b>{len(get_buttons('broadcast'))} 个\n"
            f"<b>⌨️ 底部键盘行数：</b>{len(cfg.get('reply_keyboard', []))} 行\n\n"
            f"<b>🌐 代理：</b>{cfg.get('proxy', '无')}\n"
            f"<b>📋 管理员：</b>@{ADMIN_USERNAME}"
        )
        await query.message.reply_text(text, parse_mode=ParseMode.HTML)
        return

    # === 自动回复设置 ===
    if data == "set_auto_reply":
        ar = get_auto_reply()
        context.user_data.pop("awaiting", None)
        await query.message.edit_text(
            f"✏️ <b>自动回复设置</b>\n\n"
            f"<b>当前文字：</b>\n<code>{ar or '(空)'}</code>\n\n"
            f"🔘 当前附带 {len(get_buttons('auto_reply'))} 个内联按钮\n\n"
            "可以编辑文字内容，也可以管理内联按钮。",
            reply_markup=message_settings_kb("auto_reply"), parse_mode=ParseMode.HTML,
        )
        return

    # === 欢迎消息设置 ===
    if data == "set_welcome":
        wm = get_welcome_message()
        context.user_data.pop("awaiting", None)
        await query.message.edit_text(
            f"👋 <b>欢迎消息设置</b>\n\n"
            f"<b>当前文字：</b>\n<code>{wm or '(空)'}</code>\n\n"
            f"🔘 当前附带 {len(get_buttons('welcome'))} 个内联按钮\n\n"
            "可以编辑文字内容，也可以管理内联按钮。",
            reply_markup=message_settings_kb("welcome"), parse_mode=ParseMode.HTML,
        )
        return

    # === 广播通知 ===
    if data == "set_broadcast":
        context.user_data.pop("awaiting", None)
        await query.message.edit_text(
            f"📢 <b>广播通知设置</b>\n\n"
            f"🔘 当前附带 {len(get_buttons('broadcast'))} 个内联按钮\n\n"
            "可以发送广播消息，也可以管理内联按钮。",
            reply_markup=message_settings_kb("broadcast"), parse_mode=ParseMode.HTML,
        )
        return

    # === 关键词管理 ===
    if data == "set_keywords":
        context.user_data.pop("awaiting", None)
        await query.message.edit_text(
            "🔑 <b>关键词管理</b>\n\n请选择操作：",
            reply_markup=keywords_kb(), parse_mode=ParseMode.HTML,
        )
        return
    if data == "kw_view":
        kw = get_keywords()
        if not kw:
            text = "🔑 <b>关键词列表</b>\n\n暂无关键词。"
        else:
            lines = ["🔑 <b>关键词列表</b>\n"]
            for i, k in enumerate(kw.keys(), 1):
                reply = get_kw_reply(kw, k)
                btn_count = len(get_kw_buttons(kw, k))
                v_short = reply[:40] + "..." if len(reply) > 40 else reply
                lines.append(f"{i}. <code>{k}</code> → {v_short}（按钮{btn_count}个）")
            text = "\n".join(lines)
        await query.message.reply_text(text, parse_mode=ParseMode.HTML)
        return

    # 管理关键词（选择要管理的关键词）
    if data == "kw_manage":
        kw = get_keywords()
        if not kw:
            await query.message.reply_text("🔑 暂无关键词，请先添加。")
            return
        lines = ["🔧 <b>管理关键词</b>\n\n请发送要管理的关键词序号：\n"]
        for i, k in enumerate(kw.keys(), 1):
            reply = get_kw_reply(kw, k)
            v_short = reply[:30] + "..." if len(reply) > 30 else reply
            lines.append(f"{i}. <code>{k}</code> → {v_short}")
        context.user_data["awaiting"] = "kw_manage_select"
        await query.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)
        return

    # 关键词管理页（编辑回复 + 按钮管理）
    if data.startswith("kw_edit_reply_"):
        index = int(data[len("kw_edit_reply_"):])
        kw = get_keywords()
        keys = list(kw.keys())
        if 0 <= index < len(keys):
            key = keys[index]
            reply = get_kw_reply(kw, key)
            context.user_data["kw_index"] = index
            context.user_data["awaiting"] = "kw_edit_reply"
            await query.message.reply_text(
                f"✏️ <b>编辑关键词回复</b>\n\n关键词：<code>{key}</code>\n"
                f"当前回复：\n<code>{reply or '(空)'}</code>\n\n请发送新的回复内容：",
                parse_mode=ParseMode.HTML,
            )
        return

    if data.startswith("kw_view_btn_"):
        index = int(data[len("kw_view_btn_"):])
        kw = get_keywords()
        keys = list(kw.keys())
        if 0 <= index < len(keys):
            key = keys[index]
            btns = get_kw_buttons(kw, key)
            if not btns:
                text = f"🔘 <b>关键词「{key}」的按钮</b>\n\n暂无按钮。"
            else:
                lines = [f"🔘 <b>关键词「{key}」的按钮</b>\n"]
                for i, b in enumerate(btns, 1):
                    lines.append(f"{i}. {b['text']} → 🔗 {b.get('url', '')}")
                text = "\n".join(lines)
            await query.message.reply_text(text, parse_mode=ParseMode.HTML)
        return

    if data.startswith("kw_add_url_"):
        index = int(data[len("kw_add_url_"):])
        context.user_data["kw_index"] = index
        context.user_data["awaiting"] = "kw_add_url_text"
        context.user_data.pop("temp", None)
        kw = get_keywords()
        keys = list(kw.keys())
        key = keys[index] if 0 <= index < len(keys) else ""
        await query.message.reply_text(
            f"➕ <b>添加URL按钮</b> (关键词「{key}」)\n\n"
            "请发送按钮显示文字（用户看到的按钮名称）：",
            parse_mode=ParseMode.HTML,
        )
        return

    if data.startswith("kw_del_btn_"):
        index = int(data[len("kw_del_btn_"):])
        kw = get_keywords()
        keys = list(kw.keys())
        if 0 <= index < len(keys):
            key = keys[index]
            btns = get_kw_buttons(kw, key)
            if not btns:
                await query.message.reply_text("🔘 暂无按钮可删除。")
                return
            lines = [f"➖ <b>删除按钮</b> (关键词「{key}」)\n\n请发送要删除的按钮序号：\n"]
            for i, b in enumerate(btns, 1):
                lines.append(f"{i}. {b['text']}")
            context.user_data["kw_index"] = index
            context.user_data["awaiting"] = "kw_del_btn"
            await query.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)
        return

    if data.startswith("kw_clear_btn_"):
        index = int(data[len("kw_clear_btn_"):])
        kw = get_keywords()
        keys = list(kw.keys())
        if 0 <= index < len(keys):
            key = keys[index]
            cfg = get_config()
            set_kw_data(cfg["keywords"], key, buttons=[])
            save_config(cfg)
            await query.message.reply_text(f"🗑️ 已清空关键词「{key}」的按钮。")
        return
    if data == "kw_add":
        context.user_data["awaiting"] = "kw_add_key"
        context.user_data.pop("temp", None)
        await query.message.reply_text("➕ <b>添加关键词</b>\n\n请发送关键词（触发词）：", parse_mode=ParseMode.HTML)
        return
    if data == "kw_del":
        kw = get_keywords()
        if not kw:
            await query.message.reply_text("🔑 暂无关键词可删除。")
            return
        lines = ["➖ <b>删除关键词</b>\n\n请发送要删除的关键词序号：\n"]
        for i, k in enumerate(kw.keys(), 1):
            lines.append(f"{i}. <code>{k}</code>")
        lines.append("\n💡 也可直接发送关键词文字。")
        context.user_data["awaiting"] = "kw_del"
        await query.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)
        return
    if data == "kw_clear":
        cfg = get_config()
        cfg["keywords"] = {}
        save_config(cfg)
        await query.message.reply_text("🗑️ 已清空所有关键词。")
        return

    # === 消息设置：编辑文字 ===
    if data.startswith("msg_edit_"):
        scope = data[len("msg_edit_"):]
        context.user_data["btn_scope"] = scope
        if scope == "auto_reply":
            ar = get_auto_reply()
            context.user_data["awaiting"] = "auto_reply"
            await query.message.reply_text(
                f"✏️ <b>编辑自动回复文字</b>\n\n当前值：\n<code>{ar or '(空)'}</code>\n\n"
                "请发送新的自动回复内容：\n💡 发送 <code>清除</code> 可关闭自动回复",
                parse_mode=ParseMode.HTML,
            )
        elif scope == "welcome":
            wm = get_welcome_message()
            context.user_data["awaiting"] = "welcome"
            await query.message.reply_text(
                f"👋 <b>编辑欢迎消息</b>\n\n当前值：\n<code>{wm or '(空)'}</code>\n\n请发送新的欢迎消息：",
                parse_mode=ParseMode.HTML,
            )
        elif scope == "broadcast":
            context.user_data["awaiting"] = "broadcast"
            await query.message.reply_text(
                "📢 <b>发送广播</b>\n\n请发送要广播给所有用户的消息内容：",
                parse_mode=ParseMode.HTML,
            )
        return

    # === 消息设置：查看按钮 ===
    if data.startswith("msg_view_btn_"):
        scope = data[len("msg_view_btn_"):]
        btns = get_buttons(scope)
        label = SCOPE_LABELS.get(scope, scope)
        if not btns:
            text = f"🔘 <b>{label}</b>\n\n暂无按钮。"
        else:
            lines = [f"🔘 <b>{label}</b>\n"]
            for i, b in enumerate(btns, 1):
                lines.append(f"{i}. {b['text']} → 🔗 {b.get('url', b.get('callback', ''))}")
            text = "\n".join(lines)
        await query.message.reply_text(text, parse_mode=ParseMode.HTML)
        return

    # === 消息设置：添加URL按钮 ===
    if data.startswith("msg_add_url_"):
        scope = data[len("msg_add_url_"):]
        context.user_data["btn_scope"] = scope
        context.user_data["awaiting"] = "btn_add_url_text"
        context.user_data.pop("temp", None)
        await query.message.reply_text(
            f"➕ <b>添加URL按钮</b> ({SCOPE_LABELS.get(scope, '')})\n\n"
            "请发送按钮显示文字（用户看到的按钮名称）：",
            parse_mode=ParseMode.HTML,
        )
        return

    # === 消息设置：删除按钮 ===
    if data.startswith("msg_del_btn_"):
        scope = data[len("msg_del_btn_"):]
        context.user_data["btn_scope"] = scope
        btns = get_buttons(scope)
        if not btns:
            await query.message.reply_text("🔘 暂无按钮可删除。")
            return
        lines = [f"➖ <b>删除按钮</b> ({SCOPE_LABELS.get(scope, '')})\n\n请发送要删除的按钮序号：\n"]
        for i, b in enumerate(btns, 1):
            lines.append(f"{i}. {b['text']}")
        context.user_data["awaiting"] = "btn_del"
        await query.message.reply_text("\n".join(lines), parse_mode=ParseMode.HTML)
        return

    # === 消息设置：清空按钮 ===
    if data.startswith("msg_clear_btn_"):
        scope = data[len("msg_clear_btn_"):]
        save_buttons(scope, [])
        await query.message.reply_text(f"🗑️ 已清空 {SCOPE_LABELS.get(scope, '')}。")
        return

    # === 底部键盘管理 ===
    if data == "set_keyboard":
        context.user_data.pop("awaiting", None)
        await query.message.edit_text(
            "⌨️ <b>底部键盘管理</b>\n\n请选择操作：",
            reply_markup=keyboard_kb(), parse_mode=ParseMode.HTML,
        )
        return
    if data == "kb_view":
        rkb = get_reply_keyboard_config()
        if not rkb:
            text = "⌨️ <b>底部键盘</b>\n\n当前无底部键盘。"
        else:
            lines = ["⌨️ <b>底部键盘</b>\n"]
            for i, row in enumerate(rkb, 1):
                lines.append(f"第{i}行: {' | '.join(row)}")
            text = "\n".join(lines)
        await query.message.reply_text(text, parse_mode=ParseMode.HTML)
        return
    if data == "kb_add":
        context.user_data["awaiting"] = "kb_add"
        await query.message.reply_text(
            "➕ <b>添加底部键盘行</b>\n\n请发送一行按钮文字，多个按钮用 <code>|</code> 分隔。\n\n"
            "示例：<code>📋 菜单 | ❓ 帮助</code>",
            parse_mode=ParseMode.HTML,
        )
        return
    if data == "kb_clear":
        cfg = get_config()
        cfg["reply_keyboard"] = []
        save_config(cfg)
        await query.message.reply_text("🗑️ 已清空底部键盘。")
        return
    if data == "kb_default":
        cfg = get_config()
        cfg["reply_keyboard"] = [["📋 菜单", "❓ 帮助"], ["🌐 官网", "📞 联系客服"]]
        save_config(cfg)
        await query.message.reply_text("🔄 已恢复默认底部键盘。")

# ==================== 设置输入处理 ====================

async def handle_setting_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text.strip()
    awaiting = context.user_data.get("awaiting")
    temp = context.user_data.get("temp", {})
    cfg = get_config()

    # --- 自动回复 ---
    if awaiting == "auto_reply":
        if text == "清除":
            cfg["auto_reply"] = ""
            await update.message.reply_text("✅ 自动回复已清除（关闭）。")
        else:
            cfg["auto_reply"] = text
            await update.message.reply_text("✅ 自动回复已更新。")
        save_config(cfg)
        context.user_data.pop("awaiting", None)
        return True

    # --- 欢迎消息 ---
    if awaiting == "welcome":
        cfg["welcome_message"] = text
        save_config(cfg)
        await update.message.reply_text("✅ 欢迎消息已更新。")
        context.user_data.pop("awaiting", None)
        return True

    # --- 广播 ---
    if awaiting == "broadcast":
        context.user_data.pop("awaiting", None)
        await do_broadcast(update, context, text)
        return True

    # --- 关键词添加 ---
    if awaiting == "kw_add_key":
        temp["kw_key"] = text
        context.user_data["temp"] = temp
        context.user_data["awaiting"] = "kw_add_val"
        await update.message.reply_text(
            f"✅ 关键词：<code>{text}</code>\n\n请发送该关键词的回复内容：",
            parse_mode=ParseMode.HTML,
        )
        return True
    if awaiting == "kw_add_val":
        key = temp.get("kw_key", "")
        if key:
            set_kw_data(cfg["keywords"], key, reply=text, buttons=[])
            save_config(cfg)
            await update.message.reply_text(
                f"✅ 关键词已添加！\n\n<code>{key}</code> → {text}\n\n"
                "💡 可在「🔧 管理关键词」中为该关键词添加按钮。",
                parse_mode=ParseMode.HTML,
            )
        context.user_data.pop("awaiting", None)
        context.user_data.pop("temp", None)
        return True

    # --- 关键词管理：选择关键词 ---
    if awaiting == "kw_manage_select":
        kw = cfg.get("keywords", {})
        keys = list(kw.keys())
        try:
            idx = int(text) - 1
            if 0 <= idx < len(keys):
                key = keys[idx]
                reply = get_kw_reply(kw, key)
                btn_count = len(get_kw_buttons(kw, key))
                context.user_data["kw_index"] = idx
                context.user_data.pop("awaiting", None)
                await update.message.reply_text(
                    f"🔧 <b>管理关键词</b>\n\n"
                    f"关键词：<code>{key}</code>\n"
                    f"回复：{reply[:50] + '...' if len(reply) > 50 else reply}\n"
                    f"按钮：{btn_count} 个\n\n请选择操作：",
                    reply_markup=keyword_manage_kb(idx),
                    parse_mode=ParseMode.HTML,
                )
            else:
                await update.message.reply_text("❌ 序号超出范围。")
        except ValueError:
            await update.message.reply_text("❌ 请发送数字序号。")
        context.user_data.pop("awaiting", None)
        return True

    # --- 关键词：编辑回复 ---
    if awaiting == "kw_edit_reply":
        index = context.user_data.get("kw_index", 0)
        kw = cfg.get("keywords", {})
        keys = list(kw.keys())
        if 0 <= index < len(keys):
            key = keys[index]
            set_kw_data(kw, key, reply=text)
            cfg["keywords"] = kw
            save_config(cfg)
            await update.message.reply_text(f"✅ 关键词「{key}」的回复已更新。")
        context.user_data.pop("awaiting", None)
        return True

    # --- 关键词：添加URL按钮 ---
    if awaiting == "kw_add_url_text":
        temp["btn_text"] = text
        context.user_data["temp"] = temp
        context.user_data["awaiting"] = "kw_add_url_val"
        await update.message.reply_text(
            f"✅ 按钮文字：<code>{text}</code>\n\n请发送按钮链接（URL）：\n"
            "💡 需以 http:// 或 https:// 开头",
            parse_mode=ParseMode.HTML,
        )
        return True

    if awaiting == "kw_add_url_val":
        index = context.user_data.get("kw_index", 0)
        kw = cfg.get("keywords", {})
        keys = list(kw.keys())
        btn_text = temp.get("btn_text", "")
        url = text.strip()
        if not (url.startswith("http://") or url.startswith("https://")):
            await update.message.reply_text("❌ URL 需以 http:// 或 https:// 开头，请重新发送。")
            return True
        if 0 <= index < len(keys):
            key = keys[index]
            btns = get_kw_buttons(kw, key)
            btns.append({"text": btn_text, "url": url})
            set_kw_data(kw, key, buttons=btns)
            cfg["keywords"] = kw
            save_config(cfg)
            await update.message.reply_text(f"✅ URL按钮已添加到关键词「{key}」！\n{btn_text} → {url}")
        context.user_data.pop("awaiting", None)
        context.user_data.pop("temp", None)
        return True

    # --- 关键词：删除按钮 ---
    if awaiting == "kw_del_btn":
        index = context.user_data.get("kw_index", 0)
        kw = cfg.get("keywords", {})
        keys = list(kw.keys())
        if 0 <= index < len(keys):
            key = keys[index]
            btns = get_kw_buttons(kw, key)
            try:
                btn_idx = int(text) - 1
                if 0 <= btn_idx < len(btns):
                    removed = btns.pop(btn_idx)
                    set_kw_data(kw, key, buttons=btns)
                    cfg["keywords"] = kw
                    save_config(cfg)
                    await update.message.reply_text(f"✅ 已从关键词「{key}」删除按钮：{removed['text']}")
                else:
                    await update.message.reply_text("❌ 序号超出范围。")
            except ValueError:
                await update.message.reply_text("❌ 请发送数字序号。")
        context.user_data.pop("awaiting", None)
        return True

    # --- 关键词删除 ---
    if awaiting == "kw_del":
        kw = cfg.get("keywords", {})
        keys = list(kw.keys())
        deleted = False
        try:
            idx = int(text) - 1
            if 0 <= idx < len(keys):
                del kw[keys[idx]]
                cfg["keywords"] = kw
                save_config(cfg)
                deleted = True
                await update.message.reply_text(f"✅ 已删除关键词：<code>{keys[idx]}</code>")
        except ValueError:
            pass
        if not deleted and text in kw:
            del kw[text]
            cfg["keywords"] = kw
            save_config(cfg)
            deleted = True
            await update.message.reply_text(f"✅ 已删除关键词：<code>{text}</code>")
        if not deleted:
            await update.message.reply_text("❌ 未找到对应关键词。")
        context.user_data.pop("awaiting", None)
        return True

    # --- 按钮添加（通用，按 scope）---
    scope = context.user_data.get("btn_scope", "menu")
    btns = get_buttons(scope)
    label = SCOPE_LABELS.get(scope, "")

    if awaiting == "btn_add_url_text":
        temp["btn_text"] = text
        context.user_data["temp"] = temp
        context.user_data["awaiting"] = "btn_add_url_val"
        await update.message.reply_text(
            f"✅ 按钮文字：<code>{text}</code>\n\n请发送按钮链接（URL）：\n"
            "💡 需以 http:// 或 https:// 开头",
            parse_mode=ParseMode.HTML,
        )
        return True

    if awaiting == "btn_add_url_val":
        btn_text = temp.get("btn_text", "")
        url = text.strip()
        if not (url.startswith("http://") or url.startswith("https://")):
            await update.message.reply_text("❌ URL 需以 http:// 或 https:// 开头，请重新发送。")
            return True
        btns.append({"text": btn_text, "url": url})
        save_buttons(scope, btns)
        await update.message.reply_text(f"✅ URL按钮已添加到{label}！\n{btn_text} → {url}")
        context.user_data.pop("awaiting", None)
        context.user_data.pop("temp", None)
        return True

    if awaiting == "btn_del":
        try:
            idx = int(text) - 1
            if 0 <= idx < len(btns):
                removed = btns.pop(idx)
                save_buttons(scope, btns)
                await update.message.reply_text(f"✅ 已从{label}删除按钮：{removed['text']}")
            else:
                await update.message.reply_text("❌ 序号超出范围。")
        except ValueError:
            await update.message.reply_text("❌ 请发送数字序号。")
        context.user_data.pop("awaiting", None)
        return True

    # --- 底部键盘添加 ---
    if awaiting == "kb_add":
        items = [x.strip() for x in text.split("|") if x.strip()]
        if not items:
            await update.message.reply_text("❌ 格式错误。请用 | 分隔按钮文字。")
            return True
        cfg["reply_keyboard"].append(items)
        save_config(cfg)
        await update.message.reply_text(
            f"✅ 底部键盘已添加一行：{' | '.join(items)}\n\n💡 发送 /start 可刷新底部键盘显示。"
        )
        context.user_data.pop("awaiting", None)
        return True

    return False

# ==================== 消息处理 ====================

async def on_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    register_user(update)
    user = update.effective_user
    chat = update.effective_chat
    msg = update.message
    text = (msg.text or "").strip()

    # --- 管理员设置模式 ---
    if is_admin(update) and context.user_data.get("awaiting"):
        handled = await handle_setting_input(update, context)
        if handled:
            return

    # --- 底部键盘按钮（仅管理员）---
    if is_admin(update):
        if text in ("📋 菜单", "菜单"):
            await cmd_menu(update, context)
            return
        if text in ("❓ 帮助", "帮助"):
            await cmd_help(update, context)
            return
        if text in ("🌐 官网", "官网"):
            await msg.reply_text("🌐 官网地址：https://t.me/MTBTQ")
            return
        if text in ("📞 联系客服", "联系客服"):
            await msg.reply_text("📞 您可以直接发送消息，我们会收到并回复。")
            return

    # --- 管理员消息处理 ---
    if is_admin(update):
        if msg.reply_to_message:
            replied_id = msg.reply_to_message.message_id
            if replied_id in forward_tracker:
                target_uid = forward_tracker[replied_id]
                try:
                    await context.bot.send_message(
                        chat_id=target_uid,
                        text=f"💬 <b>管理员回复</b>\n\n{text}",
                        parse_mode=ParseMode.HTML,
                    )
                    await msg.reply_text("✅ 已回复用户。")
                except Exception as e:
                    await msg.reply_text(f"❌ 回复失败：{e}")
                return
        await msg.reply_text(
            "💡 <b>管理员提示</b>\n\n"
            "• 回复转发消息 → 回复对应用户\n"
            "• /settings → ⚙️ 交互式设置\n"
            "• /broadcast &lt;消息&gt; → 广播所有用户\n"
            "• /reply &lt;ID&gt; &lt;消息&gt; → 回复指定用户\n"
            "• /stats → 查看统计\n"
            "• /users → 查看用户列表",
            parse_mode=ParseMode.HTML,
        )
        return

    # --- 普通用户消息处理 ---

    # 1. 关键词匹配（优先）
    matched = False
    keywords = get_keywords()
    for keyword in keywords:
        if keyword.lower() in text.lower():
            reply = get_kw_reply(keywords, keyword)
            kw_btns = get_kw_buttons(keywords, keyword)
            kb = build_kb_from_buttons(kw_btns)
            if reply:
                await msg.reply_text(reply, reply_markup=kb)
            matched = True
            break

    # 2. 自动回复（附带按钮）
    auto_reply = get_auto_reply()
    if not matched and auto_reply:
        await msg.reply_text(auto_reply, reply_markup=build_auto_reply_kb())

    # 3. 转发给管理员
    users_data = load_users()
    admin_id = users_data.get("admin_chat_id")
    if admin_id:
        try:
            info_parts = [f"👤 <b>{user.first_name or '未知'}</b>"]
            if user.username:
                info_parts.append(f"@{user.username}")
            info_parts.append(f"ID: <code>{user.id}</code>")
            info_parts.append(f"🕐 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            info_text = " | ".join(info_parts)
            sent = await context.bot.send_message(
                chat_id=admin_id,
                text=f"{info_text}\n\n💬 <b>消息：</b>\n{text}",
                parse_mode=ParseMode.HTML,
            )
            track_forward(sent.message_id, chat.id)
        except Exception as e:
            logger.error(f"转发消息给管理员失败: {e}")
    else:
        logger.warning("管理员尚未与机器人互动，无法转发消息。")

# ==================== 错误处理 ====================

async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"异常: {context.error}", exc_info=context.error)
    if update and isinstance(update, Update) and update.effective_chat:
        try:
            await context.bot.send_message(
                chat_id=update.effective_chat.id, text="⚠️ 发生错误，请稍后重试。"
            )
        except Exception:
            pass

# ==================== 主函数 ====================

def main():
    if not BOT_TOKEN:
        print("❌ 错误：config.json 中未设置 bot_token")
        return

    builder = Application.builder().token(BOT_TOKEN)
    if PROXY_URL:
        timeout_kwargs = {
            "read_timeout": 30, "write_timeout": 30,
            "connect_timeout": 30, "pool_timeout": 30,
        }
        req = HTTPXRequest(proxy=PROXY_URL, **timeout_kwargs)
        get_updates_req = HTTPXRequest(proxy=PROXY_URL, **timeout_kwargs)
        builder = builder.request(req).get_updates_request(get_updates_req)
        logger.info(f"代理已设置: {PROXY_URL} (超时: 30s)")

    application = builder.build()

    application.add_handler(CommandHandler("start", cmd_start))
    application.add_handler(CommandHandler("help", cmd_help))
    application.add_handler(CommandHandler("menu", cmd_menu))
    application.add_handler(CommandHandler("settings", cmd_settings))
    application.add_handler(CommandHandler("broadcast", cmd_broadcast))
    application.add_handler(CommandHandler("stats", cmd_stats))
    application.add_handler(CommandHandler("users", cmd_users))
    application.add_handler(CommandHandler("reply", cmd_reply))
    application.add_handler(CommandHandler("id", cmd_id))
    application.add_handler(CommandHandler("cancel", cmd_cancel))

    application.add_handler(CallbackQueryHandler(on_callback))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_message))
    application.add_error_handler(on_error)

    logger.info("=" * 50)
    logger.info("🤖 Telegram 双向机器人启动中...")
    logger.info(f"📋 管理员用户名: @{ADMIN_USERNAME}")
    logger.info(f"🌐 代理: {PROXY_URL or '无'}")
    logger.info("⚙️ 交互式设置已启用 - 管理员发送 /settings 打开")
    logger.info("🔘 四种消息按钮独立管理：菜单/自动回复/欢迎/广播")
    logger.info("=" * 50)

    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
