#!/bin/bash
# *************************************
# * 功能: 自动化部署rsync服务（nfs1节点专属）
# * 作者: 王树森
# * 适配: Ubuntu系统
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出，确保配置完整性

# ==================== 核心配置参数（可按需修改） ====================
RSYNC_CONF_FILE="/etc/rsyncd.conf"        # rsync核心配置文件
RSYNC_SECRETS_FILE="/etc/rsyncd.secrets"  # rsync认证密码文件
RSYNC_CLIENT_FILE="/etc/rsyncd.pwd"       # rsync客户端认证密码文件
RSYNC_AUTH_USER="rsync_user"              # rsync认证用户名
RSYNC_AUTH_PASS="Rsync123"                # rsync认证密码
ALLOW_CLIENT_IPS="10.0.0.20/32 10.0.0.21/32"  # 允许访问的客户端IP
SYNC_MODULES=("jpress" "wordpress" "discuz")  # 同步模块名称
SYNC_DIRS=("/data/jpress" "/data/wordpress" "/data/discuz")  # 模块对应目录
RSYNC_SERVICE="rsync.service"             # rsync服务名称
MAX_CONNECTIONS="10"                      # rsync最大连接数


echo -e "\n【步骤1/4】安装rsync和inotify-tools软件..."
apt update && apt install -y rsync inotify-tools > /dev/null 2>&1

echo -e "\n【步骤2/4】创建${RSYNC_CONF_FILE}配置文件..."
# 备份原有配置文件（若存在）
[ -f "${RSYNC_CONF_FILE}" ] && cp "${RSYNC_CONF_FILE}" "${RSYNC_CONF_FILE}.bak"
# 写入rsync全局配置
cat > "${RSYNC_CONF_FILE}" << EOF
# 全局配置
uid = root
gid = root
use chroot = no
max connections = ${MAX_CONNECTIONS}
pid file = /var/run/rsyncd.pid
lock file = /var/run/rsync.lock
log file = /var/log/rsyncd.log
ignore errors
read only = no
list = no
EOF

# 循环写入各个同步模块配置
for index in "${!SYNC_MODULES[@]}"; do
    module_name="${SYNC_MODULES[$index]}"
    module_path="${SYNC_DIRS[$index]}"
    module_comment="${module_name} data sync"

    cat >> "${RSYNC_CONF_FILE}" << EOF

# 同步模块：${module_name}（对应${module_path}目录）
[${module_name}]
path = ${module_path}
comment = ${module_comment}
hosts allow = ${ALLOW_CLIENT_IPS}
auth users = ${RSYNC_AUTH_USER}
secrets file = ${RSYNC_SECRETS_FILE}
EOF
done

echo -e "\n【步骤3/4】创建${RSYNC_SECRETS_FILE}认证文件..."
# 写入用户名:密码格式
echo "${RSYNC_AUTH_USER}:${RSYNC_AUTH_PASS}" > "${RSYNC_SECRETS_FILE}"
echo "${RSYNC_AUTH_PASS}" > "${RSYNC_CLIENT_FILE}"
chmod 600 "${RSYNC_SECRETS_FILE}" "${RSYNC_CLIENT_FILE}"

echo -e "\n【步骤4/4】设置${RSYNC_SERVICE}服务开机自启..."
systemctl enable ${RSYNC_SERVICE} > /dev/null 2>&1
systemctl restart ${RSYNC_SERVICE} > /dev/null 2>&1

# 最终验证服务状态
if [ "$(systemctl is-active ${RSYNC_SERVICE})" = "active" ]; then
    echo "${RSYNC_SERVICE}服务最终状态：active（运行正常）"
else
    echo "警告：${RSYNC_SERVICE}服务最终状态异常，请手动排查！"
fi

# ==================== 部署完成提示 ====================
echo -e "\n======================================"
echo "  rsync服务部署完成！"
echo "  核心信息："
echo "    配置文件：${RSYNC_CONF_FILE}"
echo "    认证文件：${RSYNC_SECRETS_FILE}"
echo "    认证用户：${RSYNC_AUTH_USER}"
echo "    同步模块：${SYNC_MODULES[*]}"
echo "    服务名称：${RSYNC_SERVICE}"
echo "    服务状态：$(systemctl is-active ${RSYNC_SERVICE})"
echo "  验证提示：可通过 rsync ${RSYNC_AUTH_USER}@\$(hostname -i):: 测试模块列表"
echo "======================================"