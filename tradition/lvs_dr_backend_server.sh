#!/bin/bash
# *************************************
# * 功能: 定制DR的后端真实主机环境
# * 适配: Ubuntu 24.04
# * 作者: 李芝全
# * 版本: 2025-10-22
# *************************************

# 定义网络相关变量
# vip=10.0.0.100
mask='255.255.255.255'
dev=lo:1

# 定义内核配置路径前缀
conf_path="/proc/sys/net/ipv4/conf"

# 定义 ARP 配置文件路径数组
arp_ignore_files=(
    "${conf_path}/all/arp_ignore"
    "${conf_path}/lo/arp_ignore"
)
arp_announce_files=(
    "${conf_path}/all/arp_announce"
    "${conf_path}/lo/arp_announce"
)

# 配置 ARP 参数的函数
configure_arp() {
    local value=$1
    for file in "${arp_ignore_files[@]}"; do
        echo "$value" > "$file"
    done
    local announce_value=$((value * 2))
    for file in "${arp_announce_files[@]}"; do
        echo "$announce_value" > "$file"
    done
}

# 启动服务的函数
start_service() {
    configure_arp 1
    ifconfig "$dev" "$vip" netmask "$mask"
    echo "The RS Server is Ready!"
}

# 停止服务的函数
stop_service() {
    ifconfig "$dev" down
    configure_arp 0
    echo "The RS Server is Canceled!"
}

# 定义获取VIP的函数（支持空输入使用默认值，并验证格式）
get_vip() {
    local default_vip="10.0.0.130"  # 默认VIP
    local vip_input                 # 用于接收用户输入

    # 提示用户输入，显示默认值
    read -p "请输入虚拟IP地址（默认：$default_vip）：" vip_input

    # 如果输入为空，直接使用默认值
    if [ -z "$vip_input" ]; then
        echo "$default_vip"
        return 0
    fi
    echo "$vip_input"
    # 缺少ip地址的格式限制验证功能，如果有需要的话，可以自己加
}

# 主函数，根据参数调用相应的函数
main() {
    case $1 in
        start)
            # 获取vip
            vip=$(get_vip)
            start_service
            ;;
        stop)
            stop_service
            ;;
        *)
            echo "Usage: $(basename "$0") start|stop"
            exit 1
            ;;
    esac
}

# 调用主函数
main "$1"
