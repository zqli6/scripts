# Logstash收集日志写入 MySQL 数据库
1. lzq学习文档：  
   [点击查看](https://www.yuque.com/jianglai-iayzx/sa1zul/mm8hhtlxgy3xuwsa#Vh9CY)  
2. logstash输出数据到MySQL插件`logstash-output-jdbc`的安装  
安装方位在线安装和离线导入  
   1. mysql官网下载地址：<https://downloads.mysql.com/archives/c-j/>  
   2. 步骤  
   ```
   # 创建logstash插件目录
   mkdir -p /usr/share/logstash/vendor/jar/jdbc
   # 解压tar包并复制jar包到logstash的插件目录中 
   tar xf mysql-connector-j-8.0.33.tar.gz
   cp mysql-connector-j-8.0.33/mysql-connector-j-8.0.33.jar /usr/share/logstash/vendor/jar/jdbc/
   # 方法一：在线logstash安装插件
      #安装
      /usr/share/logstash/bin/logstash-plugin install logstash-output-jdbc
   # 方法二：离线安装，先导出再导入
      # 导出
      /usr/share/logstash/bin/logstash-plugin prepare-offline-pack logstash-output-jdbc
      # 导入
      /usr/share/logstash/bin/logstash-plugin install file:///usr/share/logstash/logstash-offline-plugins-8.6.1.zip
   # 查看插件
      /usr/share/logstash/bin/logstash-plugin list|grep jdbc
   # 移除插件
      /usr/share/logstash/bin/logstash-plugin remove logstash-output-jdbc
   ```
   3. logstash-offline-plugins-8.6.1.zip离线
   ```
   wget https://gitee.com/zqli6/scripts/raw/main/ELK/logstash-offline-plugins-8.6.1.zip
   ```
