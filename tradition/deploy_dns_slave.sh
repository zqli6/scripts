#!/bin/bash
# *************************************
# * 功能: 自动化部署dns-slave节点
# * 作者: 李芝全
# * 适配: Ubuntu系统 + MySQL 8.0+
# * 版本: 2025-12-20
# *************************************

set -e  # 遇到错误立即退出，确保配置完整性

# ==================== 核心配置参数（可按需修改） ====================
SLAVE_IP="10.0.0.148"           # 从DNS服务器自身IP
MASTER_IP="10.0.0.147"          # 主DNS服务器IP（用于同步区域数据）
DOMAIN="magedu.com"             # 需同步的正向解析域名
OPTIONS_FILE="/etc/bind/named.conf.options"
LOCAL_FILE="/etc/bind/named.conf.local"
SLAVE_ZONE_FILE="/var/cache/bind/db.${DOMAIN}"  # 从服务器区域文件（自动同步，无需手动创建）

# ==================== 脚本执行提示 ====================
echo "======================================"
echo "  开始部署Bind9从DNS服务器（${DOMAIN}）"
echo "  从DNS IP：${SLAVE_IP}"
echo "  主DNS IP：${MASTER_IP}"
echo "======================================"

# ==================== 步骤1：安装bind9软件包 ====================
echo -e "\n【步骤1/6】安装bind9软件..."
apt update && apt install bind9 -y > /dev/null 2>&1

# 验证并确保bind9服务启动
if [ "$(systemctl is-active bind9)" != "active" ]; then
    systemctl start bind9
    echo "bind9服务已手动启动"
else
    echo "bind9服务已自动启动"
fi

# ==================== 步骤2：修改named.conf.options配置 ====================
echo -e "\n【步骤2/6】修改${OPTIONS_FILE}配置..."
# 备份原有配置文件
if [ -f "${OPTIONS_FILE}" ]; then
    cp "${OPTIONS_FILE}" "${OPTIONS_FILE}.bak"
    echo "已备份原有配置至${OPTIONS_FILE}.bak"
fi

# 写入从DNS专属配置（无allow-transfer，无需转发器）
cat > "${OPTIONS_FILE}" << EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { 10.0.0.0/24; };
    dnssec-validation auto;
    listen-on { ${SLAVE_IP}; };
};
EOF
echo "named.conf.options配置修改完成"

# ==================== 步骤3：修改named.conf.local，添加从区域配置 ====================
echo -e "\n【步骤3/6】修改${LOCAL_FILE}配置，添加从区域..."
# 备份原有配置文件
if [ -f "${LOCAL_FILE}" ]; then
    cp "${LOCAL_FILE}" "${LOCAL_FILE}.bak"
    echo "已备份原有配置至${LOCAL_FILE}.bak"
fi

# 追加从区域配置（不覆盖原有其他配置）
cat >> "${LOCAL_FILE}" << EOF

// 从区域配置 - ${DOMAIN}
zone "${DOMAIN}" {
    type slave;
    file "${SLAVE_ZONE_FILE}";
    masters { ${MASTER_IP}; };
};
EOF
echo "named.conf.local从区域配置添加完成"

# ==================== 步骤4：重启named服务（临时生效基础配置） ====================
echo -e "\n【步骤4/6】重启named服务加载基础配置..."
systemctl restart named
echo "named服务已重启"

# ==================== 步骤5：配置语法检查（全局+区域） ====================
echo -e "\n【步骤5/6】检查Bind9配置语法..."
# 1. 检查全局配置语法
if named-checkconf; then
    echo "全局配置文件（named.conf.*）语法检查：OK"
else
    echo "错误：全局配置文件语法有误，请手动排查！"
    exit 1
fi

# 2. 检查从区域配置（无需手动检查区域文件，自动同步后生效）
echo "从区域（${DOMAIN}）配置语法检查：无需手动验证（同步后自动生效）"

# ==================== 步骤6：设置开机自启并重启服务 ====================
echo -e "\n【步骤6/6】设置named服务开机自启并最终重启..."
# 设置开机自启（静默执行，不输出冗余信息）
systemctl enable named > /dev/null 2>&1
# 最终重启服务，加载所有配置
systemctl restart named

# 验证服务最终状态
if [ "$(systemctl is-active named)" = "active" ]; then
    echo "named服务开机自启已配置，重启后状态：active"
else
    echo "警告：named服务重启后状态异常，请手动执行 systemctl status named 排查！"
fi

# ==================== 部署完成提示 ====================
echo -e "\n======================================"
echo "  Bind9从DNS服务器部署完成！"
echo "  核心信息："
echo "    域名：${DOMAIN}"
echo "    从DNS IP：${SLAVE_IP}"
echo "    主DNS IP：${MASTER_IP}"
echo "    从区域文件：${SLAVE_ZONE_FILE}（自动从主DNS同步）"
echo "    服务状态：$(systemctl is-active named)"
echo "  验证提示：可通过 nslookup ${DOMAIN} ${SLAVE_IP} 测试解析功能"
echo "======================================"