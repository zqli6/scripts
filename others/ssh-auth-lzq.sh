#!/bin/bash
# auth：lizhiquan
# email：zqli6@qq.com
# 功能：多主机免密认证（支持自动补全IP与双密码尝试）

# 全局变量初始化
HOSTS=()

echo -e "\e[1;32m支持多主机并行验证，每台主机配置独立密码\e[0m\n"

# 1. 工具安装函数
install_tools() {
    while true; do
        # 同时检查 expect 和 ping
        if type expect > /dev/null 2>&1 && type ping > /dev/null 2>&1; then
            break
        fi

        read -t 10 -p "需安装 expect/ping 命令，是否继续(y/n)? " CH
        if [ $? -ne 0 ]; then
            echo -e "\e[31m\n--输入超时，自动退出--\e[0m"
            exit 1
        fi

        case "$CH" in
            [nN]*)
                echo -e "\e[30;41m------用户取消退出------\e[0m"
                exit 1
                ;;
            [yY]*)
                echo -e "\e[32m---正在确定包管理器---\e[0m"
                if command -v apt > /dev/null 2>&1; then
                    echo -e "\e[32m---正在通过 apt 安装缺失命令---\e[0m"
                    apt update &> /dev/null
                    apt install iputils-ping expect -y &> /dev/null
                elif command -v yum > /dev/null 2>&1; then
                    echo -e "\e[32m---正在通过 yum 安装缺失命令---\e[0m"
                    yum install iputils-ping expect -y &> /dev/null
                elif command -v dnf > /dev/null 2>&1; then
                    echo -e "\e[32m---正在通过 dnf 安装缺失命令---\e[0m"
                    dnf install iputils-ping expect -y &> /dev/null
                else
                    echo -e "\e[31m!!!未找到兼容的包管理器 (apt/yum/dnf)!!!\e[0m"
                    exit 1
                fi
                ;;
            *)
                echo -e "\e[31m!!!无效输入，请输入 y 或 n !!!\e[0m"
                ;;
        esac
    done
}

# 2. 密码收集函数
collect_passwd() {
    echo -e "\n\e[33m请输入登录密码（支持备用密码，若无则直接回车跳过备密码）：\e[0m"
    read -e -s -p "首选密码：" PASSWD
    echo ""
    read -e -s -p "备用密码：" EULERPASSWD
    echo ""
}

# 3. IP 收集函数
collect_ips() {
    PREFIX_REGEX='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}$'
    IP_REGEX='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])$'
    
    read -e -p "输入网络前缀（例如 192.168.1.）： " prefix
    while [[ ! $prefix =~ $PREFIX_REGEX ]]; do
        read -e -p "格式错误，请重新输入前缀： " prefix
    done
    
    echo -e "\n输入待处理 IP（支持完整 IP 或最后一段数字，空格分隔）："
    read -e -p "> " ip_input
    
    for x in $ip_input; do
        if [[ $x =~ $IP_REGEX ]]; then
            HOSTS+=("$x")
        elif [[ $x =~ ^[0-9]+$ ]]; then
            full_ip="${prefix}${x}"
            if [[ $full_ip =~ $IP_REGEX ]]; then
                HOSTS+=("$full_ip")
            else
                echo "跳过无效拼接: $full_ip"
            fi
        else
            echo "跳过非法输入: $x"
        fi
    done
}

# 4. 密钥生成函数
new_keygen() {
    rm -rf ~/.ssh/id_rsa*
    /usr/bin/expect > /dev/null 2>&1 <<-EOF
        set timeout 5
        spawn ssh-keygen -t rsa -b 2048 -N "" -f /root/.ssh/id_rsa
        expect {
            "overwrite" { send "y\r"; exp_continue }
            eof
        }
EOF
    echo -e "\e[32m>>> SSH 密钥生成完成 <<<\e[0m"
}

# 5. 密钥分发函数
ssh_copy_id() {
    local pub_key="/root/.ssh/id_rsa.pub"
    if [ ! -f "$pub_key" ]; then
        echo -e "\e[31m未找到公钥文件，请检查密钥生成环节。\e[0m"
        return
    fi

    for i in ${HOSTS[@]}; do
        ping -c 1 -W 2 $i &> /dev/null
        if [ $? -ne 0 ]; then 
            echo -e "\e[31m!!! $i 主机无法 PING 通，跳过认证 !!!\e[0m"
            continue
        fi

        echo "正在为 $i 部署免密认证..."
        /usr/bin/expect > /dev/null 2>&1 <<-EOF
            set timeout 10
            spawn ssh-copy-id -o StrictHostKeyChecking=no root@$i
            expect {
                "password:" {
                    send "$PASSWD\r"
                    expect {
                        "Permission denied" {
                            send "$EULERPASSWD\r"
                            expect {
                                "Permission denied" { exit 1 }
                                eof
                            }
                        }
                        eof
                    }
                }
                "Already installed" { puts "已存在，跳过"; eof }
                eof
            }
EOF
        if [ $? -eq 0 ]; then
            echo -e "\e[32m$i 认证分发指令已发送\e[0m"
        else
            echo -e "\e[31m$i 认证失败（双密码均错误或连接被拒）\e[0m"
        fi
    done
}

# 6. 私钥状态检查
key_exist() {
    if [ -f ~/.ssh/id_rsa ]; then
        read -r -t 10 -p "检测到已存在私钥，是否覆盖重新生成？(y/n): " choice
        if [ $? -ne 0 ] || [[ "$choice" =~ ^[Nn] ]]; then
            echo -e "\e[32m>>> 使用现有私钥继续 <<<\e[0m"
        else
            new_keygen
        fi
    else
        new_keygen
    fi
}

# 7. 最终连接验证
check() {
    echo -e "\n\e[1;34m--- 开始最终连接验证 ---\e[0m"
    for i in ${HOSTS[@]}; do
        # 使用 SSH 非交互式命令测试
        result=$(ssh -o BatchMode=yes -o ConnectTimeout=3 root@$i "echo 'success'" 2>/dev/null)
        if [ "$result" == "success" ]; then
            echo -e "$i \e[32m[ 认证成功 ✔ ]\e[0m"
        else
            echo -e "$i \e[31m[ 认证失败 ✘ ]\e[0m"
        fi
    done
}

# --- 脚本执行流程 ---
install_tools
collect_ips
if [ ${#HOSTS[@]} -eq 0 ]; then
    echo "未发现有效 IP 地址，脚本退出。"
    exit 1
fi
collect_passwd
key_exist
ssh_copy_id
check