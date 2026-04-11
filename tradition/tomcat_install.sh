#!/bin/bash
# *************************************
# * 功能: Shell部署tomcat9
# * 适配: Ubuntu 24.04
# * 作者: 李芝全
# * 版本: 2025-10-19
# *************************************
# 部署java环境
java_install(){
  apt install openjdk-11-jdk -y
}

java_config(){
  cat > /etc/profile.d/java.sh <<-eof
  export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
  export JAVA_BIN=\$JAVA_HOME/bin
  export PATH=\$JAVA_BIN:\$PATH
eof

  source /etc/profile.d/java.sh
}

get_tomcat(){
  [ -d /data/softs ] || mkdir -p /data/softs
  if [ ! -f /data/softs/apache-tomcat-9.0.97.tar.gz ]; then
    cd /data/softs
    wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.97/bin/apache-tomcat-9.0.97.tar.gz
  fi
}

untar_tomcat(){
  [ -d /data/server/tomcat ] && rm -rf /data/server/tomcat* \
                             || mkdir -p /data/server
  tar xf /data/softs/apache-tomcat-9.0.97.tar.gz -C /data/server/
  ln -sv /data/server/apache-tomcat-9.0.97 /data/server/tomcat
  echo "Tomcat jsp page from $(hostname)<br />" > /data/server/tomcat/webapps/ROOT/test.jsp
  echo 'SessionID = <span style="color:blue"><%=session.getId() %>' >> /data/server/tomcat/webapps/ROOT/test.jsp
}

tomcat_config(){
  cat > /etc/profile.d/tomcat.sh <<- eof
  export CATALINA_BASE=/data/server/tomcat
  export CATALINA_HOME=/data/server/tomcat
  export CATALINA_TMPDIR=\$CATALINA_HOME/temp
  export CLASSPATH=\$CATALINA_HOME/bin/bootstrap.jar:\$CATALINA_HOME/bin/tomcat-juli.jar
  export PATH=\$CATALINA_HOME/bin:\$PATH
eof
  source /etc/profile.d/tomcat.sh
}

tomcat_user(){
  userdel -r tomcat >/dev/null 2>&1
  useradd -u 666 -r -s /sbin/nologin tomcat
  chown tomcat:tomcat -R /data/server/tomcat/*
}

tomcat_service(){
  cat > /lib/systemd/system/tomcat.service <<-eof
[Unit]
Description=Tomcat
After=syslog.target network.target

[Service]
Type=forking
# Environment=JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
ExecStart=/data/server/tomcat/bin/startup.sh
ExecStop=/data/server/tomcat/bin/shutdown.sh
PrivateTmp=true
User=tomcat
Group=tomcat

[Install]
WantedBy=multi-user.target
eof
  systemctl daemon-reload
  systemctl enable --now tomcat
}

main(){
  java_install
  java_config
  get_tomcat
  untar_tomcat
  tomcat_config
  tomcat_user
  tomcat_service
}

main