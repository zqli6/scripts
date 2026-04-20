#!/bin/bash
# *************************************
# * 功能: 设定主机名和主机ip
# * 作者: 李芝全
# * 联系: zqli6@qq.com
# * 版本: 2025-12-27
# *************************************

set -e  # 遇到错误立即退出

# 1. 提示用户输入IP地址（仅需输入最后一段，如147）
read -p "请输入10.0.0.0/24网段的IP最后一段（如147）：" IP_LAST
IP_FULL="10.0.0.${IP_LAST}"
HOSTNAME="ubuntu24-${IP_LAST}"

# 2. 设置主机名
echo "正在设置主机名为：${HOSTNAME}"
hostnamectl set-hostname "${HOSTNAME}"
source /etc/profile

# 3. 定制apt源
rm -rf /etc/apt/sources.list.d/*
cat > /etc/apt/sources.list <<-eof
deb https://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
eof

# 4. 生成新的netplan配置（网关默认用10.0.0.2，可根据实际修改）
rm -rf /etc/netplan/*
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
echo "正在生成netplan网络配置（IP：${IP_FULL}/24）"
cat > "${NETPLAN_FILE}" << EOF
network:
  version: 2
  ethernets:
    ens33:  # 注意：需确保网卡名正确（可通过ip a查看）
      addresses:
        - "${IP_FULL}/24"
      nameservers:
        addresses:
          - 10.0.0.2  # DNS服务器可根据实际修改
      routes:
        - to: default
          via: 10.0.0.2  # 网关地址可根据实际修改
EOF
chmod 600 "${NETPLAN_FILE}"

# 5. 应用netplan配置并验证
echo "正在应用网络配置..."
netplan apply
> ~/.bash_history


# 6. 验证结果
echo -e "\n配置完成！当前信息："
echo "主机名：$(hostname)"
echo "IP地址：$(hostname -I)"
rm -f $0 && echo "脚本已成功自我删除"