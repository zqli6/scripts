#!/bin/bash
#
#********************************************************************
#Author:            zqli
#QQ:                412001070
#Date:              2026-01-15
#FileName:          wechat_and_dingding_API.sh
#URL:               
#Description:       The test script
#Copyright (C):     2026 All rights reserved
#********************************************************************
#!/bin/bash
#功能；put message
#适用：wechatapp API，wechat webhook

message_content() {
echo -e "\e[1;33m‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣\e[0m
\e[1;33m•\e[0m\e[1;34m   请输入推送消息内容   \e[0m\e[1;33m•\e[0m
\e[1;33m•\e[0m\e[1;34m按'Enter'换行可删减编辑 \e[0m\e[1;33m•\e[0m
\e[1;33m•\e[0m\e[1;34m       按'空行'发送     \e[0m\e[1;33m•\e[0m
\e[1;33m‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣\e[0m
\e[1;36m内容：\e[0m"
   content=""
   while true;do
      read -er line
      [ -z "$line" ] && break #空行结束输入
      content="$content$line"$'\n'
   done
}


#调API推送消息
wechat_API_message() {
#获取access_token
echo -e "\e[1;32m请输入企业ID(corpid)\e[0m"
read corpid
echo -e "\e[1;32m请输入微信应用Secret(corpsecret)\e[0m"
read corpsecret
echo -e "\e[1;32m请输入微信应用ID(agentid)\e[0m"
read agentid
echo -e "\e[1;32m请输入微信消息推送对象账号\e[0m"
read touser
echo -e "\e[1;32m请输入微信消息推送对象部门账号\e[0m"
read toparty
echo -e "\e[1;32m请输入微信消息推送对象标签\e[0m"
read totag

#echo -e "\e[1;33m‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣\e[0m
#\e[1;33m•\e[0m\e[1;34m   请输入推送消息内容   \e[0m\e[1;33m•\e[0m
#\e[1;33m•\e[0m\e[1;34m   按'\'和'Enter'换行   \e[0m\e[1;33m•\e[0m
#\e[1;33m•\e[0m\e[1;34m      按'Enter'发送     \e[0m\e[1;33m•\e[0m
#\e[1;33m‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣\e[0m
#\e[1;36m内容：\e[0m"
#read content

message_content



local TKURL="https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=$corpid&corpsecret=$corpsecret"
#access_token=curl -X GET "$TKURL" | cut -d '"' -f10
local access_token=$(curl -s -X GET "$TKURL" | awk -F '"' '{print $10}')

if [ -z "$access_token" ];then
   echo -e "\e[1;31m获取access_token失败\e[0m"
   return 1
fi

local data='{
    "touser": "'"$touser"'",
    "toparty": "'"$toparty"'",
    "totag": "'"$totag"'",
    "msgtype": "'"text"'",
    "agentid": '"$agentid"',
    "text": {
        "content": "'"$content"'"
    },
    "safe": 0,
    "enable_id_trans": 0,
    "enable_duplicate_check": 0,
    "duplicate_check_interval": 1800
   }'

response=$(curl -s -X POST "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$access_token" -H "Content-Type: application/json" -d "$data")

echo $response
if echo "$response" | grep -q '"errcode":0';then
   echo -e "\n\n\e[1;32m╰(*°▽°*)╯  信息推送成功\e[0m"
else
   echo -e "\n\n\e[1;31mಠ_ಠ信息推送失败ಠ_ಠ\e[0m"
fi
}


wechat_webhook() {
   while true;do
   echo -e "\e[1;32m请输入微信群聊机器人webhook\e[0m"
   read wechat_webhook
      if [[ -z "$wechat_webhook" || ${#wechat_webhook} -ne 89 ]];then
         echo -e "\e[1;31m!无效输入，请重新输入!\e[0m\n"
         continue
      else
         break
      fi
   done
    
echo -e "\e[1;33m‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣\e[0m
\e[1;33m•\e[0m\e[1;34m   请输入推送消息内容   \e[0m\e[1;33m•\e[0m
\e[1;33m•\e[0m\e[1;34m  按'Enter'换行不可删减 \e[0m\e[1;33m•\e[0m
\e[1;33m•\e[0m\e[1;34m     按'Ctrl+2'发送     \e[0m\e[1;33m•\e[0m
\e[1;33m‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣‣\e[0m
\e[1;36m内容：\e[0m"
read -r -d '' wechat_webhook_content

   data='{
         "msgtype": "text",
         "text": {
         "content": "'"$wechat_webhook_content"'"
         }
    }'

   local response=$(curl -s "$wechat_webhook" -H 'Content-Type: application/json' -d "$data")
   echo $response
   if echo "$response" | grep -q '"errcode":0';then
      echo -e "\n\n\e[1;32m╰(*°▽°*)╯  信息推送成功\e[0m"
   else
      echo -e "\n\n\e[1;31mಠ_ಠ信息推送失败ಠ_ಠ\e[0m"
   fi
}



#选择功能
while true; do
echo -e "\033[1;33m ------------------------\033[0m
\033[1;33m¦\033[0m\033[1;36m    请选择使用的功能    \033[0m\033[1;33m¦\033[0m
\033[1;33m ------------------------\033[0m\033[1;32m
[1] 微信应用推送消息
[2] 微信群聊机器人推送消息
[3] 钉钉群聊机器人推送消息
[x] 退出\033[0m
\033[1;33m--------------------------\033[0m"

read -n 1 -t 10 -s choice

  if [ $? -ne 0 ]; then
    echo -e "\e[1;31m\n!!!超时未输入，自动退出!!!\e[0m"
    exit 1
  fi

echo -e "\033[1;36m选择：\033[0m\033[32m[$choice]\033[0m\n"
case "$choice" in
      x)
        echo -e "\e[1;35m退出\e[0m"
        exit 0
        ;;
      1)
        echo -e "\e[1;35m>>>调用微信API推送消息<<<\e[0m\n"
        wechat_API_message
        break
        ;;
      2)
        echo -e "\e[1;35m>>>调用微信群机器人webhook推送消息<<<\e[0m\n"
        wechat_webhook
        break
        ;;
      3)
        echo -e "\e[1;35m<><>功能正在完善中，敬请期待<><>\e[0m"
        while true;do
        echo -e "\e[33m重新选择功能或退出\e[0m\n\e[34m[1] 重新选择\n[2] 退出\e[0m"
        read -n 1 -s C
        echo -e "\033[1;35m选择：\033[0m\033[32m[$C]\033[0m"
          if [ $C = 2 ];then
             echo -e "\e[1;35m\n~~退出~~\e[0m"
             break 2
          elif [ $C = 1 ];then
             break
          else
             echo -e "\e[1;35m\n!无效输入,请选择[1]或[2]!\e[0m\n"
          fi
          done
        ;;
      *)
        echo -e "\e[1;31m!无效输入，请重新输入!\e[0m\n"
        ;;
esac
done
