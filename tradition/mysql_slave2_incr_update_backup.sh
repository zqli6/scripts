#!/bin/bash
# *************************************
# * 功能: mysql增量备份数据(分库分表)
# * 作者: 李芝全
# * 适配: Ubuntu系统 + MySQL 8.0+
# * 版本: 2025-12-27（增量优化版）
# *************************************

# 基础配置
BASE_DIR="/data/backup/mysql_backups"
INCR_DIR="${BASE_DIR}/incremental"  # 增量备份存储路径
FULL_DIR="${BASE_DIR}/full"         # 全量备份路径（用于获取binlog基线）
LOG_DIR="${BASE_DIR}/logs"          # 日志路径
MD5_DIR="${BASE_DIR}/md5_checksums" # 校验值存储路径
DATE=$(date +%Y%m%d)                # 日期（用于目录命名）
TIMESTAMP=$(date +%Y%m%d%H%M)       # 时间戳（用于文件名）
# 基础配置下方新增
INCR_POS_FILE="${INCR_DIR}/${DATE}/incr_binlog_pos_${TIMESTAMP}.txt"  # 本次增量的位点记录文件
LATEST_INCR_POS_DIR="${INCR_DIR}"  # 增量位点文件的根目录，用于查找最新增量位点

# 数据库连接配置
MYSQL_USER="backup_user"
MYSQL_HOST="10.0.0.12"               # 改为TCP/IP连接（匹配账号权限）
MYSQL_CNF="/etc/mysql/my.cnf"        # 指定配置文件路径（读取预配置的账号密码）
export MYSQL_PWD=$(grep -E "^password=" "${MYSQL_CNF}" | awk -F'=' '{print $2}')
# MYSQL_PASS="BackupPass123!"        # 注释/删除明文密码，消除安全风险
# MYSQL_SOCKET="/var/run/mysqld/mysqld.sock" # 注释Socket，使用TCP/IP连接
MYSQL_BINLOG_DIR="/data/mysql/logbin"   # slave2本地binlog目录（需启用log_bin）
EXCLUDE_DBS=("information_schema" "performance_schema" "sys" "mysql")  # 排除系统库

# 创建必要目录
mkdir -p "${INCR_DIR}/${DATE}"
LOG_FILE="${LOG_DIR}/incr_backup_${TIMESTAMP}.log"
echo "===== 增量备份启动 | 时间：$(date '+%Y-%m-%d %H:%M:%S') =====" >> "${LOG_FILE}"

echo "正在测试MySQL账号认证连接..." >> "${LOG_FILE}"
mysql -uroot -e "SELECT 1;" >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "错误：MySQL账号认证失败（用户名/密码/IP端口异常），增量备份终止" >> "${LOG_FILE}"
    echo "===== 增量备份失败 | 时间：$(date '+%Y-%m-%d %H:%M:%S') =====" >> "${LOG_FILE}"
    exit 1
fi
echo "MySQL账号认证连接正常" >> "${LOG_FILE}"

# 获取最新全量备份的binlog位置
# get_latest_binlog_info() {
#     # 查找最新的全量备份目录
#     LATEST_FULL=$(ls -rt "${FULL_DIR}" | tail -n1)
# 
#     # 读取全量备份记录的“从库自身binlog信息”
#     BINLOG_POS_FILE="${FULL_DIR}/${LATEST_FULL}/binlog_pos.txt"
# 
#     # 解析从库自身的binlog文件名和pos值（关键！）
#     SLAVE_BINLOG_FILE=$(grep "Slave_Binlog_File" "${BINLOG_POS_FILE}" | awk '{print $2}')
#     SLAVE_BINLOG_POS=$(grep "Slave_Binlog_Pos" "${BINLOG_POS_FILE}" | awk '{print $2}')
#     echo "使用全量备份 ${LATEST_FULL} 的binlog基线：${SLAVE_BINLOG_FILE}:${SLAVE_BINLOG_POS}" >> "${LOG_FILE}"
# }

# 替换原有 get_latest_binlog_info 函数，实现“先找最新增量位点，再找全量位点”
get_latest_backup_pos() {
    # 第一步：查找最新的增量位点文件（按时间倒序排序，取第一个）
    # 遍历所有增量目录下的位点文件，按时间戳倒序排列
    LATEST_INCR_POS_FILE=$(find "${LATEST_INCR_POS_DIR}" -name "incr_binlog_pos_*.txt" -type f | sort -r | head -n1)

    # 若存在最新增量位点文件，优先读取该位点作为本次增量的起始基线
    if [ -n "${LATEST_INCR_POS_FILE}" ]; then
        # 解析增量位点文件中的起始文件名和起始位置
        SLAVE_BINLOG_FILE=$(grep "Incr_End_Binlog_File" "${LATEST_INCR_POS_FILE}" | awk '{print $2}')
        SLAVE_BINLOG_POS=$(grep "Incr_End_Binlog_Pos" "${LATEST_INCR_POS_FILE}" | awk '{print $2}')
        echo "找到最新增量备份位点文件：${LATEST_INCR_POS_FILE}，使用基线：${SLAVE_BINLOG_FILE}:${SLAVE_BINLOG_POS}" >> "${LOG_FILE}"
        return 0
    fi

    # 若不存在增量位点文件，再读取全量备份位点（兼容首次增量备份）
    echo "未找到增量备份位点，将使用最新全量备份位点作为基线" >> "${LOG_FILE}"
    LATEST_FULL=$(ls -rt "${FULL_DIR}" | tail -n1)
    BINLOG_POS_FILE="${FULL_DIR}/${LATEST_FULL}/binlog_pos.txt"

    # 解析全量位点
    SLAVE_BINLOG_FILE=$(grep "Slave_Binlog_File" "${BINLOG_POS_FILE}" | awk '{print $2}')
    SLAVE_BINLOG_POS=$(grep "Slave_Binlog_Pos" "${BINLOG_POS_FILE}" | awk '{print $2}')
    echo "使用全量备份 ${LATEST_FULL} 的binlog基线：${SLAVE_BINLOG_FILE}:${SLAVE_BINLOG_POS}" >> "${LOG_FILE}"
}


# 获取所有业务数据库列表（与全量备份保持一致）
get_business_dbs() {
    ALL_DBS=$(mysql -uroot \
        -N -e "SHOW DATABASES;" 2>> "${LOG_FILE}")

    # 过滤系统库
    BUSINESS_DBS=()
    for DB in ${ALL_DBS}; do
        if ! [[ " ${EXCLUDE_DBS[@]} " =~ " ${DB} " ]]; then
            BUSINESS_DBS+=("${DB}")
        fi
    done
}

# 分库增量备份函数（基于binlog）
backup_incr_db() {
    local db=$1
    local backup_file="${INCR_DIR}/${DATE}/${db}_incr_${TIMESTAMP}.sql"

    echo "开始备份数据库 ${db} 的增量数据" >> "${LOG_FILE}"

    # 解析binlog，提取指定库的增量数据
    mysqlbinlog --start-position="${SLAVE_BINLOG_POS}" \
        --database="${db}" \
        -u"${MYSQL_USER}" -h"${MYSQL_HOST}" \
        "${MYSQL_BINLOG_DIR}/${SLAVE_BINLOG_FILE}" > "${backup_file}" 2>> "${LOG_FILE}"
		
    # 新增：兼容无增量数据场景
    local binlog_exit_code=$?
    # 判定条件：1. 命令返回码非严重错误（排除认证/文件不存在等真失败）；2. 备份文件为空
    if [ ${binlog_exit_code} -eq 0 ] || [ ${binlog_exit_code} -eq 7 ]; then
        if [ ! -s "${backup_file}" ]; then
            echo "提示：数据库 ${db} 无新的增量数据，无需备份" >> "${LOG_FILE}"
            rm -f "${backup_file}"
            return 0  # 返回0表示正常，非失败
        fi
    fi
	
    # 检查备份是否成功
    if [ ${binlog_exit_code} -ne 0 ] && [ ${binlog_exit_code} -ne 7 ]; then
        echo "错误：数据库 ${db} 增量备份失败" >> "${LOG_FILE}"
        rm -f "${backup_file}"
        return 1
    fi

    # 生成MD5校验值
    md5sum "${backup_file}" > "${MD5_DIR}/$(basename ${backup_file})-incr.md5"
    echo "成功备份：${backup_file}" >> "${LOG_FILE}"
	
	# 关键改造：获取本次增量备份的binlog结束位点
    # 方式1：直接解析当前binlog文件的末尾位置（推荐，简单高效）
    local INCR_END_BINLOG_POS=$(mysqlbinlog "${MYSQL_BINLOG_DIR}/${SLAVE_BINLOG_FILE}" | grep -E "^# at [0-9]+$" | awk '{print $3}' | sort -n | tail -n1)
    local INCR_END_BINLOG_FILE="${SLAVE_BINLOG_FILE}"
	# 记录本次增量的结束位点到增量位点文件（关键：供下一次增量备份使用）
    echo "Incr_End_Binlog_File: ${INCR_END_BINLOG_FILE}" > "${INCR_POS_FILE}"
    echo "Incr_End_Binlog_Pos: ${INCR_END_BINLOG_POS}" >> "${INCR_POS_FILE}"
    echo "Incr_Backup_Time: $(date '+%Y-%m-%d %H:%M:%S')" >> "${INCR_POS_FILE}"
    echo "本次增量备份结束位点已写入：${INCR_POS_FILE}" >> "${LOG_FILE}"

    return 0
}

# 主执行流程
get_latest_backup_pos  
get_business_dbs

# 对所有业务库执行增量备份
for db in "${BUSINESS_DBS[@]}"; do
    backup_incr_db "${db}"
done

# 清理8天前的增量备份
echo "清理8天前的增量备份..." >> "${LOG_FILE}"
find "${INCR_DIR}" -type d -mtime +8 -exec rm -rf {} \;
find "${MD5_DIR}" -name "*-incr.md5" -mtime +8 -delete
find "${LATEST_INCR_POS_DIR}" -name "incr_binlog_pos_*.txt" -mtime +8 -delete

# ================================== 备份完成日志 ==================================
echo -e "\n===== 增量备份完成 | 时间：$(date '+%Y-%m-%d %H:%M:%S') =====" >> "${LOG_FILE}"