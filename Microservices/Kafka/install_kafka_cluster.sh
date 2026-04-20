#!/bin/bash
#
#********************************************************************
#Author:            lizhiquan
#QQ:                412001070
#Date:              2020-06-03
#FileName:          install_kafka.sh  
#URL:               https://gitee.com/zqli6/
#Description:       The test script
#Copyright (C):     2020 All rights reserved
#********************************************************************

#支持在线和离线安装安装

NODE1=10.0.0.201
NODE2=10.0.0.202
NODE3=10.0.0.203

KAFKA_VERSION=3.9.2
#KAFKA_VERSION=3.9.0
#KAFKA_VERSION=3.8.0
#KAFKA_VERSION=3.7.0
#KAFKA_VERSION=3.6.1
#KAFKA_VERSION=3.5.1
#KAFKA_VERSION=3.5.0
#KAFKA_VERSION=3.4.0
#KAFKA_VERSION=3.3.2
#KAFKA_VERSION=3.2.0
#KAFKA_VERSION=-3.0.0

SCALA_VERSION=2.13

KAFKA_URL="https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
#KAFKA_URL="https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/2.8.1/kafka_2.13-2.8.1.tgz"
#KAFKA_URL="https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/2.7.1/kafka_2.13-2.7.1.tgz"


KAFKA_INSTALL_DIR=/usr/local/kafka


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

env () {
    if hostname -I |grep -q $NODE1;then
	    ID=1
	   hostnamectl set-hostname node1
	elif hostname -I |grep -q $NODE2;then
	    ID=2
	   hostnamectl set-hostname node2
	elif hostname -I |grep -q $NODE3;then
	    ID=3
	    hostnamectl set-hostname node3
    else
	    color 'IP地址错误' 1
	    exit
	fi
    cat >> /etc/hosts <<EOF
	
$NODE1   node1
$NODE2   node2
$NODE3   node3

EOF
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
	mv ${KAFKA_INSTALL_DIR}/config/zookeeper.properties{,.bak}
    cat > ${KAFKA_INSTALL_DIR}/config/zookeeper.properties <<EOF
tickTime=2000
initLimit=10
syncLimit=5
dataDir=${KAFKA_INSTALL_DIR}/data
clientPort=2181
maxClientCnxns=128
autopurge.snapRetainCount=3
autopurge.purgeInterval=24
server.1=${NODE1}:2888:3888
server.2=${NODE2}:2888:3888
server.3=${NODE3}:2888:3888
EOF
    mkdir -p ${KAFKA_INSTALL_DIR}/data
	
    echo $ID > ${KAFKA_INSTALL_DIR}/data/myid

    cat > ${KAFKA_INSTALL_DIR}/bin/zookeeper-startup.sh <<EOF
#!/bin/bash
nohup ${KAFKA_INSTALL_DIR}/bin/zookeeper-server-start.sh ${KAFKA_INSTALL_DIR}/config/zookeeper.properties   &
EOF
    chmod +x ${KAFKA_INSTALL_DIR}/bin/zookeeper-startup.sh
    cat > /lib/systemd/system/zookeeper.service <<EOF
[Unit]
Description=zookeeper.service
After=network.target

[Service]
Type=forking
ExecStart=${KAFKA_INSTALL_DIR}/bin/zookeeper-startup.sh
ExecStop=${KAFKA_INSTALL_DIR}/bin/zookeeper-server-stop.sh 

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
   

install_kafka(){
    if [ ! -f kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ];then
        wget -P /usr/local/src/  --no-check-certificate $KAFKA_URL  || { color  "下载失败!" 1 ;exit ; }
    fi
    tar xf /usr/local/src/${KAFKA_URL##*/}  -C /usr/local/
    ln -s /usr/local/kafka_${SCALA_VERSION}-${KAFKA_VERSION}  ${KAFKA_INSTALL_DIR}
    install_zookeeper
	
    echo PATH=${KAFKA_INSTALL_DIR}/bin:'$PATH' >> /etc/profile
	
    mv ${KAFKA_INSTALL_DIR}/config/server.properties{,.bak}
    cat > ${KAFKA_INSTALL_DIR}/config/server.properties <<EOF
broker.id=$ID
listeners=PLAINTEXT://${HOST}:9092
log.dirs=${KAFKA_INSTALL_DIR}/data
num.partitions=1
log.retention.hours=168
zookeeper.connect=${NODE1}:2181,${NODE2}:2181,${NODE3}:2181
zookeeper.connection.timeout.ms=6000
delete.topic.enable=true
EOF
    	
    cat > ${KAFKA_INSTALL_DIR}/bin/kafka-startup.sh <<EOF
#!/bin/bash
nohup ${KAFKA_INSTALL_DIR}/bin/kafka-server-start.sh  ${KAFKA_INSTALL_DIR}/config/server.properties &
EOF
    chmod +x ${KAFKA_INSTALL_DIR}/bin/kafka-startup.sh
	
    cat > /lib/systemd/system/kafka.service <<EOF
[Unit]                                                                          
Description=Apache kafka
After=network.target

[Service]
Type=forking
ExecStart=${KAFKA_INSTALL_DIR}/bin/kafka-startup.sh
ExecStop=/bin/kill  -TERM \${MAINPID}
Restart=always
RestartSec=20

[Install]
WantedBy=multi-user.target

EOF
    systemctl daemon-reload
    systemctl enable --now kafka.service
    #kafka-server-start.sh -daemon ${KAFKA_INSTALL_DIR}/config/server.properties 
    systemctl is-active kafka.service
    if [ $? -eq 0 ] ;then 
        color "kafka 安装成功!" 0  
    else 
        color "kafka 安装失败!" 1
        exit 1
    fi    
}


env

install_jdk

install_kafka
