#!/bin/bash
#功能：多主机免密认证

PASSWD="123456"
EULERPASSWD="W!@#$%^w"
HOSTS=(10.0.0.1{2..8})


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
                             apt update &> /dev/null
                             if ! type ping > /dev/null 2>&1;then
                                     apt install iputils-ping -y &> /dev/null
                             else apt install expect -y &> /dev/null
                             fi
                        elif command -v yum > /dev/null 2>&1;then
                             echo -e "\e[32m---正在安装缺失命令---\e[0m"
                             yum update &> /dev/null
                             if ! type ping > /dev/null 2>&1;then
                                     yum install iputils-ping -y &> /dev/null
                             else yum install expect -y &> /dev/null
                             fi
                        elif command -v dnf &> /dev/null;then
                             echo -e "\e[32m---正在安装缺失命令---\e[0m"
                             dnf update &> /dev/null
                             if ! type ping > /dev/null 2>&1;then
                                     dnf install iputils-ping -y &> /dev/null
                             else dnf install expect -y &> /dev/null
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

#本地认证
#/usr/bin/expect > /dev/null 2>&1  <<-EOF
#set timeout 5
##log_user 0  # 关闭 expect 的输出
#spawn ssh-copy-id root@127.1
#expect {
#  "yes/no/" { send "yes\r";exp_continue }
#  "password" { send "$PASSWD\r" }
#}
#expect eof
#EOF                          没有必要本地认证

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

#传递公钥到远程主机
#spawn scp /root/.ssh/*b root@$i:/root/.ssh/
#expect {
#  "yes/no" { send "yes\r";exp_continue }
#  "password" { send "$PASSWD\r" }
#  "already exist" { send "\r" }
#}                                             #scp的方式并不科学和精准

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
if [ -f ~/.ssh/id_rsa -o -f ~/.ssh/id_ed25519 ]; then
        while true;do
        read -n 3 -t 10 -p "已存在私钥,是否重新生成(y/n)" choice
        
        # 检查是否超时（read命令返回非零状态码）
        if [ $? -ne 0 ]; then
        # $? 上一条命令的退出状态码
                echo -e "\n超时未输入，自动退出 "
                exit 1
        fi

          case "$choice" in
                n|N|no|No|NO)
                        echo -e "\e[32m>>>以原私钥进行免密认证<<<\e[0m"
                        ssh_copy_id
                        break
                        ;;
                y|Y|yes|Yes|YES)
                        echo -e "\e[32m>>>重新生成私钥<<<\e[0m"
                        new_keygen
                        ssh_copy_id
                        break
                        ;;
                *)
                        echo "无效输入，请重新输入"
                        ;;
          esac
       done
else
        new_keygen
        ssh_copy_id
fi

#验证远程连接是否成功
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
