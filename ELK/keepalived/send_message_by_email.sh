#!/bin/bash
# *************************************
# * 功能: Shell脚本模板
# * 作者: 王树森
# * 联系: wangshusen@sswang.com
# * 版本: 2025-08-01
# *************************************

# 配置邮件相关信息
contact='wshs1117@126.com'       #需更改自己的QQ邮箱信息
email_send='wshs1117@126.com'    #需更改自己的QQ邮箱信息
email_passwd='LTZFDDIVDRNYOOAL'  #需更改自己的QQ邮箱信息
email_smtp_server='smtp.126.com'

# 加载操作系统信息
. /etc/os-release

# 定义颜色输出函数
msg_error() {
    echo -e "\033[1;31m$1\033[0m"
}

msg_info() {
    echo -e "\033[1;32m$1\033[0m"
}

msg_warn() {
    echo -e "\033[1;33m$1\033[0m"
}

# 带颜色的状态输出函数
color() {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"

    echo -n "$1"
    $MOVE_TO_COL
    echo -n "["
    case $2 in
        success|0)
            $SETCOLOR_SUCCESS
            echo -n "  OK  "
            ;;
        failure|1)
            $SETCOLOR_FAILURE
            echo -n "FAILED"
            ;;
        *)
            $SETCOLOR_WARNING
            echo -n "WARNING"
            ;;
    esac
    $SETCOLOR_NORMAL
    echo -n "]"
    echo
}

# 安装 sendemail 工具
install_sendemail() {
    local package_installed=false
    case $ID in
        rhel|centos|rocky)
            if ! rpm -q sendemail &> /dev/null; then
                msg_info "正在安装 sendemail..."
                if yum install -y sendemail; then
                    package_installed=true
                else
                    msg_error "安装 sendemail 失败！"
                    exit 1
                fi
            else
                package_installed=true
            fi;;
        ubuntu)
            if ! dpkg -l | grep -q sendemail; then
                msg_info "正在更新软件源并安装 sendemail..."
                if apt update && apt install -y libio-socket-ssl-perl libnet-ssleay-perl sendemail; then
                    package_installed=true
                else
                    msg_error "安装 sendemail 失败！"
                    exit 1
                fi
            else
                package_installed=true
            fi;;
        *)
            msg_error "不支持此操作系统，退出!"
            exit 1;;
    esac
}

# 发送邮件函数
send_email() {
    local email_receive="$1"
    local email_subject="$2"
    local email_message="$3"

    # 验证邮件接收地址是否为空
    if [ -z "$email_receive" ]; then
        msg_error "邮件接收地址不能为空！"
        return 1
    fi

    sendemail -f "$email_send" -t "$email_receive" -u "$email_subject" -m "$email_message" -s "$email_smtp_server" -o message-charset=utf-8 -o tls=yes -xu "$email_send" -xp "$email_passwd"
    local send_status=$?
    if [ $send_status -eq 0 ]; then
        color "邮件发送成功!" 0
    else
        color "邮件发送失败!" 1
    fi
    return $send_status
}

# 通知函数
notify() {
    local state="$1"
    # 验证输入的状态是否合法
    if [[ $state =~ ^(master|backup|fault)$ ]]; then
        local mailsubject="$(hostname) to be $state, vip floating"
        local mailbody="$(date +'%F %T'): vrrp transition, $(hostname) changed to be $state"
        send_email "$contact" "$mailsubject" "$mailbody"
    else
        msg_error "Usage: $(basename $0) {master|backup|fault}"
        exit 1
    fi
}

# 主程序入口
main() {
    # 验证输入参数是否存在
    if [ $# -eq 0 ]; then
        msg_error "请提供脚本运行状态参数 {master|backup|fault}"
        exit 1
    fi

    install_sendemail
    notify "$1"
}

# 执行主函数，接收三个选项
main "$@"