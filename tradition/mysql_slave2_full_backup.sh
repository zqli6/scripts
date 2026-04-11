#!/bin/bash
# *************************************
# * 功能: mysql全量备份(分库分表)
# * 作者: 李芝全
# * 版本: 2025-12-27
# *************************************

# 基础配置
BASE_DIR="/data/backup/mysql_backups"
FULL_DIR="${BASE_DIR}/full"          # 全量备份存储路径
LOG_DIR="${BASE_DIR}/logs"           # 日志路径
MD5_DIR="${BASE_DIR}/md5_checksums"  # 校验值存储路径
DATE=$(date +%Y%m%d)                 # 日期（用于目录命名）
TIMESTAMP=$(date +%Y%m%d%H%M)        # 时间戳（用于文件名）

# 数据库连接配置
MYSQL_USER="backup_user"
MYSQL_HOST="10.0.0.12"               # 改为TCP/IP连接的IP（匹配账号权限）
MYSQL_CNF="/etc/mysql/my.cnf"		 # 指定配置文件路径
# MYSQL_SOCKET="/var/run/mysqld/mysqld.sock" 
EXCLUDE_DBS=("information_schema" "performance_schema" "sys" "mysql")  # 排除系统库

# 创建必要目录
mkdir -p "${FULL_DIR}/${DATE}" "${LOG_DIR}" "${MD5_DIR}"
LOG_FILE="${LOG_DIR}/full_backup_${TIMESTAMP}.log"
echo "===== 全量备份启动 | 时间：$(date '+%Y-%m-%d %H:%M:%S') =====" >> "${LOG_FILE}"

# ==================== 认证异常处理：前置连接测试（适配TCP/IP连接） ====================
echo "正在测试MySQL账号认证连接..." >> "${LOG_FILE}"
mysql -uroot -e "SELECT 1;" >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "错误：MySQL账号认证失败（用户名/密码/IP端口异常），备份终止" >> "${LOG_FILE}"
    echo "===== 全量备份失败 | 时间：$(date '+%Y-%m-%d %H:%M:%S') =====" >> "${LOG_FILE}"
    exit 1
fi
echo "MySQL账号认证连接正常" >> "${LOG_FILE}"

# 获取所有业务数据库列表
ALL_DBS=$(mysql -uroot \
    -N -e "SHOW DATABASES;" 2>> "${LOG_FILE}")

# 过滤掉系统库（原有逻辑不变）
BUSINESS_DBS=()
for DB in ${ALL_DBS}; do
    if ! [[ " ${EXCLUDE_DBS[@]} " =~ " ${DB} " ]]; then
        BUSINESS_DBS+=("${DB}")
    fi
done

# 分库分表备份函数
backup_db_tables() {
    local db=$1
    echo "开始备份数据库: ${db}" >> "${LOG_FILE}"

    # 获取当前数据库的所有表
    TABLES=$(mysql -uroot \
        -D "${db}" -N -e "SHOW TABLES;" 2>> "${LOG_FILE}")

    # 分表备份（原有逻辑不变）
    for table in ${TABLES}; do
        local backup_file="${FULL_DIR}/${DATE}/${db}_${table}_full_${TIMESTAMP}.sql"

        # 执行备份（单表）
        mysqldump --defaults-extra-file="${MYSQL_CNF}"  -u"${MYSQL_USER}" -h"${MYSQL_HOST}" \
            --single-transaction \
            --source-data=2 \
            --lock-tables=false \
            "${db}" "${table}" > "${backup_file}" 2>> "${LOG_FILE}"

        # 检查备份是否成功
        if [ $? -ne 0 ] || [ ! -s "${backup_file}" ]; then
            echo "错误：数据库 ${db} 表 ${table} 备份失败" >> "${LOG_FILE}"
            rm -f "${backup_file}"
            continue
        fi

        # 生成MD5校验值
        md5sum "${backup_file}" > "${MD5_DIR}/$(basename ${backup_file}).md5"
        echo "成功备份：${backup_file}" >> "${LOG_FILE}"
    done
}

# 执行所有业务库备份
for db in "${BUSINESS_DBS[@]}"; do
    backup_db_tables "${db}"
done

# 记录当前binlog位置
BINLOG_POS_FILE="${FULL_DIR}/${DATE}/binlog_pos.txt"
echo "===== 主库同步binlog信息（用于主从同步） =====" > "${BINLOG_POS_FILE}"
mysql -uroot \
    -e "SHOW SLAVE STATUS\G" 2>> "${LOG_FILE}" \
    | grep -E "Relay_Master_Log_File|Exec_Master_Log_Pos" >> "${BINLOG_POS_FILE}" || echo "警告：获取主库binlog信息失败（不影响备份文件）" >> "${LOG_FILE}"
echo "===== 从库自身binlog信息（用于增量备份） =====" >> "${BINLOG_POS_FILE}"

mysql -uroot \
    -N -e "SHOW MASTER STATUS" 2>> "${LOG_FILE}" \
    | awk '{print "Slave_Binlog_File: " $1 "\nSlave_Binlog_Pos: " $2}' >> "${BINLOG_POS_FILE}" || echo "警告：获取从库binlog信息失败（不影响备份文件）" >> "${LOG_FILE}"

# 清理31天前的全量备份
echo "清理31天前的全量备份..." >> "${LOG_FILE}"
find "${FULL_DIR}" -type d -mtime +31 -exec rm -rf {} \; 2>/dev/null
find "${MD5_DIR}" -name "*.md5" -mtime +31 -delete
find "${LOG_DIR}" -name "full_backup_*.log" -mtime +31 -delete
find "${BASE_DIR}" -maxdepth 1 -type f -name "*.sql.gz" -mtime +31 -delete

# ================================== 备份完成日志 ==================================
echo -e "===== 全量备份完成 | 时间：$(date '+%Y-%m-%d %H:%M:%S') =====" >> "${LOG_FILE}"