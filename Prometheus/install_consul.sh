#!/bin/bash
#FileName: install_consul.sh

CONSUL_VERSION=1.13.3
# CONSUL_VERSION=1.10.2
CONSUL_FILE=consul_${CONSUL_VERSION}_linux_amd64.zip
CONSUL_URL=https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${CONSUL_FILE}
CONSUL_DATA=/data/consul
LOCAL_IP=`hostname -I|awk '{print $1}'`

msg_error() {
    echo -e "\033[1;31m$1\033[0m"
}

msg_info() {
    echo -e "\033[1;32m$1\033[0m"
}

msg_warn() {
    echo -e "\033[1;33m$1\033[0m"
}

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
        echo -n $" OK "    
    elif [ $2 = "failure" -o $2 = "1" ] ;then 
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

install_consul () {
    if [ ! -f ${CONSUL_FILE} ] ;then
        wget -P /usr/local/src ${CONSUL_URL} || { color "下载失败!" 1 ; exit ; }
    fi
    unzip /usr/local/src/${CONSUL_FILE} -d /usr/local/bin/
    
    /usr/local/bin/consul -autocomplete-install
    useradd -s /sbin/nologin consul
    mkdir -p ${CONSUL_DATA} /etc/consul.d
    chown -R consul.consul ${CONSUL_DATA} /etc/consul.d
}

service_consul () {
cat <<EOF > /lib/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -server -ui -bootstrap-expect=1 -data-dir=${CONSUL_DATA} -node=consul -client=0.0.0.0 -config-dir=/etc/consul.d
# ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now consul.service
}

start_consul() { 
    systemctl is-active consul
    if [ $? -eq 0 ];then  
        echo
        color "Consul 安装完成!" 0
        echo "-------------------------------------------------------------------"
        echo -e "访问链接: \c"
        msg_info "http://${LOCAL_IP}:8500/"
    else
        color "Consul 安装失败!" 1
        exit
    fi
}

install_consul
service_consul
start_consul
