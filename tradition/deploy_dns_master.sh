#!/bin/bash
# *************************************
# * 功能: 自动化部署dns-master节点
# * 作者: 李芝全
# * 联系: zqli6@qq.com
# * 版本: 2025-12-20
# *************************************

set -e  # 遇到错误立即退出，保证脚本执行完整性
# 定义核心配置参数（可根据实际需求修改）
MASTER_IP="10.0.0.147"          # 主DNS服务器IP
SLAVE_IP="10.0.0.148"           # 从DNS服务器IP
DOMAIN="magedu.com"             # 正向解析域名
TTL_DEFAULT="1800"              # 默认TTL值
SERIAL="2025101901"             # 区域文件序列号
ZONE_DIR="/etc/bind/zones"      # 区域文件存放目录
OPTIONS_FILE="/etc/bind/named.conf.options"
LOCAL_FILE="/etc/bind/named.conf.local"
ZONE_FILE="${ZONE_DIR}/db.${DOMAIN}"

# 脚本执行提示
echo "======================================"
echo "  开始部署Bind9主DNS服务器（${DOMAIN}）"
echo "  主DNS IP：${MASTER_IP}"
echo "  从DNS IP：${SLAVE_IP}"
echo "======================================"

# 步骤1：安装bind9软件包
echo -e "\n【步骤1/8】安装bind9软件..."
apt update && apt install bind9 -y
# 验证bind9是否启动
if [ "$(systemctl is-active bind9)" != "active" ]; then
    systemctl start bind9
    echo "bind9已手动启动"
else
    echo "bind9已自动启动"
fi

# 步骤2：修改named.conf.options配置文件
echo -e "\n【步骤2/8】修改${OPTIONS_FILE}配置..."
# 备份原有配置文件
if [ -f "${OPTIONS_FILE}" ]; then
    cp "${OPTIONS_FILE}" "${OPTIONS_FILE}.bak"
    echo "已备份原有配置至${OPTIONS_FILE}.bak"
fi
# 写入新配置
cat > "${OPTIONS_FILE}" << EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { 10.0.0.0/24; };
    allow-transfer { ${SLAVE_IP}; };
    forwarders { 8.8.8.8; 114.114.114.114; };
    dnssec-validation auto;
    listen-on { ${MASTER_IP}; };
};
EOF
echo "named.conf.options配置修改完成"

# 步骤3：修改named.conf.local配置文件，添加正向解析区域
echo -e "\n【步骤3/8】修改${LOCAL_FILE}配置..."
# 备份原有配置文件
if [ -f "${LOCAL_FILE}" ]; then
    cp "${LOCAL_FILE}" "${LOCAL_FILE}.bak"
    echo "已备份原有配置至${LOCAL_FILE}.bak"
fi
# 追加正向解析区域配置（避免覆盖原有其他配置）
cat >> "${LOCAL_FILE}" << EOF

// 正向解析区域 - ${DOMAIN}
zone "${DOMAIN}" {
    type master;
    file "${ZONE_FILE}";
    notify yes;
    also-notify { ${SLAVE_IP}; };
};
EOF
echo "named.conf.local配置修改完成"

# 步骤4：创建区域文件存放目录
echo -e "\n【步骤4/8】创建区域文件目录${ZONE_DIR}..."
mkdir -p "${ZONE_DIR}"
echo "目录创建成功（若已存在则跳过）"

# 步骤5：复制模板文件并修改正向解析区域文件
echo -e "\n【步骤5/8】创建并修改正向解析区域文件${ZONE_FILE}..."
# 复制模板文件
cp /etc/bind/db.local "${ZONE_FILE}"
# 覆盖写入完整的区域配置
cat > "${ZONE_FILE}" << EOF
\$TTL    ${TTL_DEFAULT}  ; 默认TTL（存储/缓存/运维层用此值，应用/反向代理/接入层需单独指定）
@       IN      SOA     dns1.${DOMAIN}. admin.${DOMAIN}. (
                        ${SERIAL}  ; 序列号（主从同步的关键，每次修改+1）
                        3600        ; 刷新时间（从服务器多久查一次主服务器更新）
                        1800        ; 重试时间（刷新失败后多久重试）
                        604800      ; 过期时间（从服务器多久后停止使用旧数据）
                        86400 )     ; 否定缓存时间
; Nameserver 记录（DNS服务器自身解析）
        IN      NS      dns1.${DOMAIN}.
        IN      NS      dns2.${DOMAIN}.
; DNS服务器IP解析
dns1    IN      A       ${MASTER_IP}
dns2    IN      A       ${SLAVE_IP}

; 存储层解析（TTL=${TTL_DEFAULT}，默认已匹配）
mysql-master  IN      A       10.0.0.10
mysql-slave1  IN      A       10.0.0.11
mysql-slave2  IN      A       10.0.0.12
nfs-storage   IN      A       10.0.0.200
nfs1          IN      A       10.0.0.20
nfs2          IN      A       10.0.0.21
backup        IN      A       10.0.0.22

; 缓存层解析（TTL=${TTL_DEFAULT}，默认已匹配）
redis-master  IN      A       10.0.0.30
redis-slave   IN      A       10.0.0.31

; 应用层（单独设置TTL=300，格式：TTL值 + 记录类型）
\$TTL 300
mycat         IN      A       10.0.0.201
mycat1        IN      A       10.0.0.50
mycat2        IN      A       10.0.0.51
jpress-1      IN      A       10.0.0.60
jpress-2      IN      A       10.0.0.61
wordpress     IN      A       10.0.0.70
discuz        IN      A       10.0.0.71

; 反向代理层（TTL=300，沿用上面的\$TTL 300）
nginx-1       IN      A       10.0.0.105
nginx-2       IN      A       10.0.0.106

; 接入层（vip需要TTL=300，其他用默认${TTL_DEFAULT}）
\$TTL ${TTL_DEFAULT}
lvs-master    IN      A       10.0.0.125
lvs-backup    IN      A       10.0.0.126
\$TTL 300
vip           IN      A       10.0.0.130

; 运维层（zabbix需要TTL=3600）
\$TTL 3600
zabbix-master IN      A       10.0.0.145
zabbix-slave  IN      A       10.0.0.146
\$TTL ${TTL_DEFAULT}
ansible       IN      A       10.0.0.149

; 业务入口层（TTL=300）
\$TTL 300
www           IN      CNAME   vip.${DOMAIN}.
EOF
echo "正向解析区域文件创建完成"

# 步骤6：检查配置文件语法正确性
echo -e "\n【步骤6/8】检查Bind9配置语法..."
# 检查全局配置
if named-checkconf; then
    echo "全局配置文件（named.conf.*）语法检查：OK"
else
    echo "错误：全局配置文件语法有误！"
    exit 1
fi
# 检查区域文件配置
if named-checkzone "${DOMAIN}" "${ZONE_FILE}"; then
    echo "正向区域文件（${ZONE_FILE}）语法检查：OK"
else
    echo "错误：正向区域文件语法有误！"
    exit 1
fi

# 步骤7：设置named服务开机自启并重启服务
echo -e "\n【步骤7/8】设置named服务开机自启并重启..."
systemctl enable named > /dev/null 2>&1
systemctl restart named
# 验证服务重启后状态
if [ "$(systemctl is-active named)" = "active" ]; then
    echo "named服务重启成功，状态：active"
else
    echo "警告：named服务重启后状态异常，请手动检查！"
fi

# 步骤8：脚本执行完成提示
echo -e "\n======================================"
echo "  Bind9主DNS服务器部署完成！"
echo "  核心信息："
echo "    域名：${DOMAIN}"
echo "    主DNS IP：${MASTER_IP}"
echo "    区域文件：${ZONE_FILE}"
echo "    服务状态：$(systemctl is-active named)"
echo "======================================"