#!/bin/bash
# *************************************
# * 功能: Redis 一键安装与配置自动化脚本
# * 适配: Ubuntu 24.04 + Redis-server（apt源安装）
# * 作者: 李芝全
# * 版本: 2025-12-28
# * 说明: 自动完成安装、配置修改、服务启停，保留原有配置备份
# *************************************

set -e  # 遇到错误立即退出，保证流程完整性
set -u  # 未定义变量报错，避免隐性bug

# ==================== 核心配置参数（可按需修改，对应你的配置需求） ====================
REDIS_BIND_IP="10.0.0.30"        # Redis绑定内网IP
REDIS_PORT="6379"                # Redis监听端口
REDIS_PASSWORD="Redis@1234"      # Redis认证密码
REDIS_CONF="/etc/redis/redis.conf"  # Redis主配置文件路径
SERVICE_NAME="redis-server"      # Redis系统服务名

echo -e "\n【步骤1/5】开始安装Redis-server..."
# 先更新apt源（可选，确保安装最新版本）
apt update -y >/dev/null 2>&1
apt install -y redis-server >/dev/null 2>&1

echo -e "\n【步骤2/5】备份原有Redis配置文件..."
# 添加时间戳，避免重复备份覆盖
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_CONF="${REDIS_CONF}.bak.${BACKUP_TIMESTAMP}"
cp "${REDIS_CONF}" "${BACKUP_CONF}"
 
echo -e "\n【步骤3/5】开始修改Redis核心配置..."
sed -i "/^#*bind /d" "${REDIS_CONF}"
echo "bind ${REDIS_BIND_IP}" >> "${REDIS_CONF}"
sed -i "/^#*port /d" "${REDIS_CONF}"
echo "port ${REDIS_PORT}" >> "${REDIS_CONF}"
sed -i "/^#*requirepass /d" "${REDIS_CONF}"
echo "requirepass ${REDIS_PASSWORD}" >> "${REDIS_CONF}"
sed -i "/^#*protected-mode /d" "${REDIS_CONF}"
echo "protected-mode no" >> "${REDIS_CONF}"
sed -i "/^#*save /d" "${REDIS_CONF}"
echo "save 900 1" >> "${REDIS_CONF}"
echo "save 300 10" >> "${REDIS_CONF}"
echo "save 60 10000" >> "${REDIS_CONF}"
sed -i "/^#*appendonly /d" "${REDIS_CONF}"
echo "appendonly no" >> "${REDIS_CONF}"
echo "Redis核心配置修改完成！"

echo -e "\n【步骤4/5】重启Redis服务并配置开机自启..."
systemctl restart "${SERVICE_NAME}"
sleep 3

echo -e "\n【步骤5/5】验证Redis配置有效性..."
REDIS_CHECK=$(redis-cli -h "${REDIS_BIND_IP}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" PING 2>/dev/null)
if [ "${REDIS_CHECK}" = "PONG" ]; then
    echo "Redis连接验证成功！配置已生效"
else
    echo "警告：Redis连接验证失败，请检查配置或服务状态"
    echo "  排查命令：redis-cli -h ${REDIS_BIND_IP} -p ${REDIS_PORT} -a ${REDIS_PASSWORD}"
fi

# ==================== 脚本执行完成提示 ====================
echo -e "\n======================================"
echo "  Redis 安装与配置流程全部完成！"
echo "  关键信息："
echo "    1. 绑定IP: ${REDIS_BIND_IP}"
echo "    2. 监听端口: ${REDIS_PORT}"
echo "    3. 认证密码: ${REDIS_PASSWORD}"
echo "    4. 配置文件: ${REDIS_CONF}"
echo "    5. 备份文件: ${BACKUP_CONF}"
echo "    6. 服务状态: 已启动 + 开机自启"
echo "======================================"