#!/bin/bash
#
#********************************************************************
#Author:            lizhiquan
#QQ:                412001070
#Date:              2020-06-20
#FileName:          install_zookeeper.sh
#URL:               http://www.lizhiquan.com
#Description:       The test script
#Copyright (C):     2022 All rights reserved
#********************************************************************

#支持在线和离线安装

ZK_VERSION=3.9.5
#ZK_VERSION=3.9.4
#ZK_VERSION=3.9.3
#ZK_VERSION=3.9.2
#ZK_VERSION=3.9.1
#ZK_VERSION=3.9.0
#ZK_VERSION=3.8.1
#ZK_VERSION=3.8.0
#ZK_VERSION=3.6.3
#ZK_VERSION=3.7.1
#ZK_URL=https://archive.apache.org/dist/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz
ZK_URL=https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz
#ZK_URL="https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/stable/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"
#ZK_URL="https://downloads.apache.org/zookeeper/stable/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"

INSTALL_DIR=/usr/local/zookeeper


HOST=`hostname -I|awk '{print $1}'`

.  /etc/os-release

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

install_jdk() {
    java -version &>/dev/null && { color "JDK 已安装!" 1 ; return;  }
    if command -v yum &>/dev/null ; then
        yum -y install java-1.8.0-openjdk-devel || { color "安装JDK失败!" 1; exit 1; }
    elif command -v apt &>/dev/null ; then
        apt update
        #apt install openjdk-11-jdk -y || { color "安装JDK失败!" 1; exit 1; } 
        #apt install openjdk-8-jdk -y || { color "安装JDK失败!" 1; exit 1; } 
        apt install openjdk-21-jdk -y || { color "安装JDK失败!" 1; exit 1; } 
    else
       color "不支持当前操作系统!" 1
       exit 1
    fi
    java -version && { color "安装 JDK 完成!" 0 ; } || { color "安装JDK失败!" 1; exit 1; } 
}


install_zookeeper() {
    if [ -f apache-zookeeper-${ZK_VERSION}-bin.tar.gz ] ;then
        cp apache-zookeeper-${ZK_VERSION}-bin.tar.gz /usr/local/src/
    else
        wget -P /usr/local/src/ --no-check-certificate $ZK_URL || { color  "下载失败!" 1 ;exit ; }
    fi
    tar xf /usr/local/src/${ZK_URL##*/} -C /usr/local
    ln -s /usr/local/apache-zookeeper-*-bin/ ${INSTALL_DIR}
   #echo "PATH=${INSTALL_DIR}/bin:$PATH" >  /etc/profile.d/zookeeper.sh
    echo "PATH=${INSTALL_DIR}/bin:$PATH" >>  /etc/profile
    #.  /etc/profile.d/zookeeper.sh
    mkdir -p ${INSTALL_DIR}/data 
    cat > ${INSTALL_DIR}/conf/zoo.cfg <<EOF
tickTime=2000
initLimit=10
syncLimit=5
dataDir=${INSTALL_DIR}/data
dataLogDir=${INSTALL_DIR}/logs
clientPort=2181
maxClientCnxns=128
autopurge.snapRetainCount=3
autopurge.purgeInterval=24
EOF
	cat > /lib/systemd/system/zookeeper.service <<EOF
[Unit]
Description=zookeeper.service
After=network.target

[Service]
Type=forking
#Environment=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/bin/zkServer.sh start
ExecStop=${INSTALL_DIR}/bin/zkServer.sh stop
ExecReload=${INSTALL_DIR}/bin/zkServer.sh restart

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now  zookeeper.service
    systemctl is-active zookeeper.service
	if [ $? -eq 0 ] ;then 
        color "zookeeper 安装成功!" 0  
    else 
        color "zookeeper 安装失败!" 1
        exit 1
    fi   
}


install_jdk

install_zookeeper
