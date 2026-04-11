#!/bin/bash
# *************************************
# * 功能: 自动化部署mysql-master节点
# * 适配: Ubuntu系统 + MySQL 8.0+
# * 作者: 李芝全
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出，保证部署完整性

# ==================== 核心配置参数（可按需修改） ====================
MYSQL_IP="10.0.0.10"            # MySQL主节点IP
SERVER_ID="10"                  # MySQL server-id（主节点唯一标识）
MYSQL_DATA_DIR="/data/mysql/logbin"  # 二进制日志存放目录
MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"
APPARMOR_CONF="/etc/apparmor.d/usr.sbin.mysqld"
REPL_USER="repl"                # 主从同步账号
REPL_PASS="ReplPass123!"        # 主从同步密码
REPL_ALLOW="10.0.0.%"           # 允许同步的客户端网段

# ==================== 脚本执行提示 ====================
echo "======================================"
echo "  开始部署MySQL主节点环境"
echo "  MySQL IP：${MYSQL_IP}"
echo "  Server-id：${SERVER_ID}"
echo "  同步账号：${REPL_USER}"
echo "======================================"

# ==================== 步骤1：安装mysql-server软件 ====================
echo -e "\n【步骤1/7】安装mysql-server软件..."
apt update && apt install mysql-server -y > /dev/null 2>&1
echo "mysql-server安装完成"

# ==================== 步骤2：创建二进制日志目录并修改属主属组 ====================
echo -e "\n【步骤2/7】创建目录${MYSQL_DATA_DIR}并设置权限..."
# 递归创建目录（-p：不存在则创建，-v：显示创建过程）
mkdir -pv "${MYSQL_DATA_DIR}"
# 递归修改属主属组为mysql:mysql
chown -R mysql:mysql /data/mysql/
echo "目录创建及权限设置完成"

# ==================== 步骤3：定制MySQL配置文件（mysqld.cnf） ====================
echo -e "\n【步骤3/7】修改MySQL配置文件${MYSQL_CONF}..."
# 备份原有配置文件
if [ -f "${MYSQL_CONF}" ]; then
    cp "${MYSQL_CONF}" "${MYSQL_CONF}.bak"
    echo "已备份原有配置至${MYSQL_CONF}.bak"
fi

# 写入纯净配置（过滤注释和空行，与手动配置一致）
cat > "${MYSQL_CONF}" << EOF
[mysqld]
user            = mysql
bind-address            = ${MYSQL_IP}
mysqlx-bind-address     = ${MYSQL_IP}
key_buffer_size         = 16M
myisam-recover-options  = BACKUP
log_error = /var/log/mysql/error.log
server-id               = ${SERVER_ID}
log_bin                 = ${MYSQL_DATA_DIR}/mysql-bin
authentication_policy   = mysql_native_password
max_binlog_size   = 100M
EOF
echo "MySQL配置文件修改完成"

# ==================== 步骤4：开放AppArmor访问权限 ====================
echo -e "\n【步骤4/7】配置AppArmor权限，允许访问${MYSQL_DATA_DIR}..."
# 1. 备份原AppArmor配置（保险）
cp "${APPARMOR_CONF}" "${APPARMOR_CONF}.bak"
# 2. 删除原文件的最后一行（即末尾的}）
sed -i '$d' "${APPARMOR_CONF}"
# 3. 追加权限配置 + 重新加上闭合的}
cat >> "${APPARMOR_CONF}" << EOF
# 允许mysql使用自定义二进制日志目录
  /data/mysql/logbin/ r,
  /data/mysql/logbin/** rw,
}
EOF
# 重启AppArmor服务使配置生效
systemctl restart apparmor
apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
echo "AppArmor权限配置完成并重启服务"

# ==================== 步骤5：重启MySQL服务加载配置 ====================
echo -e "\n【步骤5/7】重启MySQL服务..."
systemctl restart mysql
# 验证MySQL服务状态
if [ "$(systemctl is-active mysql)" = "active" ]; then
    echo "MySQL服务重启成功，状态：active"
else
    echo "警告：MySQL服务重启后状态异常，请手动排查！"
fi

# ==================== 步骤6：创建主从同步账号并授权 ====================
echo -e "\n【步骤6/7】创建主从同步账号并授权..."
# 免交互执行MySQL命令（root本地登录无需密码，Ubuntu默认配置）
mysql -e "
CREATE USER '${REPL_USER}'@'${REPL_ALLOW}' IDENTIFIED BY '${REPL_PASS}';
GRANT REPLICATION SLAVE ON *.* TO '${REPL_USER}'@'${REPL_ALLOW}';
FLUSH PRIVILEGES;
"
echo "同步账号${REPL_USER}创建及授权完成"

# ==================== 步骤7：查看主节点状态（SHOW MASTER STATUS） ====================
echo -e "\n【步骤7/7】查看MySQL主节点状态..."
echo "======================================"
echo "          MASTER STATUS INFO          "
echo "======================================"
# 执行SHOW MASTER STATUS并以垂直格式输出
mysql -e "SHOW MASTER STATUS\G"
echo "======================================"

# ==================== 部署完成提示 ====================
echo -e "\n======================================"
echo "  MySQL主节点环境部署完成！"
echo "  核心信息："
echo "    MySQL IP：${MYSQL_IP}"
echo "    二进制日志目录：${MYSQL_DATA_DIR}"
echo "    同步账号：${REPL_USER}@${REPL_ALLOW}"
echo "    服务状态：$(systemctl is-active mysql)"
echo "  验证提示：可通过 mysql -u root 登录数据库进一步检查"
echo "======================================"