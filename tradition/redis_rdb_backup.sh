#!/bin/bash
# *************************************
# * 功能: RDB 全量备份脚本，每日凌晨3点执行
# * 适配: Ubuntu 24.04 
# * 作者: 王树森
# * 版本: 2025-12-28
# ************************************

# 配置参数
BACKUP_DIR="/data/redis_backup/rdb"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REDIS_CLI="redis-cli -h 10.0.0.31 -a Redis@1234"

# 强制切换到备份目录（避免依赖当前工作目录权限）
[ ! -d "${BACKUP_DIR}" ] && mkdir "${BACKUP_DIR}" -p
cd /data/redis_backup/rdb || {
  echo "[$(date)] 切换到备份目录失败！" >> /var/log/redis_backup_error.log
  exit 1
}

# 1. 执行 BGSAVE 生成 RDB
echo "[$(date)] 开始执行 RDB 全量备份..."
$REDIS_CLI BGSAVE
if [ $? -ne 0 ]; then
  echo "[$(date)] BGSAVE 执行失败！" >> /var/log/redis_backup_error.log
  exit 1
fi

# 2. 等待 RDB 生成完成（最多等待 5 分钟，每 10 秒检查一次）
WAIT_SECONDS=0
MAX_WAIT=300  # 300秒=5分钟
while true; do
  # 检查 RDB 是否正在生成
  BGSAVE_STATUS=$($REDIS_CLI INFO Persistence \
                  | grep "rdb_bgsave_in_progress" \
                  | awk -F: '{print $2}' \
                  | tr -d '\r')
  if [ "$BGSAVE_STATUS" -eq 0 ]; then
    echo "[$(date)] RDB 备份完成"
    break
  fi
  if [ $WAIT_SECONDS -ge $MAX_WAIT ]; then
    echo "[$(date)] RDB 备份超时！" >> /var/log/redis_backup_error.log
    exit 1
  fi
  sleep 10
  WAIT_SECONDS=$((WAIT_SECONDS + 10))
done

# 3. 复制 RDB 文件到备份目录（带时间戳）
cp /var/lib/redis/dump.rdb "${BACKUP_DIR}/redis_rdb_${TIMESTAMP}.rdb"
if [ $? -ne 0 ]; then
  echo "[$(date)] RDB 文件复制失败！" >> /var/log/redis_backup_error.log
  exit 1
fi

# 4. 清理 3 天前的 RDB 备份（保留最近3天）
echo "[$(date)] 清理过期 RDB 备份..."
find $BACKUP_DIR -name "redis_rdb_*.rdb" -mtime +3 -delete

echo "[$(date)] RDB 全量备份完成！"