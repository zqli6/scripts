#!/bin/bash
# *************************************
# * 功能: 自动化部署sersync服务（nfs1节点，含三个同步模块）
# * 作者: 李芝全
# * 联系: wangshusen@sswang.com
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出，确保配置完整性

# ==================== 核心配置参数（可按需修改） ====================
SOFT_DIR="/data/softs"                  # 软件下载目录
SERVER_DIR="/data/server"               # sersync安装根目录
SERSYNC_DIR="${SERVER_DIR}/sersync"     # sersync主目录
SERSYNC_CONF_DIR="${SERSYNC_DIR}/conf"  # sersync配置目录
SERSYNC_BIN_DIR="${SERSYNC_DIR}/bin"    # sersync可执行文件目录
DOWNLOAD_URL="https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/sersync/sersync2.5.4_64bit_binary_stable_final.tar.gz"
TARGET_NFS_IP="10.0.0.21"               # 目标nfs2节点IP
RSYNC_AUTH_USER="rsync_user"            # rsync认证用户
RSYNC_PWD_FILE="/etc/rsyncd.pwd"        # rsync密码文件路径
SYNC_MODULES=("jpress" "wordpress" "discuz")  # 同步模块名称
SYNC_LOCAL_DIRS=("/data/jpress" "/data/wordpress" "/data/discuz")  # 本地监控目录
SERSYNC_SERVICE_DIR="/etc/systemd/system"  # 系统服务文件目录
XML_CHECK_TOOL="libxml2-utils"          # xml语法检测工具


echo -e "\n【步骤1/8】创建目录并下载解压sersync软件..."
# 创建软件下载目录
[ ! -d "${SOFT_DIR}" ] && mkdir -pv "${SOFT_DIR}" > /dev/null 2>&1
[ -d "${SERVER_DIR}" ] && rm -rf "${SERVER_DIR}"
mkdir -pv "${SERVER_DIR}" > /dev/null 2>&1
cd "${SOFT_DIR}"
if [ ! -f "$(basename ${DOWNLOAD_URL})" ]; then
    wget "${DOWNLOAD_URL}" > /dev/null 2>&1
fi

# 解压软件并重命名目录
tar xf "$(basename ${DOWNLOAD_URL})" -C "${SERVER_DIR}" > /dev/null 2>&1
if [ -d "${SERVER_DIR}/GNU-Linux-x86" ]; then
    mv "${SERVER_DIR}/GNU-Linux-x86" "${SERSYNC_DIR}"
fi

# 创建bin和conf目录并移动文件
mkdir -pv "${SERSYNC_BIN_DIR}" "${SERSYNC_CONF_DIR}" > /dev/null 2>&1
if [ -f "${SERSYNC_DIR}/sersync2" ]; then
    mv "${SERSYNC_DIR}/sersync2" "${SERSYNC_BIN_DIR}/"
fi

echo -e "\n【步骤2/8】安装${XML_CHECK_TOOL}工具..."
apt update && apt install -y "${XML_CHECK_TOOL}" > /dev/null 2>&1

echo -e "\n【步骤3/8】创建jpress模块sersync配置文件..."
JPRESS_CONF_FILE="${SERSYNC_CONF_DIR}/jpress_conf.xml"
cat > "${JPRESS_CONF_FILE}" << EOF
<?xml version="1.0" encoding="ISO-8859-1"?>
<head version="2.5">
    <host hostip="localhost" port="8008"></host>
    <debug start="false"/>
    <fileSystem xfs="false"/>
    <filter start="false">
        <exclude expression="(.*)\.svn"></exclude>
        <exclude expression="(.*)\.gz"></exclude>
    </filter>
    <inotify>
        <delete start="true"/>
        <createFolder start="true"/>
        <createFile start="true"/>
        <closeWrite start="true"/>
        <moveFrom start="true"/>
        <moveTo start="true"/>
        <attrib start="true"/>
        <modify start="true"/>
    </inotify>

    <sersync>
        <localpath watch="/data/jpress">
            <remote ip="${TARGET_NFS_IP}" name="jpress"/>
        </localpath>
        <rsync>
            <commonParams params="-artuz"/>
            <auth start="true" users="${RSYNC_AUTH_USER}" passwordfile="${RSYNC_PWD_FILE}"/>
            <userDefinedPort start="false" port="873"/>
            <timeout start="true" time="100"/>
            <ssh start="false"/>
        </rsync>
        <failLog path="/var/log/sersync_fail.log" timeToExecute="60"/>
        <crontab start="false" schedule="600">
            <crontabfilter start="false">
                <exclude expression="*.php"></exclude>
                <exclude expression="info/*"></exclude>
            </crontabfilter>
        </crontab>
        <plugin start="false" name="command"/>
    </sersync>
</head>
EOF

# 验证xml配置语法
xmllint --noout "${JPRESS_CONF_FILE}" > /dev/null 2>&1
echo "jpress配置文件 ${JPRESS_CONF_FILE} 创建完成，语法验证：OK"

echo -e "\n【步骤4/8】创建wordpress和discuz模块配置文件..."
for module in "wordpress" "discuz"; do
    MODULE_CONF_FILE="${SERSYNC_CONF_DIR}/${module}_conf.xml"
    cp "${JPRESS_CONF_FILE}" "${MODULE_CONF_FILE}"
    # 替换配置中的jpress为对应模块名
    sed -i "s/\/data\/jpress/\/data\/${module}/g" "${MODULE_CONF_FILE}"
    sed -i "s/name=\"jpress\"/name=\"${module}\"/g" "${MODULE_CONF_FILE}"
    # 验证语法
    xmllint --noout "${MODULE_CONF_FILE}" > /dev/null 2>&1
    echo "${module}配置文件 ${MODULE_CONF_FILE} 创建完成，语法验证：OK"
done

echo -e "\n【步骤5/8】创建jpress模块sersync系统服务文件..."
JPRESS_SERVICE_FILE="${SERSYNC_SERVICE_DIR}/sersync_jpress.service"
cat > "${JPRESS_SERVICE_FILE}" << 'EOF'
[Unit]
Description=Sersync service for /data/jpress directory sync
After=network.target rsync.service

[Service]
Type=forking
ExecStart=/data/server/sersync/bin/sersync2 -d -r -o /data/server/sersync/conf/jpress_conf.xml
ExecStop=pkill -f sersync2
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
echo "jpress服务文件 ${JPRESS_SERVICE_FILE} 创建完成"

# ==================== 步骤6：复制并修改wordpress/discuz服务文件 ====================
echo -e "\n【步骤6/8】创建wordpress和discuz模块服务文件..."
for module in "wordpress" "discuz"; do
    MODULE_SERVICE_FILE="${SERSYNC_SERVICE_DIR}/sersync_${module}.service"
    cp "${JPRESS_SERVICE_FILE}" "${MODULE_SERVICE_FILE}"
    # 替换服务文件中的jpress为对应模块名
    sed -i "s/jpress/${module}/g" "${MODULE_SERVICE_FILE}"
    echo "${module}服务文件 ${MODULE_SERVICE_FILE} 创建完成"
done

# ==================== 步骤7：重载系统服务并设置开机自启 ====================
echo -e "\n【步骤7/8】重载系统服务并配置开机自启..."
systemctl daemon-reload > /dev/null 2>&1
systemctl enable rsync > /dev/null 2>&1
for module in "${SYNC_MODULES[@]}"; do
    systemctl enable "sersync_${module}.service" > /dev/null 2>&1
done

echo -e "\n【步骤8/8】启动所有sersync服务并验证状态..."
# 重启rsync服务
systemctl restart rsync > /dev/null 2>&1
echo "rsync服务已重启"

# 启动三个sersync服务并验证状态
for module in "${SYNC_MODULES[@]}"; do
    SERVICE_NAME="sersync_${module}.service"
    systemctl restart "${SERVICE_NAME}" > /dev/null 2>&1
    if [ "$(systemctl is-active "${SERVICE_NAME}")" = "active" ]; then
        echo "${SERVICE_NAME} 启动成功，状态：active"
    else
        echo "警告：${SERVICE_NAME} 启动失败，请手动排查！"
    fi
done

# ==================== 部署完成提示 ====================
echo -e "\n======================================"
echo "  sersync服务部署完成！"
echo "  核心信息："
echo "    sersync目录：${SERSYNC_DIR}"
echo "    配置文件目录：${SERSYNC_CONF_DIR}"
echo "    服务文件目录：${SERSYNC_SERVICE_DIR}"
echo "    同步模块：${SYNC_MODULES[*]}"
echo "    目标同步IP：${TARGET_NFS_IP}"
echo "  验证提示：可在nfs1创建测试文件，在nfs2验证同步效果"
echo "  服务操作：systemctl [start/stop/restart] sersync_xxx.service"
echo "======================================"