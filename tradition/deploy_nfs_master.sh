#!/bin/bash
# *************************************
# * 功能: 自动化部署NFS Server服务节点
# * 作者: 王树森
# * 适配: Ubuntu系统
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出，确保配置完整性

# ==================== 核心配置参数（可按需修改） ====================
NFS_WORK_ROOT="/data"          # NFS根工作目录
APP_DIRS=("jpress" "wordpress" "discuz") # 需创建的应用子目录
ALLOW_NET="10.0.0.0/24"        # 允许访问的客户端网段
NFS_OPTIONS="rw,sync,no_root_squash"
EXPORTS_FILE="/etc/exports"
NFS_SERVICE="nfs-server"

echo -e "\n【步骤1/6】安装nfs-server软件..."
apt update && apt install nfs-server -y > /dev/null 2>&1

echo -e "\n【步骤2/6】创建NFS工作目录及应用子目录..."
[ ! -d "${NFS_WORK_ROOT}" ] && mkdir -pv ${NFS_WORK_ROOT}
for dir in "${APP_DIRS[@]}"; do
    full_dir="${NFS_WORK_ROOT}/${dir}"
    if [ ! -d "${full_dir}" ]; then
        mkdir -pv ${full_dir} > /dev/null 2>&1
    fi
done

echo -e "\n【步骤3/6】修改${EXPORTS_FILE}配置..."
# 备份原有配置文件
[ -f "${EXPORTS_FILE}" ] && cp "${EXPORTS_FILE}" "${EXPORTS_FILE}.bak"
# 写入NFS共享配置（覆盖写入，确保配置纯净）
> ${EXPORTS_FILE} # 清空原有配置
for dir in "${APP_DIRS[@]}"; do
    full_dir="${NFS_WORK_ROOT}/${dir}"
    echo "${full_dir} ${ALLOW_NET}(${NFS_OPTIONS})" >> ${EXPORTS_FILE}
done

echo -e "\n【步骤4/6】导出NFS共享配置，临时生效..."
exportfs -rv > /dev/null 2>&1

echo -e "\n【步骤5/6】重启${NFS_SERVICE}服务加载配置..."
systemctl restart ${NFS_SERVICE}

# 验证服务最终状态
if [ "$(systemctl is-active ${NFS_SERVICE})" = "active" ]; then
    echo "${NFS_SERVICE}服务开机自启已配置，重启后状态：active"
else
    echo "警告：${NFS_SERVICE}服务重启后状态异常，请手动执行 systemctl status ${NFS_SERVICE} 排查！"
fi

# ==================== 部署完成提示 ====================
echo -e "\n======================================"
echo "  NFS Server服务部署完成！"
echo "  核心信息："
echo "    NFS根目录：${NFS_WORK_ROOT}"
echo "    共享目录：${APP_DIRS[*]}"
echo "    允许网段：${ALLOW_NET}"
echo "    服务名称：${NFS_SERVICE}"
echo "    服务状态：$(systemctl is-active ${NFS_SERVICE})"
echo "  验证提示：可通过 showmount -e \$(hostname -i) 测试NFS共享列表"
echo "======================================"

