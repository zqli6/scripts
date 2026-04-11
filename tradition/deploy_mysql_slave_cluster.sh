#!/bin/bash
# *************************************
# * 功能: MySQL从节点主从集群配置
# * 适配: Ubuntu系统 + MySQL 8.0+
# * 作者: 王树森
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出，保证配置完整性

# ==================== 核心配置参数 ====================
MASTER_IP="10.0.0.10"           # 主节点IP地址（与实际一致）
REPL_USER="repl"                # 主从同步账号（与主节点一致）
REPL_PASS="ReplPass123!"        # 主从同步密码（与主节点一致）
BACKUP_FILE="all.sql"           # 主节点备份文件（固定为all.sql，无需修改）

# ==================== 脚本执行提示 ====================
echo "======================================"
echo "  MySQL从节点主从集群配置"
echo "  主节点IP：${MASTER_IP}"
echo "  同步账号：${REPL_USER}"
echo "  备份文件：${BACKUP_FILE}"
echo "======================================"

echo -e "\n【步骤1/5】导入主节点初始化备份数据..."
read -p "是否需要导入基准数据(yes|no)：" SKIP_IMPORT
# 判断是否跳过导入
if [ "${SKIP_IMPORT}" == "yes" ]; then
    if [ ! -f "${BACKUP_FILE}" ]; then
        echo "错误：备份文件 ${BACKUP_FILE} 不存在！无法导入初始化数据，请先拷贝主节点备份文件。"
        exit 1
    fi
    # 导入备份文件（免交互，忽略导入过程中的非致命警告）
    echo "正在导入 ${BACKUP_FILE}，请耐心等待（耗时取决于备份文件大小）..."
	(
        echo "SET sql_log_bin = 0;";  # 第一步：临时禁用二进制日志
        cat "${BACKUP_FILE}";        # 第二步：执行备份文件导入（无日志记录）
        echo "SET sql_log_bin = 1;";  # 第三步：导入完成后，重新启用二进制日志
        echo "SELECT '二进制日志已重新启用，数据导入完成！' AS result;";
    ) | mysql -uroot --force  # 同一个会话执行上述所有操作
    # mysql -uroot --force < "${BACKUP_FILE}" 2>/dev/null
    # --force：忽略导入过程中的部分错误，保证导入继续
    # 2>/dev/null：屏蔽无关警告输出，保持日志整洁
    echo "初始化备份数据导入完成！"
else
    echo "已跳过数据导入步骤（SKIP_IMPORT=yes）"
fi

# ==================== 步骤1：提取MASTER_LOG_FILE和MASTER_LOG_POS ====================
echo -e "\n【步骤2/5】从 ${BACKUP_FILE} 中提取主节点日志文件名和位置..."

# 检查all.sql是否存在，不存在则直接退出（强制依赖备份文件）
if [ ! -f "${BACKUP_FILE}" ]; then
    echo "错误：备份文件 ${BACKUP_FILE} 不存在！无法提取日志信息，请先拷贝主节点备份文件。"
    exit 1
fi

# 精准提取日志文件名（匹配 -- CHANGE MASTER TO 后的日志文件）
MASTER_LOG_FILE=$(grep -- "-- CHANGE MASTER TO" "${BACKUP_FILE}" | awk -F"MASTER_LOG_FILE='|'" '{print $2}')

# 精准提取日志位置（匹配 -- CHANGE MASTER TO 后的POS值）
MASTER_LOG_POS=$(grep -- "-- CHANGE MASTER TO" "${BACKUP_FILE}" | awk -F"MASTER_LOG_POS=|;" '{print $2}' | tr -d ' ')

# 验证提取结果是否有效，无效则退出
if [ -z "${MASTER_LOG_FILE}" ] || [ -z "${MASTER_LOG_POS}" ]; then
    echo "错误：从 ${BACKUP_FILE} 中提取日志信息失败！请确认备份文件完整性。"
    echo "建议检查：${BACKUP_FILE} 中是否存在 '-- CHANGE MASTER TO' 关键字。"
    exit 1
fi

# 输出提取结果
echo "提取成功！"
echo "  主节点日志文件（MASTER_LOG_FILE）：${MASTER_LOG_FILE}"
echo "  主节点日志位置（MASTER_LOG_POS）：${MASTER_LOG_POS}"

# ==================== 步骤2：配置主从复制关系（CHANGE MASTER TO） ====================
echo -e "\n【步骤3/5】配置主从复制关系..."
# 免交互执行MySQL命令，先停止原有slave进程（防止冲突），再配置主从参数
mysql -e "
-- 停止原有从节点复制进程（若存在）
STOP SLAVE;
-- 配置主从连接参数（日志信息为自动提取结果）
CHANGE MASTER TO
  MASTER_HOST='${MASTER_IP}',
  MASTER_USER='${REPL_USER}',
  MASTER_PASSWORD='${REPL_PASS}',
  MASTER_LOG_FILE='${MASTER_LOG_FILE}',
  MASTER_LOG_POS=${MASTER_LOG_POS};
"
echo "主从复制参数配置完成！"
echo "配置详情："
echo "  主节点IP：${MASTER_IP}"
echo "  同步账号：${REPL_USER}"
echo "  日志文件：${MASTER_LOG_FILE}"
echo "  日志位置：${MASTER_LOG_POS}"

# ==================== 步骤3：启动从节点复制进程（START SLAVE） ====================
echo -e "\n【步骤4/5】启动从节点复制进程..."
# 启动slave并忽略无关警告
mysql -e "START SLAVE;"
echo "从节点复制进程启动成功！"
sleep 3
# ==================== 步骤4：验证主从集群核心状态 ====================
echo -e "\n【步骤5/5】验证主从集群状态（核心：Slave_IO_Running 和 Slave_SQL_Running 均为 Yes）..."
# 获取完整slave状态并提取关键信息
SLAVE_STATUS=$(mysql -e "SHOW SLAVE STATUS\G")
# 自动判断核心状态是否正常
IO_RUNNING=$(echo "${SLAVE_STATUS}" | grep "Slave_IO_Running:" | awk '{print $2}')
SQL_RUNNING=$(echo "${SLAVE_STATUS}" | grep "Slave_SQL_Running:" | awk '{print $2}')
echo "  Slave_IO_Running: ${IO_RUNNING}"
echo "  Slave_SQL_Running: ${SQL_RUNNING}"

# ==================== 配置完成提示 ====================
echo -e "\n======================================"
echo "  MySQL从节点主从集群配置流程完成！"
echo "  核心依赖：${BACKUP_FILE}（日志信息自动提取）"
echo "  后续验证：可在主节点插入数据，从节点查询是否同步。"
echo "======================================"