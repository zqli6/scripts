#!/bin/bash
#
#********************************************************************
#Author:            wangxiaochun
#QQ:                29308620
#Date:              2020-03-01
#FileName:          set_http_proxy.sh
#URL:               http://www.wangxiaochun.com
#Description:       The test script
#Copyright (C):     2020 All rights reserved
#********************************************************************

PROXY_SERVER_IP=10.0.0.1
PROXY_PORT=10809
#PROXY_PORT=4780

color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "    
    elif [ $2 = "failure" -o $2 = "1"  ] ;then 
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo 
}

start () {
    export http_proxy="http://${PROXY_SERVER_IP}:${PROXY_PORT}/"
    export https_proxy="http://${PROXY_SERVER_IP}:${PROXY_PORT}/"
    export no_proxy="127.0.0.0/8,172.17.0.0/16,172.18.0.0/16,172.20.0.0/16,172.22.0.0/16,10.0.0.0/24,10.244.0.0/16,192.168.0.0/16,wang.org,cluster.local"
    if [ $? -eq 0 ] ;then 
        color "HTTP 代理配置完成!" 0  
    else
        color "HTTP 代理配置失败!" 1
    exit 1
    fi   
}

stop () {
    unset http_proxy https_proxy no_proxy
    if [ $? -eq 0 ] ;then
        color "HTTP 代理配置取消完成!" 0
    else
        color "HTTP 代理配置取消失败!" 1
    exit 1
    fi
}

usage () {
    echo "Usage: $(basename $0) start|stop"
    exit 1
}

case $1 in 
start)
    start
    exec bash
    ;;
stop)
    stop
    exec bash
    ;;
*)
    usage
    ;;
esac


