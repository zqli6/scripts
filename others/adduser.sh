#!/bin/bash
#功能：批量增加用户 

echo -e "\e[1;32m请输入用户创建数量\e[0m"
read -e num
while true;do
echo -e "\e[1;32m请选择用户类型
[1] 系统用户
[2] 普通用户\e[0m"
read -n 1 -s choice
echo -e "\e[32m选择[$choice]\e[0m"

case "$choice" in
    1|2)
       echo -e "创建时间：$(date +%F/%T)" >> ~/userpasswd.txt
     #此处也可以使用while循环
    for i in $(seq 1 $num);do
        if [ $choice = 1 ];then
           sys="-r"
        else 
           sys=""
        fi
        echo "正在创建user$i"
        useradd $sys -m user$i
        passwd=$(tr -dc "0-9a-zA-z@#$%^&*()_+=" < /dev/urandom | head -c 10)
        echo "user$i:$passwd" | chpasswd
        echo -e "用户名：user$i  密 码：$passwd" >> ~/userpasswd.txt
    done
        echo "用户密码存放在家目录userpasswd.txt中"
      break
    ;;
     *)
      echo -e "\e[1;31m输入有误请重新输入\[0m"
    ;;
esac
done
