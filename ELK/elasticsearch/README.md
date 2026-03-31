# elasticsearch安装
1. 链接   
    配置文档：<https://www.elastic.co/docs/deploy-manage/deploy/self-managed/configure-elasticsearch>  
    安装文档：<https://www.elastic.co/docs/deploy-manage/deploy/self-managed/installing-elasticsearch>  
    部署要求:  
    1. java版本  
    <https://www.elastic.co/support/matrix>  
    2. 系统要求
    <https://www.elastic.co/docs/deploy-manage/deploy/self-managed/important-system-configuration>  
    下载地址：<https://www.elastic.co/cn/downloads/elasticsearch>
2.配置参考  
```
[root@elasticsearch ]# grep -Ev '#|^$' /etc/elasticsearch/elasticsearch.yml 
# 集群名称：同一个集群内的所有节点必须配置相同的集群名
cluster.name: es-1
# 节点名称：当前节点的唯一标识，集群中每个节点名称必须不同
node.name: node-1
# 数据路径：索引数据存放的目录
path.data: /var/lib/elasticsearch
# 日志路径：日志文件存放的目录
path.logs: /var/log/elasticsearch
# 内存锁定：设为 true 防止系统交换内存，提升性能（生产环境推荐开启）
bootstrap.memory_lock: true
# 网络绑定：0.0.0.0 表示绑定所有网卡，允许外部访问
network.host: 0.0.0.0
# 发布主机：节点对外通告的 IP 地址（通常设为内网 IP）
network.publish_host: 10.0.0.102
# 发现种子主机：用于引导节点发现集群其他成员
# [单机] 可留空或注释；[集群] 必须填写其他主节点的主机名或 IP
discovery.seed_hosts: ["jenkins.lzq.org", "master1.lzq.org", "node1.lzq.org"]
# 初始主节点列表：仅用于集群首次启动选举主节点
# [单机] 填写当前节点名；[集群] 填写所有具备选举资格的主节点名称（集群启动成功后建议注释掉）
cluster.initial_master_nodes: ["jenkins.lzq.org", "master1.lzq.org", "node1.lzq.org"]
# HTTP 安全配置
xpack.security.http.ssl:
  enabled: true # 启用 HTTP 层 SSL 加密
  keystore.path: certs/http.p12 # 指定 HTTP 证书路径
# 传输安全配置（节点间通信）
xpack.security.transport.ssl:
  enabled: true # 启用节点间通信 SSL 加密
  verification_mode: certificate # 证书验证模式
  keystore.path: certs/transport.p12 # 指定传输层证书路径
  truststore.path: certs/transport.p12 # 指定信任库路径
# HTTP 接口绑定地址：0.0.0.0 允许通过任意 IP 访问 API
http.host: 0.0.0.0
# 基础安全功能：控制是否开启账号密码认证
# [单机/开发] 建议设为 false 方便调试；[生产/集群] 建议设为 true 开启认证
xpack.security.enabled: false
# 入职功能：允许生成令牌以便新节点或 Kibana 加入集群
xpack.security.enrollment.enabled: true
```

# elasticsearch的web查看插件  
1.  ElasticSearch-Head  
    1. 只能在chrome内核浏览器(goole和edge)使用   
    2. 获取：下载ElasticSearch-Head-0.1.5_0.zip  
       1. 解压  
       2. 浏览器设置--->扩展插件--->开启开发者模式--->加载解压缩的扩展  
       3. 选择ElasticSearch-Head-0.1.5_0/0.1.5_0文件  
2. cerebro   
    1. 官网  
   <https://github.com/lmenezes/cerebro>  
    2. 下载安装相应的包  
    3. 安装java 11+
    ```
    apt install openjdk-11-jdk -y
    ```
    3. 配置  
    ```
    #默认无法启动,查看日志,可以看到以下提示,原因是默认cerebro.db文件所有目录没有权限导致[root@ubuntu2404 ~]#journalctl -u cerebro
    Caused by: java.sql.SQLException: opening db: './cerebro.db': 权限不够

    #修改配置文件
    [root@ubuntu2404 ~]#vim /etc/cerebro/application.conf
    data.path: "/var/lib/cerebro/cerebro.db" #取消此行注释
    #data.path = "./cerebro.db" #注释此行，默认路径是/usr/share/cerebro/cerebro.db
    #此目录自动生成

    [root@ubuntu2204 ~]#ll -d /var/lib/cerebro
    drwxr-xr-x 2 cerebro cerebro 4096 4月 10 2021 /var/lib/cerebro/
    [root@ubuntu2404 ~]#systemctl restart cerebro.service active

    #默认监听9000端口
    [root@ubuntu2404 ~]#ss -ntlp|grep 9000
    LISTEN   0 100   *:9000         *:*       users:(("java",pid=26333,fd=155))
    ```
    ```
    #访问下面链接地址
    http://cerebro.wang.org:9000
    #在Node address输入框中输入任意ES集群节点的地址
    http://127.0.0.1:9200  # 注意http://
    ```