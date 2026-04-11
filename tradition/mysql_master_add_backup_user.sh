#!/bin/bash
# *************************************
# * 功能: MySQL Master节点 - 备份账号创建
# * 适配: Ubuntu 24.04 + MySQL 8.0+
# * 作者: 李芝全
# * 版本: 2025-12-27
# *************************************

# 核心配置
BACKUP_USER="backup_user"
BACKUP_HOST="10.0.0.12"
BACKUP_PASS="BackupPass123!"
BACKUP_PRIVILEGES="SELECT, SHOW VIEW, RELOAD, LOCK TABLES, REPLICATION CLIENT, PROCESS"

# 步骤1：检查账号是否存在（和手动执行命令完全一致）
echo -e "\n【步骤1/4】检查账号 ${BACKUP_USER}@${BACKUP_HOST} 是否存在..."
ACCOUNT_EXISTS=$(mysql -u root -e "SELECT 1 FROM mysql.user WHERE user='${BACKUP_USER}' AND host='${BACKUP_HOST}'" | grep -c 1)
# 强制打印变量值，确认判断依据
echo "账号存在性标识（0=不存在，1=存在）：ACCOUNT_EXISTS = ${ACCOUNT_EXISTS}"

# 步骤2：创建账号（逻辑极简，无隐形语法）
if [ ${ACCOUNT_EXISTS} -eq 1 ]; then
    echo -e "\n【步骤2/4】账号已存在，跳过创建！"
else
    echo -e "\n【步骤2/4】账号不存在，开始创建..."
    # 执行创建命令（和手动执行一致，无多余换行/缩进）
    mysql -u root -e "CREATE USER '${BACKUP_USER}'@'${BACKUP_HOST}' IDENTIFIED BY '${BACKUP_PASS}';"
    echo "账号 ${BACKUP_USER}@${BACKUP_HOST} 创建成功！"
fi

# 步骤3：授予权限（无论账号是否存在，重新授权确保权限正确）
echo -e "\n【步骤3/4】授予备份所需核心权限..."
mysql -u root -e "GRANT ${BACKUP_PRIVILEGES} ON *.* TO '${BACKUP_USER}'@'${BACKUP_HOST}'; FLUSH PRIVILEGES;"
echo "权限授予成功，并已刷新权限！"

# 步骤4：验证账号（强制打印结果，直观确认）
echo -e "\n【步骤4/4】验证账号信息和权限..."
echo "---------- 账号存在性验证 ----------"
mysql -u root -e "SELECT user, host FROM mysql.user WHERE user='${BACKUP_USER}';"
echo -e "\n---------- 账号权限验证 ----------"
mysql -u root -e "SHOW GRANTS FOR '${BACKUP_USER}'@'${BACKUP_HOST}'\G"

# 完成提示
echo -e "\n======================================"
echo "  Master节点备份账号配置全部完成！"
echo "======================================"