#!/bin/bash
# 自动部署Tialscale


#密码收集函数
collect_passwd() {
    echo "请输入密码支持两个密码，首位密码错误自动尝试第二位密码，若没有第二个密码可不输入"
    read -e -s -p "首密码：" PASSWD
    read -e -s -p "备密码：" EULERPASSWD
}

#ip收集函数
collect_ips() {
    # 定义ip格式及大小范围用于判断
    PREFIX_REGEX='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}$'
    IP_REGEX='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])$'
    # 读取前缀
    read -e -p "输入网络前缀（X.X.X.）： " prefix
    while [[ ! $prefix =~ $PREFIX_REGEX ]]; do
        read -e -p "格式错误，重新输入： " prefix
    done
    
    # 读取IP
    echo -e "\n输入IP（完整IP 或 最后一段数字，空格分隔）："
    read -e -p "> " ip_input
    
    # 处理输入的IP
    ips=()
    for x in $ip_input; do
        # 直接检查是否是完整IP
        if [[ $x =~ $IP_REGEX ]]; then
            HOSTS+=("$x")
        
        # 如果是纯数字，先拼接再验证
        elif [[ $x =~ ^[0-9]+$ ]]; then
            full_ip="${prefix}${x}"
            if [[ $full_ip =~ $IP_REGEX ]]; then
                HOSTS+=("$full_ip")
            else
                echo "跳过: $x (拼接后无效: $full_ip)"
            fi
        
        else
            echo "跳过: $x"
        fi
    done
    
    # 返回结果
    # echo "${HOSTS[@]}"
}

install_tools() {
while true;do
        #判断是否已安装expect
        if type expect > /dev/null 2>&1 && type ping > /dev/null 2>&1;then
                break
        fi
   read -n 3 -t 6 -p "需安装expectt/ping命令是否继续(y/n)" CH
       if [ $? -ne 0 ];then
          echo -e "\e[31m--输出超时，自动退出--\e[0m"
       fi
     case "$CH" in
                n|N|no|No|NO)
                        echo -e "\e[30;41m------退出------\e[0m"
                        exit 1
                        break
                        ;;
                y|Y|yes|Yes|YES)
                        echo -e "\e[32m---正在确定包管理器---\e[0m"
                        #判断系统安装expect
                        if command -v apt > /dev/null 2>&1; then
                             echo -e "\e[32m---正在安装缺失命令---\e[0m"
                             apt update 
                             if ! type ping > /dev/null 2>&1;then
                                     apt install iputils-ping -y
                             else apt install expect -y
                             fi
                        elif command -v yum > /dev/null 2>&1;then
                             echo -e "\e[32m---正在安装缺失命令---\e[0m"
                             yum update
                             if ! type ping > /dev/null 2>&1;then
                                     yum install iputils-ping -y
                             else yum install expect -y
                             fi
                        elif command -v dnf &> /dev/null;then
                             echo -e "\e[32m---正在安装缺失命令---\e[0m"
                             dnf update
                             if ! type ping > /dev/null 2>&1;then
                                     dnf install iputils-ping -y
                             else dnf install expect -y
                             fi
                        else
                             echo -e "\e[31m!!!未找到包管理器!!!\e[0m"
                             exit
                        fi
                        ;;
               *)
                        echo -e "\e[31m!!!无效输入，请重新输入!!!\e[0m"
                        ;;
     esac
done
}

new_keygen () {
        rm -rf ~/.ssh/*
/usr/bin/expect > /dev/null 2>&1  <<-EOF
#将expect的标准和错误输出导入/dev/null实现静默 就算是puts和send user也不输出
set timeout 5
#log_user 0  # 关闭 expect 的输出

#生成私钥
spawn ssh-keygen

expect {
  "save the key" { send "\r";exp_continue }
  "passphrase"   { send "\r";exp_continue }
  "again"        { send "\r" }
}
expect eof
EOF

echo -e "\e[32m>>>SSH密钥生成完成<<<\e[0m"
}

ssh_copy_id () {

local pub_keys=$(echo /root/.ssh/*.pub)
#在utunut和rocky中公钥名称不一致，expect中不能解析*.pub，使用局部变量方法定义
for i in ${HOSTS[@]};do
       ping $i -c1 &> /dev/null
       if [ $? -ne 0 ];then 
       echo -e "\e[31m!!!$i 主机无法连接!!!\e[0m"
       continue
       else
       echo "正在为 $i 免密认证"

/usr/bin/expect > /dev/null 2>&1 <<-EOF
set timeout 5
#将expect的标准和错误输出导入/dev/null实现静默
#log_user 0  # 关闭 expect 的输出

spawn bash -c "cat $pub_keys | ssh root@$i 'cat >> /root/.ssh/authorized_keys'"
#bash -c 在expect中执行shell命令
#使用前面定义的局部变量local $pub_keys传递.pub公钥
#ssh认证的本质是在远程主机的authorized_keys文件中增写本机的公钥
#不需要本机认证

expect {
  "yes/no" { send "yes\r";exp_continue }
  "password" {
       send "$PASSWD\r"
          expect {
            "please try again" {
                send "$EULERPASSWD\r"
                expect eof
             }
        }
    }
}
puts "$i ssh免密认证完成！"
expect eof
EOF
fi
done
}

#判断是否存在私钥
key_exist() {
if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
    while true; do
        read -r -t 10 -p "已存在私钥，是否重新生成？(y/n): " choice
        
        if [ $? -ne 0 ]; then
            echo -e "\n超时未输入，自动退出"
            exit 1
        fi
        
        # 使用正则表达式判断
        if [[ "$choice" =~ ^[Nn]([Oo])?$ ]]; then
            echo -e "\e[32m>>> 以原私钥进行免密认证 <<<\e[0m"
            break
        elif [[ "$choice" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "\e[32m>>> 重新生成私钥 <<<\e[0m"
            new_keygen
            break
        else
            echo "无效输入，请重新输入 y 或 n"
        fi
    done
else
    echo -e "\e[32m>>> 生成新私钥 <<<\e[0m"
    new_keygen
fi
}

#验证远程连接是否成功
check() {
for i in ${HOSTS[@]};do
ping $i -c1 &> /dev/null
       if [ $? -ne 0 ];then 
       continue
       else
/usr/bin/expect <<-EOF
        log_user 0
         # 关闭 expect 的输出，可以输出puts和send user也不输出
        spawn  ssh root@$i "echo test ssh"
        expect {
          "test ssh" {puts "$i 认证成功"}
          "password" {puts "$i 认证失败  ×"}
     }
expect eof
EOF
fi
done
}



#部署Tailscale
Tailscale() {
    echo -e "\n需配置IP: ${HOSTS[@]}\n"
    echo "请输入authkey(tskey-auth-xxxxxxxxxxxx)"
    read -p ">" authkey
    for host in "${HOSTS[@]}"; do
    echo -e "\n配置 $host...\n"
    
    # 分离安装和启动步骤，便于调试
    if ssh "$host" "curl -fsSL https://tailscale.com/install.sh | sh" && \
       ssh "$host" "sudo tailscale up --authkey=$authkey"; then
        echo -e "\e[32msuccess\e[0m"
    else
        echo -e "\e[31mfailed\e[0m"
    fi
done
}

#提示集群免密认证
while true;do
echo -e "需先进行集群免密认证
[1] 已认证完毕
[2] 进行认证
[x] 退出\n"

read -t 10 -n 1 -s -p "请输入你的选择" A 
if [ $? != 0 ];then
  echo "超时未选择，自动退出"
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
