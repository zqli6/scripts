#!/bin/bash
# *************************************
# * 功能: 自动化部署msyql-slave节点
# * 适配: Ubuntu系统 + MySQL 8.0+
# * 作者: 李芝全
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出，保证部署完整性

# ==================== 核心配置参数（可按需修改，对应你的环境） ====================
SLAVE_IP="10.0.0.12"            # 从节点IP地址
SERVER_ID="12"                  # 从节点唯一标识（不可与主节点重复）
MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"  # MySQL配置文件路径
# 认证策略配置（MySQL 8.0+ 推荐使用，替代废弃的default_authentication_plugin）
AUTH_POLICY="mysql_native_password"

# ==================== 脚本执行提示 ====================
echo "======================================"
echo "  MySQL从节点（slave1）基础环境部署"
echo "  从节点IP：${SLAVE_IP}"
echo "  Server-id：${SERVER_ID}"
echo "======================================"

# ==================== 步骤1：安装mysql-server软件 ====================
echo -e "\n【步骤1/3】安装mysql-server软件..."
# 更新软件源并静默安装mysql-server
apt update && apt install mysql-server -y > /dev/null 2>&1

# 验证MySQL是否安装成功
if command -v mysqld > /dev/null 2>&1; then
    echo "mysql-server安装成功！"
else
    echo "错误：mysql-server安装失败，请手动排查！"
    exit 1
fi

# ==================== 步骤2：定制MySQL从节点配置文件 ====================
echo -e "\n【步骤2/3】修改MySQL配置文件 ${MYSQL_CONF}..."

# 备份原有配置文件（防止覆盖丢失）
if [ -f "${MYSQL_CONF}" ]; then
    cp "${MYSQL_CONF}" "${MYSQL_CONF}.bak"
    echo "已备份原有配置至 ${MYSQL_CONF}.bak"
fi

# 写入纯净的从节点配置
cat > "${MYSQL_CONF}" << EOF
[mysqld]
user            = mysql
bind-address            = ${SLAVE_IP}
mysqlx-bind-address     = ${SLAVE_IP}
key_buffer_size         = 16M
myisam-recover-options  = BACKUP
log_error = /var/log/mysql/error.log
server-id               = ${SERVER_ID}
relay-log               = mysql-relay-bin
read-only               = 1
authentication_policy   = ${AUTH_POLICY}
EOF

echo "MySQL从节点配置文件修改完成！"
echo "配置说明："
echo "  1. 绑定从节点IP ${SLAVE_IP}，开放访问入口"
echo "  2. 启用中继日志（mysql-relay-bin），支持主从复制"
echo "  3. 设置read-only=1，禁止从节点主动写操作"
echo "  4. 使用authentication_policy（MySQL 8.0+推荐），避免认证问题"

# ==================== 步骤3：重启MySQL服务使配置生效 ====================
echo -e "\n【步骤3/3】重启MySQL服务..."
# 重启MySQL服务
systemctl restart mysql

# 验证MySQL服务状态
if [ "$(systemctl is-active mysql)" = "active" ]; then
    echo "MySQL服务重启成功，当前状态：active（运行中）"
else
    echo "警告：MySQL服务重启后状态异常，请执行 systemctl status mysql 排查！"
fi

# ==================== 部署完成提示 ====================
echo -e "\n======================================"
echo "  MySQL从节点（slave1）基础环境部署完成！"
echo "  核心信息："
echo "    配置文件：${MYSQL_CONF}"
echo "    服务状态：$(systemctl is-active mysql)"
echo "    下一步：可导入主节点备份数据并配置主从复制"
echo "======================================"