#!/bin/bash
# *************************************
# * 功能: AOF 增量备份脚本，每6小时执行
# * 适配: Ubuntu 24.04 
# * 作者: 王树森
# * 版本: 2025-12-28
# *************************************

# 配置参数
BACKUP_DIR="/data/redis_backup/aof"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REDIS_CLI="redis-cli -h 10.0.0.31 -a Redis@1234"
AOF_DIR="/var/lib/redis/appendonlydir"  # AOF 分段目录路径
BACKUP_AOF_DIR="${BACKUP_DIR}/redis_aof_${TIMESTAMP}"  # 备份目录（带时间戳）

# 强制切换到备份目录（避免依赖当前工作目录权限）
[ ! -d "${BACKUP_DIR}" ] && mkdir "${BACKUP_DIR}" -p
cd /data/redis_backup/aof || {
  echo "[$(date)] 切换到备份目录失败！" >> /var/log/redis_backup_error.log
  exit 1
}

# 1. 执行 BGREWRITEAOF 重写 AOF
echo "[$(date)] 开始执行 AOF 重写..."
$REDIS_CLI BGREWRITEAOF
if [ $? -ne 0 ]; then
  echo "[$(date)] BGREWRITEAOF 执行失败！" >> /var/log/redis_backup_error.log
  exit 1
fi

# 2. 等待 AOF 重写完成（最多等待 5 分钟，清除回车符）
WAIT_SECONDS=0
MAX_WAIT=300
while true; do
  REWRITE_STATUS=$($REDIS_CLI INFO Persistence \
                   | grep "aof_rewrite_in_progress" \
                   | awk -F: '{print $2}' \
                   | tr -d '\r')
  if [ "$REWRITE_STATUS" -eq 0 ]; then
    echo "[$(date)] AOF 重写完成"
    break
  fi
  if [ $WAIT_SECONDS -ge $MAX_WAIT ]; then
    echo "[$(date)] AOF 重写超时！" >> /var/log/redis_backup_error.log
    exit 1
  fi
  sleep 10
  WAIT_SECONDS=$((WAIT_SECONDS + 10))
done

# 3. 复制整个 AOF 目录到备份目录（保留结构）
mkdir -p "$BACKUP_AOF_DIR"
cp -r $AOF_DIR/* "$BACKUP_AOF_DIR/"  # 复制目录内所有文件
if [ $? -ne 0 ]; then
  echo "[$(date)] AOF 目录复制失败！" >> /var/log/redis_backup_error.log
  exit 1
fi

# 4. 清理 1 天前的 AOF 备份
echo "[$(date)] 清理过期 AOF 备份..."
find $BACKUP_DIR -name "redis_aof_*" -type d -mtime +1 -delete

echo "[$(date)] AOF 增量备份完成！"