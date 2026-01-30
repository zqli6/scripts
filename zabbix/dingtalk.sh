#!/bin/bash
#
#********************************************************************
#Author:            wangxiaochun
#QQ:                29308620
#Date:              2022-11-01
#FileName:          dingtalk.sh
#URL:               http://www.wangxiaochun.com
#Description:       The test script
#Copyright (C):     2022 All rights reserved
#********************************************************************

#此脚本支持自定义关键词和加签和的消息发送
#需要指定三个参数:<收信人手机号> <主题> <消息内容>

#参考帮助：https://open.dingtalk.com/document/robots/customize-robot-security-settings

WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=08df38bfd74325d30554b33471743f0ccb6bbe853f996351bdfbde664ea4ea28"
#WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=9b31a61e017e6c30c2e875f192b32c76118482d80036a8f213c0b166e0855093"

YOUR_SECRET="SEC33f7b6b503bb2aa4b0a35ad9cb1ce00fffa43844dda2171e977de441e3936c36"
#YOUR_SECRET="SEC478dba31d8609ef07dc4e3f47c373210413524f7fb1787178267f8c794969546"



# 检查参数数量
if [ "$#" -ne 3 ]; then
  echo "使用方法: $0 <收信人手机号> <主题> <消息内容>"
  exit 1
fi

# 从参数中获取值,第1个参数收信人电话,第2个参数消息主题,第3个参数消息正文
receiver_phone="$1"
subject="$2"
message="$3"

# 配置DingTalk Webhook URL
webhook_url="https://oapi.dingtalk.com/robot/send?access_token=${YOUR_ACCESS_TOKEN}"

# 编码 URL
function url_encode() {
    t="${1}"
    if [[ -n "${1}" && -n "${2}" ]];then
       if ! echo 'xX' | grep -q "${t}";then
          t='x'
       fi
       echo -n "${2}" | od -t d1 | awk -v a="${t}" '{for (i = 2; i <= NF; i++) {printf(($i>=48 && $i<=57) || ($i>=65 &&$i<=90) || ($i>=97 && $i<=122) ||$i==45 || $i==46 || $i==95 || $i==126 ?"%c" : "%%%02"a, $i)}}'
   else
       echo -e '$1 and $2 can not empty\n$1 ==> 'x' or 'X', x ==> lower, X ==> toupper.\n$2 ==> Strings need to url encode'
   fi
}

function dingrobot(){
    # 生成时间戳和随机字符串
    timestamp=$(date +%s%3N)
    dingrobot_sign=$(echo -ne "${timestamp}\n${YOUR_SECRET}" | openssl dgst -sha256 -hmac "${YOUR_SECRET}" -binary | base64)
    dingrobot_sign=$(url_encode 'X' "${dingrobot_sign}")
    post_url="${WEBHOOK_URL}&timestamp=${timestamp}&sign=${dingrobot_sign}"

    # 构建JSON数据
    json_data="{
        \"msgtype\": \"text\",
        \"text\": {
             \"content\": \"$subject\n$message\"
        },
        \"at\": {
            \"atMobiles\": [\"$receiver_phone\"]
        }
    }"

    # 发送HTTP POST 请求至 DingTalk Webhook，包括签名信息
    curl -s -X POST -H "Content-Type: application/json"  -d "$json_data" "${post_url}"

    # 检查是否发送成功
    if [ $? -eq 0 ]; then
        echo "通知发送成功!"
    else
        echo "通知发送失败!"
    fi
}

dingrobot

