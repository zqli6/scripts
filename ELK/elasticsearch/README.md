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