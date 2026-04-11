#!/bin/bash
# *************************************
# * 功能: 更改sersync服务（nfs2节点专属）
# * 作者: 王树森
# * 适配: Ubuntu系统
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出，确保操作完整性

# ==================== 核心配置参数（可按需修改） ====================
RSYNC_CONF_FILE="/etc/rsyncd.conf"        # rsync核心配置文件
SERSYNC_CONF_DIR="/data/server/sersync/conf"  # sersync配置文件目录
NEW_REMOTE_IP="10.0.0.22"                     # 新增的远程同步IP
SYNC_MODULES=("discuz" "jpress" "wordpress")  # 需要处理的模块列表
XML_CHECK_TOOL="libxml2-utils"                # xml语法检测工具
SERSYNC_SERVICES=("sersync_discuz.service" "sersync_jpress.service" "sersync_wordpress.service")  # 对应服务名

echo -e "\n【步骤1/3】为rsync文件新增remote节点..."
sed -i "/hosts/ s#\$# ${NEW_REMOTE_IP}/32#" "${RSYNC_CONF_FILE}"
systemctl restart rsync.service

echo -e "\n【步骤2/3】为每个配置文件新增remote节点..."
for module in "${SYNC_MODULES[@]}"; do
    conf_file="${SERSYNC_CONF_DIR}/${module}_conf.xml"
    # 备份原有配置文件
    cp "${conf_file}" "${conf_file}.bak.$(date +%Y%m%d%H%M%S)"
    echo "已备份 ${conf_file} 至 ${conf_file}.bak.$(date +%Y%m%d%H%M%S)"

    # 使用sed在现有<remote>节点后插入新的<remote>节点（或在<localpath>内插入）
    sed -i "/<remote ip=\"[0-9\.]*\" name=\"${module}\"\/>/a \            <remote ip=\"${NEW_REMOTE_IP}\" name=\"${module}\"/>" "${conf_file}"
    echo "${module}配置文件 ${conf_file} 已新增remote节点（IP：${NEW_REMOTE_IP}）"
done

echo -e "\n【步骤3/3】重启sersync服务并验证状态..."
# 重载systemd配置
systemctl daemon-reload > /dev/null 2>&1
for service in "${SERSYNC_SERVICES[@]}"; do
    systemctl restart "${service}" > /dev/null 2>&1
done

echo -e "\n======================================"
echo "  sersync配置新增remote节点操作完成！"
echo "  核心信息："
echo "    新增远程IP：${NEW_REMOTE_IP}"
echo "    配置文件目录：${SERSYNC_CONF_DIR}"
echo "    处理模块：${SYNC_MODULES[*]}"
echo "    验证提示：可通过 grep remote ${SERSYNC_CONF_DIR}/*.xml 查看新增结果"
echo "======================================"