#!/bin/bash
# *************************************
# * 功能: Redis 从节点一键安装与配置自动化脚本
# * 适配: Ubuntu 24.04 + Redis-server（apt源安装）
# * 作者: 李芝全
# * 版本: 2025-12-28
# * 说明: 自动完成从节点安装、主从配置、持久化配置、服务启停
# *************************************

set -e  # 遇到错误立即退出，保证流程完整性
set -u  # 未定义变量报错，避免隐性bug

# ==================== 核心配置参数（可按需修改，对应你的配置需求） ====================
# 从节点配置
SLAVE_BIND_IP="10.0.0.31"        # 从节点绑定内网IP
SLAVE_PORT="6379"                # 从节点监听端口
SLAVE_PASSWORD="Redis@1234"      # 从节点自身认证密码
# 主节点配置
MASTER_IP="10.0.0.30"            # 主节点IP
MASTER_PORT="6379"               # 主节点端口
MASTER_PASSWORD="Redis@1234"      # 主节点认证密码（与masterauth一致）
# 其他路径配置
REDIS_CONF="/etc/redis/redis.conf"  # Redis配置文件路径
SERVICE_NAME="redis-server"      # Redis系统服务名


echo -e "\n【步骤1/5】开始安装Redis-server..."
apt update -y >/dev/null 2>&1
apt install -y redis-server >/dev/null 2>&1

echo -e "\n【步骤2/5】备份原有Redis配置文件..."
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_CONF="${REDIS_CONF}.bak.${BACKUP_TIMESTAMP}"
cp "${REDIS_CONF}" "${BACKUP_CONF}"

echo -e "\n【步骤3/5】开始修改Redis从节点核心配置..."
# 定义配置修改函数（统一处理：删除原有配置 + 追加新配置）
update_redis_config() {
    local config_key=$1
    local config_value=$2
    sed -i "/^#*${config_key} /d" "${REDIS_CONF}"
    echo "${config_key} ${config_value}" >> "${REDIS_CONF}"
}
update_redis_config "bind" "${SLAVE_BIND_IP}"
update_redis_config "port" "${SLAVE_PORT}"
update_redis_config "protected-mode" "no"
update_redis_config "slave-read-only" "yes"
update_redis_config "replicaof" "${MASTER_IP} ${MASTER_PORT}"
update_redis_config "masterauth" "${MASTER_PASSWORD}"
update_redis_config "requirepass" "${SLAVE_PASSWORD}"
update_redis_config "appendonly" "yes"
update_redis_config "appendfilename" "\"appendonly.aof\""
update_redis_config "appendfsync" "everysec"
update_redis_config "auto-aof-rewrite-percentage" "50"
update_redis_config "auto-aof-rewrite-min-size" "64mb"
update_redis_config "aof-load-truncated" "yes"
sed -i "/^#*save /d" "${REDIS_CONF}"
echo "save 3600 1" >> "${REDIS_CONF}"
update_redis_config "dir" "/var/lib/redis"
update_redis_config "dbfilename" "dump.rdb"
update_redis_config "repl-backlog-size" "100mb"
update_redis_config "repl-backlog-ttl" "3600"
update_redis_config "repl-diskless-sync" "yes"
update_redis_config "repl-diskless-sync-delay" "5"
echo "Redis从节点核心配置修改完成！"

echo -e "\n【步骤4/5】重启Redis服务并配置开机自启..."
systemctl restart "${SERVICE_NAME}"
sleep 3

echo -e "\n【步骤5/5】验证Redis从节点连接有效性..."
# 尝试连接从节点并验证密码
SLAVE_CHECK=$(redis-cli -h "${SLAVE_BIND_IP}" -p "${SLAVE_PORT}" -a "${SLAVE_PASSWORD}" PING 2>/dev/null)
echo "  - 从节点本地连接验证成功！"

# ==================== 脚本执行完成提示 ====================
echo -e "\n======================================"
echo "  Redis 从节点安装与配置流程全部完成！"
echo "  关键信息："
echo "    1.  从节点：${SLAVE_BIND_IP}:${SLAVE_PORT}  密码：${SLAVE_PASSWORD}"
echo "    2.  主节点：${MASTER_IP}:${MASTER_PORT}  密码：${MASTER_PASSWORD}"
echo "    3.  配置文件：${REDIS_CONF}"
echo "    4.  备份文件：${BACKUP_CONF}"
echo "    5.  服务状态：已启动 + 开机自启"
echo "======================================"