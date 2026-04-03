#!/bin/bash
# 自动部署 Tailscale（增强认证版）
# 整合了多主机免密认证脚本（原作者：lizhiquan）

# 全局变量初始化
HOSTS=()
PUB_KEY_PATH=""
REMOTE_USER="root"

echo -e "\e[1;32m支持多主机并行验证，每台主机配置独立密码\e[0m\n"

# ------------------------------------------------------------
# 1. 工具安装函数（修正包名）
install_tools() {
    while true; do
        if type expect > /dev/null 2>&1 && type ping > /dev/null 2>&1; then
            break
        fi

        read -t 10 -p "需安装 expect/ping 命令，是否继续(y/n)? " CH
        RET=$?
        if [ $RET -ne 0 ]; then
            echo -e "\e[31m\n--输入超时或异常，自动退出--\e[0m"
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
                    apt update &> /dev/null
                    apt install iputils-ping expect -y &> /dev/null
                elif command -v yum > /dev/null 2>&1; then
                    yum install -y iputils expect &> /dev/null      # 修正包名
                elif command -v dnf > /dev/null 2>&1; then
                    dnf install -y iputils expect &> /dev/null      # 修正包名
                else
                    echo -e "\e[31m!!!未找到兼容的包管理器 (apt/yum/dnf)!!!\e[0m"
                    exit 1
                fi
                echo -e "\e[32m---依赖安装完成---\e[0m"
                ;;
            *) echo -e "\e[31m!!!无效输入，请输入 y 或 n!!!\e[0m" ;;
        esac
    done
}

# 2. 密码收集函数
collect_passwd() {
    echo -e "\n\e[33m请输入登录密码（支持备选密码）：\e[0m"
    read -e -s -p "首选密码：" PASSWD
    echo ""
    read -e -s -p "备用密码：" EULERPASSWD
    echo ""
    if [ -z "$PASSWD" ]; then
        echo -e "\e[31m警告：首选密码为空，可能导致认证失败\e[0m"
    fi
}

# 3. IP 收集函数（自动补全前缀，非空校验）
collect_ips() {
    PREFIX_REGEX='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}$'
    IP_REGEX='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])$'
    
    read -e -p "输入网络前缀（例如 10.0.0. 或 192.168.1）： " prefix
    if [[ ! $prefix =~ \.$ ]]; then
        prefix="${prefix}."
    fi

    while [[ ! $prefix =~ $PREFIX_REGEX ]]; do
        echo -e "\e[31m格式错误：前缀必须是 x.x.x. 格式\e[0m"
        read -e -p "请重新输入前缀： " prefix
        if [[ ! $prefix =~ \.$ ]]; then
            prefix="${prefix}."
        fi
    done
    
    echo -e "\n输入待处理 IP（数字或完整 IP，空格分隔）："
    while true; do
        read -e -p "> " ip_input
        if [ -z "$ip_input" ]; then
            echo -e "\e[31m输入不能为空，请重新输入 IP 列表\e[0m"
            continue
        fi
        break
    done

    for x in $ip_input; do
        if [[ $x =~ $IP_REGEX ]]; then
            HOSTS+=("$x")
        elif [[ $x =~ ^[0-9]+$ ]]; then
            full_ip="${prefix}${x}"
            if [[ $full_ip =~ $IP_REGEX ]]; then
                HOSTS+=("$full_ip")
            else
                echo -e "\e[33m警告：生成的 IP $full_ip 格式无效，已跳过\e[0m"
            fi
        else
            echo -e "\e[33m警告：无法识别的输入 $x，已跳过\e[0m"
        fi
    done
    
    if [ ${#HOSTS[@]} -eq 0 ]; then
        echo -e "\e[31m未收集到任何有效的 IP 地址\e[0m"
        exit 1
    fi
}

# 4. 密钥生成函数
new_keygen() {
    if [ ! -d ~/.ssh ]; then
        mkdir -p ~/.ssh
    fi
    chmod 700 ~/.ssh
    
    rm -f ~/.ssh/id_rsa*
    echo "正在生成新的 RSA 密钥 (2048位, 无密码)..."
    ssh-keygen -q -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa
    if [ $? -eq 0 ]; then
        echo -e "\e[32m密钥生成成功\e[0m"
    else
        echo -e "\e[31m密钥生成失败\e[0m"
        exit 1
    fi
}

# 5. 密钥状态检查（全局变量 PUB_KEY_PATH）
key_exist() {
    local existing_pub=$(ls $HOME/.ssh/*.pub 2>/dev/null | head -n 1)
    
    if [ -n "$existing_pub" ]; then
        echo -e "\e[33m检测到已有公钥: $existing_pub\e[0m"
        read -r -t 10 -p "是否覆盖重新生成？(y/n): " choice
        RET=$?
        if [ $RET -ne 0 ] || [[ "$choice" =~ ^[Nn] ]]; then
            PUB_KEY_PATH="$existing_pub"
            echo "使用现有公钥: $PUB_KEY_PATH"
        else
            new_keygen
            PUB_KEY_PATH="$HOME/.ssh/id_rsa.pub"
        fi
    else
        new_keygen
        PUB_KEY_PATH="$HOME/.ssh/id_rsa.pub"
    fi
}

# 6. 密钥分发函数（使用 ssh-copy-id，支持双密码）
ssh_copy_id() {
    if [ -z "$PUB_KEY_PATH" ] || [ ! -f "$PUB_KEY_PATH" ]; then
        echo -e "\e[31m未找到公钥文件: ${PUB_KEY_PATH:-空路径}\e[0m"
        return
    fi

    read -e -p "请输入远程登录用户名 (默认 root): " INPUT_USER
    if [ -n "$INPUT_USER" ]; then
        REMOTE_USER="$INPUT_USER"
    fi
    echo -e "\e[32m将使用用户: $REMOTE_USER 进行部署\e[0m\n"

    for i in "${HOSTS[@]}"; do
        ping -c 1 -W 2 "$i" &> /dev/null
        if [ $? -ne 0 ]; then 
            echo -e "\e[31m!!! $i 无法 PING 通，跳过 !!!\e[0m"
            continue
        fi

        echo "正在为 $i ($REMOTE_USER) 部署免密认证..."
        
        /usr/bin/expect <<-EOF
            set timeout 15
            spawn ssh-copy-id -o StrictHostKeyChecking=no -o PubkeyAuthentication=yes -i $PUB_KEY_PATH $REMOTE_USER@$i
            
            expect {
                "yes/no" {
                    send "yes\r"
                    expect "password:" { send "$PASSWD\r" }
                }
                "password:" {
                    send "$PASSWD\r"
                }
                "Already installed" {
                    puts "\n\e[32m[i] 密钥已存在\e[0m"
                    exit 0
                }
                "Permission denied" {
                    puts "\n\e[33m[i] 首选密码错误，尝试备用密码...\e[0m"
                    expect "password:" {
                        send "$EULERPASSWD\r"
                        expect {
                            "Permission denied" { 
                                puts "\e[31m[i] 两种密码均验证失败\e[0m"
                                exit 1 
                            }
                            eof { 
                                puts "\e[32m[i] 备用密码验证成功\e[0m"
                                exit 0 
                            }
                            timeout {
                                puts "\e[31m[i] 等待备用密码响应超时\e[0m"
                                exit 1
                            }
                        }
                    }
                }
                eof {
                    exit 0
                }
                timeout {
                    puts "\e[31m[i] 连接超时\e[0m"
                    exit 1
                }
            }
            
            expect {
                eof { exit 0 }
                timeout { exit 1 }
            }
EOF
        if [ $? -eq 0 ]; then
            echo -e "\e[32m>>> $i 认证完成\e[0m"
        else
            echo -e "\e[31m>>> $i 认证失败\e[0m"
        fi
        sleep 0.5
    done
}

# 7. 最终连接验证
check() {
    echo -e "\n\e[1;34m--- 开始最终连接验证 ---\e[0m"
    for i in "${HOSTS[@]}"; do
        ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$REMOTE_USER@$i" "echo success" &>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "$i \e[32m[ 成功 ✔ ]\e[0m"
        else
            echo -e "$i \e[31m[ 失败 ✘ ]\e[0m"
        fi
    done
}

# ------------------------------------------------------------
# 部署 Tailscale（使用认证后的用户）
Tailscale() {
    echo -e "\n需配置 IP: ${HOSTS[@]}\n"
    echo "请输入 authkey (tskey-auth-xxxxxxxxxxxx)"
    read -p "> " authkey
    for host in "${HOSTS[@]}"; do
        echo -e "\n配置 $host ...\n"
        if ssh "$REMOTE_USER@$host" "curl -fsSL https://tailscale.com/install.sh | sh" && \
           ssh "$REMOTE_USER@$host" "sudo tailscale up --authkey=$authkey"; then
            echo -e "\e[32msuccess\e[0m"
        else
            echo -e "\e[31mfailed\e[0m"
        fi
    done
}

# ------------------------------------------------------------
# 主菜单：集群免密认证状态选择
while true; do
    echo -e "需先进行集群免密认证
[1] 已认证完毕
[2] 进行认证
[x] 退出\n"

    read -t 10 -n 1 -s -p "请输入你的选择" A 
    if [ $? != 0 ]; then
        echo "超时未选择，自动退出"
        exit
    fi
    echo -e "\n你的选择[$A]\n"

    case $A in
        1)
            collect_ips
            Tailscale
            break
            ;;
        2)
            echo "免密认证中"
            install_tools
            collect_ips
            collect_passwd
            key_exist
            ssh_copy_id
            check
            Tailscale
            exit
            ;;
        x)
            echo "退出"
            exit
            ;;
        *)
            echo "无效输入"
            ;;
    esac
done