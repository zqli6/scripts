#!/bin/bash
# *************************************
# * 功能: 部署openvpn服务端 
# * 版本: 2025-12-20
# *************************************
# 配置参数（可根据实际情况修改）
OPENVPN_DIR="/etc/openvpn"
EASY_RSA_DIR="/usr/share/easy-rsa"
CA_DIR="${OPENVPN_DIR}/server"
CLIENT_DIR="${OPENVPN_DIR}/client/test"
OPENVPN_EIP="121.89.82.7"
OPENVPN_PORT="1194"
VPN_SUBNET="10.8.0.0 255.255.255.0"
PUSH_ROUTE="172.30.0.0 255.255.255.0"

# 1. 基础环境配置
echo "=== 1. 基础环境配置 ==="
# 更新软件源
apt update -y  >>/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt install -y openvpn easy-rsa  >>/dev/null 2>&1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p  >>/dev/null 2>&1
iptables -t nat -A POSTROUTING -s ${VPN_SUBNET% *}/24 -o eth0 -j MASQUERADE

# 2. 初始化证书目录
echo "=== 2. 初始化证书目录 ==="
# 创建目录
mkdir -p ${CA_DIR} ${CLIENT_DIR}
chmod 700 ${CA_DIR} ${CLIENT_DIR}
# 复制 easy-rsa 配置
cp -r ${EASY_RSA_DIR}/* ${CA_DIR}/
cd ${CA_DIR}
# 初始化 PKI
echo "yes" | ./easyrsa init-pki  >>/dev/null 2>&1
echo "yes" | ./easyrsa build-ca nopass  >>/dev/null 2>&1
echo "yes" | ./easyrsa build-server-full server nopass  >>/dev/null 2>&1
./easyrsa gen-dh  >>/dev/null 2>&1
echo "yes" | ./easyrsa build-client-full test nopass  >>/dev/null 2>&1
# 复制证书到指定目录
cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem ${CA_DIR}/

# 3. 配置 OpenVPN 服务端（使用 PAM 认证）
echo "=== 3. 配置 OpenVPN 服务端 ==="
# 编写 server.conf
cat > ${OPENVPN_DIR}/server.conf << EOF
port ${OPENVPN_PORT}
proto tcp
dev tun
ca ${CA_DIR}/ca.crt
cert ${CA_DIR}/server.crt
key ${CA_DIR}/server.key
dh ${CA_DIR}/dh.pem
server ${VPN_SUBNET}
push "route ${PUSH_ROUTE}"
keepalive 10 120
cipher AES-256-CBC
compress lz4-v2
push "compress lz4-v2"
max-clients 2048
user root
group root
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
mute 20
EOF

# 4. 生成客户端配置文件
echo "=== 4. 生成客户端配置文件 ==="
# 复制客户端证书
cp ${CA_DIR}/pki/ca.crt ${CLIENT_DIR}/
cp ${CA_DIR}/pki/issued/test.crt ${CLIENT_DIR}/
cp ${CA_DIR}/pki/private/test.key ${CLIENT_DIR}/
# 编写客户端 ovpn 文件
cat > ${CLIENT_DIR}/test.ovpn << EOF
client
dev tun
proto tcp
remote ${OPENVPN_EIP} ${OPENVPN_PORT}
resolv-retry infinite
nobind
ca ca.crt
cert test.crt
key test.key
remote-cert-tls server
cipher AES-256-CBC
verb 3
compress lz4-v2
# auth-user-pass
EOF

# 5. 配置服务并启动
echo "=== 5. 配置服务并启动 ==="
# 创建日志目录
mkdir -p /var/log/openvpn
# 重启服务（先停止失败的服务）
systemctl stop openvpn@server || true  >>/dev/null 2>&1
systemctl daemon-reload  >>/dev/null 2>&1
systemctl enable --now openvpn@server  >>/dev/null 2>&1
# 检查服务状态
if systemctl is-active --quiet openvpn@server; then
    echo "OpenVPN 服务启动成功！"
else
    echo "OpenVPN 服务启动失败，请检查日志！"
    journalctl -xeu openvpn@server.service
    exit 1
fi

# 6. 输出部署信息
echo "=== 6. 部署完成，关键信息 ==="
echo "OpenVPN 服务端配置文件：${OPENVPN_DIR}/server.conf"
echo "客户端配置文件目录：${CLIENT_DIR}"
echo "客户端 ovpn 文件：${CLIENT_DIR}/test.ovpn"
echo "=== OpenVPN 部署完成！ ==="
