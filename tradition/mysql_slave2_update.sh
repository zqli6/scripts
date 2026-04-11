#!/bin/bash
# *************************************
# * 功能: MySQL slave2节点完整改造脚本（备份角色专属）
# * 适配: Ubuntu 24.04 + MySQL 8.0+
# * 作者: 王树森
# * 版本: 2025-12-27
# * 说明: 一键完成目录创建、配置修改、权限开放、服务重启
# *************************************

set -e  # 错误立即退出，保证流程完整性

# ==================== 核心配置参数（可按需修改） ====================
SLAVE2_IP="10.0.0.12" 
SERVER_ID="12"
BINLOG_DIR="/data/mysql/logbin"
MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"
APPARMOR_CONF="/etc/apparmor.d/usr.sbin.mysqld"
CLIENT_CONF="/etc/mysql/mysql.cnf"
BACKUP_USER="backup_user"
BACKUP_PASS="BackupPass123!"

# ==================== 脚本执行提示 ====================
echo "======================================"
echo "  MySQL slave2节点改造脚本（备份角色）"
echo "  slave2 IP: ${SLAVE2_IP}"
echo "  Server-id: ${SERVER_ID}"
echo "  二进制日志目录: ${BINLOG_DIR}"
echo "======================================"

# ==================== 步骤1：创建二进制日志目录并修改属主属组 ====================
echo -e "\n【步骤1/5】创建二进制日志目录并配置权限..."
if [ -d "${BINLOG_DIR}" ]; then
    echo "目录 ${BINLOG_DIR} 已存在，跳过创建"
else
    mkdir -pv "${BINLOG_DIR}"
    echo "成功创建目录: ${BINLOG_DIR}"
fi

# 修改属主属组为mysql:mysql
chown -R mysql:mysql /data/mysql/
echo "成功设置 ${BINLOG_DIR} 属主属组为 mysql:mysql"

# ==================== 步骤2：修改MySQL主配置文件（mysqld.cnf） ====================
echo -e "\n【步骤2/5】修改MySQL主配置文件: ${MYSQL_CONF}..."

# 备份原有配置文件
if [ -f "${MYSQL_CONF}.bak" ]; then
    echo "原有配置备份 ${MYSQL_CONF}.bak 已存在，跳过备份"
else
    cp "${MYSQL_CONF}" "${MYSQL_CONF}.bak"
    echo "已备份原有配置至 ${MYSQL_CONF}.bak"
fi

# 写入slave2专属配置,避免全量修改，以增量的方式操作
cat >> "${MYSQL_CONF}" <<-eof
log_bin = /data/mysql/logbin/mysql-bin 		# 指定二进制文件路径
log_bin_index = /data/mysql/logbin/mysql-bin.index 
# log_slave_updates = 1  						# 关键：记录从主节点同步的操作到binlog
expire_logs_days = 7  						# 自动清理7天前的binlog
max_binlog_size = 1G  						# 单个binlog文件最大1G（避免过大）	
eof
echo "成功修改MySQL主配置文件，核心配置已生效"

# ==================== 步骤3：配置AppArmor访问权限 ====================
echo -e "\n【步骤3/5】配置AppArmor访问权限: ${APPARMOR_CONF}..."

# 检查是否已添加权限，避免重复添加
if grep -q "${BINLOG_DIR}/** rw," "${APPARMOR_CONF}"; then
    echo "AppArmor已配置 ${BINLOG_DIR} 权限，跳过添加"
else
    # 在配置文件末尾添加权限（保留原有结尾的}）
    sed -i "/^}/i \  ${BINLOG_DIR}/ r," "${APPARMOR_CONF}"
    sed -i "/^}/i \  ${BINLOG_DIR}/** rw," "${APPARMOR_CONF}"
    echo "成功添加 ${BINLOG_DIR} 访问权限到AppArmor"
fi

# 重启AppArmor使配置生效
systemctl restart apparmor
apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
echo "成功重启AppArmor服务"

# ==================== 步骤4：重启MySQL服务并验证同步状态 ====================
echo -e "\n【步骤4/5】重启MySQL服务并验证主从同步状态..."
# 尝试停止复制线程，忽略未配置复制的错误
mysql -e "STOP SLAVE;" >/dev/null 2>&1 || echo "未配置复制，跳过停止复制线程"
# 重启MySQL服务
systemctl restart mysql
sleep 2
if [ "$(systemctl is-active mysql)" = "active" ]; then
    echo "MySQL服务重启成功，状态：active"
else
    echo "错误：MySQL服务重启失败，请手动排查！"
    exit 1
fi
# 重新配置主从复制并启动（自动修复复制异常）
mysql -e "START SLAVE;" >/dev/null 2>&1
sleep 3

# 验证主从同步核心状态
echo "验证主从同步状态（Slave_IO_Running / Slave_SQL_Running）..."
SLAVE_STATUS=$(mysql -e "show slave status\G")
IO_RUNNING=$(echo "${SLAVE_STATUS}" | grep "Slave_IO_Running:" | awk '{print $2}')
SQL_RUNNING=$(echo "${SLAVE_STATUS}" | grep "Slave_SQL_Running:" | awk '{print $2}')

if [ "${IO_RUNNING}" = "Yes" ] && [ "${SQL_RUNNING}" = "Yes" ]; then
    echo "主从同步状态正常：Slave_IO_Running=Yes，Slave_SQL_Running=Yes"
else
    echo "警告：主从同步状态异常！IO=${IO_RUNNING}，SQL=${SQL_RUNNING}"
fi

# ==================== 步骤5：配置MySQL客户端认证（mysqldump自动登录） ====================
echo -e "\n【步骤5/5】配置MySQL客户端认证: ${CLIENT_CONF}..."

# 在文件末尾添加[mysqldump]配置
if grep -q "\[mysqldump\]" "${CLIENT_CONF}"; then
    sed -i "/\[mysqldump\]/,/^$/d" "${CLIENT_CONF}"
fi
cat >> "${CLIENT_CONF}" << EOF
[mysqldump]
user=${BACKUP_USER}
password=${BACKUP_PASS}
host=${SLAVE2_IP}
EOF

# 限制客户端配置文件权限，防止明文密码泄露
chmod 600 "${CLIENT_CONF}"
echo "成功配置mysqldump自动认证，文件权限已设置为600"

# ==================== 改造完成提示 ====================
echo -e "\n======================================"
echo "  MySQL slave2节点改造流程全部完成！"
echo "  后续操作："
echo "    1. 确认主节点已创建 ${BACKUP_USER}@${SLAVE2_IP} 账号"
echo "    2. 直接执行mysqldump即可进行备份，无需手动传参"
echo "    3. 示例备份命令：mysqldump --databases test_db --single-transaction --source-data=2 --lock-tables=false > backup.sql"
echo "======================================"