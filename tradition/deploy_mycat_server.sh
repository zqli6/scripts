#!/bin/bash
# *************************************
# * 功能: MyCat 一键部署自动化脚本
# * 适配: Ubuntu 24.04
# * 作者: 李芝全
# * 版本: 2025-12-28
# *************************************

set -e  # 错误立即退出，保证流程完整性
set -u  # 未定义变量报错，避免隐性bug

# ==================== 核心配置参数（可按需修改） ====================
# 基础环境配置
JAVA_PACKAGE="openjdk-8-jdk"
MYSQL_CLIENT_PACKAGE="mysql-client"
# MyCat配置
MYCAT_SOFT_DIR="/data/softs"
MYCAT_INSTALL_DIR="/data/server"
MYCAT_TAR_URL="https://github.com/MyCATApache/Mycat-Server/releases/download/Mycat-server-1675-release/Mycat-server-1.6.7.5-release-20200422133810-linux.tar.gz"
MYCAT_TAR_NAME=$(basename ${MYCAT_TAR_URL})
MYCAT_CONF_DIR="${MYCAT_INSTALL_DIR}/mycat/conf"
MYCAT_LOG_DIR="${MYCAT_INSTALL_DIR}/mycat/logs"
# MySQL主节点配置（用于创建MyCat授权账号）
MYSQL_MASTER_IP="10.0.0.10"
MYCAT_DB_USER="mycat"
MYCAT_DB_PASS="MyCat@123"
MYSQL_ALLOW_HOST="10.0.0.%"
# MyCat系统服务配置
MYCAT_SERVICE_FILE="/etc/systemd/system/mycat.service"


echo -e "\n【步骤1/6】安装Java环境（${JAVA_PACKAGE}）与MySQL客户端（${MYSQL_CLIENT_PACKAGE}）..."
apt update -y >/dev/null 2>&1
apt install -y ${JAVA_PACKAGE} ${MYSQL_CLIENT_PACKAGE} >/dev/null 2>&1
JAVA_VERSION=$(java -version 2>&1 | grep "openjdk version" | awk '{print $3}')
echo "  - Java版本: ${JAVA_VERSION}"

echo -e "\n【步骤2/6】创建目录并下载MyCat软件..."
mkdir -p ${MYCAT_SOFT_DIR}
mkdir -p ${MYCAT_INSTALL_DIR}
cd ${MYCAT_SOFT_DIR}
[ -f ${MYCAT_TAR_NAME} ] || wget ${MYCAT_TAR_URL} >/dev/null 2>&1

echo -e "\n【步骤3/6】解压MyCat软件到 ${MYCAT_INSTALL_DIR}..."
tar xf ${MYCAT_TAR_NAME} -C ${MYCAT_INSTALL_DIR}

echo -e "\n【步骤4/6】配置MyCat schema.xml（读写分离规则）..."
cp ${MYCAT_CONF_DIR}/schema.xml ${MYCAT_CONF_DIR}/schema.xml.bak.$(date +%Y%m%d_%H%M%S)
cat > ${MYCAT_CONF_DIR}/schema.xml << EOF
<?xml version="1.0"?>
<!DOCTYPE mycat:schema SYSTEM "schema.dtd">
<mycat:schema xmlns:mycat="http://io.mycat/">
    <!-- 逻辑库1：对应物理库 jpress -->
    <schema name="jpress" checkSQLschema="false" sqlMaxLimit="100" dataNode="dn_jpress"/>

    <!-- 逻辑库2：对应物理库 wordpress -->
    <schema name="wordpress" checkSQLschema="false" sqlMaxLimit="100" dataNode="dn_wordpress"/>

    <!-- 逻辑库3：对应物理库 discuz -->
    <schema name="discuz" checkSQLschema="false" sqlMaxLimit="100" dataNode="dn_discuz"/>

    <!-- 数据节点：分别关联三个物理库 -->
    <dataNode name="dn_jpress" dataHost="mysql_host" database="jpress"/>
    <dataNode name="dn_wordpress" dataHost="mysql_host" database="wordpress"/>
    <dataNode name="dn_discuz" dataHost="mysql_host" database="discuz"/>

    <!-- 数据主机：主从数据源配置（共用一套主从集群） -->
    <dataHost name="mysql_host" maxCon="1000" minCon="10" balance="1"
              writeType="0" dbType="mysql" dbDriver="native" switchType="1" slaveThreshold="100">
        <!-- 心跳检测：确认主从节点存活 -->
        <heartbeat>select 1</heartbeat>

        <!-- 主节点：处理所有写操作 -->
        <writeHost host="master" url="10.0.0.10:3306" user="mycat" password="MyCat@123">
            <!-- 从节点1：处理读操作（负载均衡） -->
            <readHost host="slave1" url="10.0.0.11:3306" user="mycat" password="MyCat@123"/>
            <!-- 从节点2：处理读操作（负载均衡） -->
            <readHost host="slave2" url="10.0.0.12:3306" user="mycat" password="MyCat@123"/>
        </writeHost>
    </dataHost>
</mycat:schema>
EOF

echo -e "\n【步骤5/6】配置MyCat server.xml（应用访问用户）..."
cp ${MYCAT_CONF_DIR}/server.xml ${MYCAT_CONF_DIR}/server.xml.bak.$(date +%Y%m%d_%H%M%S)
cat > ${MYCAT_CONF_DIR}/server.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mycat:server SYSTEM "server.dtd">
<mycat:server xmlns:mycat="http://io.mycat/">
    <!-- 系统参数配置（保持默认，或按需调整） -->
    <system>
        <property name="useHandshakeV10">1</property>
        <property name="serverPort">3306</property>
    </system>

    <!-- 应用访问用户：授予三个逻辑库的权限 -->
    <user name="appuser">
        <property name="password">123456</property>  <!-- 应用连接密码 -->
        <property name="schemas">jpress,wordpress,discuz</property>  <!-- 关联的逻辑库 -->
        <property name="defaultSchema">jpress</property> <!-- 该属性意义不大 -->
    </user>
</mycat:server>
EOF

echo -e "\n【步骤6/6】创建MyCat日志目录并配置系统服务..."
mkdir -p ${MYCAT_LOG_DIR}
echo "  - 已创建MyCat日志目录：${MYCAT_LOG_DIR}"
cat > ${MYCAT_SERVICE_FILE} << EOF
[Unit]
Description=MyCat Server
After=network.target
Wants=network.target

[Service]
WorkingDirectory=${MYCAT_INSTALL_DIR}/mycat
ExecStart=${MYCAT_INSTALL_DIR}/mycat/bin/mycat start
ExecStop=${MYCAT_INSTALL_DIR}/mycat/bin/mycat stop
ExecReload=${MYCAT_INSTALL_DIR}/mycat/bin/mycat restart
Restart=on-failure
RestartSec=3s
Type=forking
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now mycat

# ==================== 脚本执行完成提示 ====================
echo -e "\n======================================"
echo "  MyCat 一键部署流程全部完成！"
echo "  关键信息汇总："
echo "    1.  Java环境：${JAVA_PACKAGE}（版本：${JAVA_VERSION}）"
echo "    2.  MyCat安装路径：${MYCAT_INSTALL_DIR}/mycat"
echo "    3.  MyCat配置文件：${MYCAT_CONF_DIR}/schema.xml、${MYCAT_CONF_DIR}/server.xml"
echo "    4.  MyCat日志路径：${MYCAT_LOG_DIR}"
echo "    5.  连接MyCat：mysql -h 本机IP -P 3306 -u appuser -p123456"
echo "======================================"