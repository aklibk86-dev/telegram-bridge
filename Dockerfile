FROM python:3.11-slim

LABEL maintainer="TeleBridge"
LABEL description="Telegram 双向机器人"

WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY bot.py config.json ./

# 持久化数据卷
VOLUME ["/app/data"]

# 设置环境变量
ENV PYTHONUNBUFFERED=1

# 将日志和用户数据写入 data 目录
ENV DATA_DIR=/app/data

# 健康检查
HEALTHCHECK --interval=60s --timeout=10s --retries=3 \
    CMD python -c "import os; exit(0 if os.path.exists('/app/data') else 1)"

CMD ["python", "bot.py"]
