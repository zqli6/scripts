# scripts

运维自动化脚本合集，收录日常运维工作中常用工具的安装与配置脚本，覆盖监控、CI/CD、数据库、VPN 等多个方向。所有脚本均在 CentOS / Rocky Linux 环境下验证，支持通过 GitHub 或 Gitee 获取单个文件使用。

## 包含内容

1. **Jenkins**：安装脚本
2. **Prometheus**：node_exporter 安装脚本，以及基于 Consul 服务发现的 docker-compose 配置（单节点和集群两种）
3. **Redis**：安装脚本，以及单机、集群、哨兵三种模式的连通性测试脚本（Shell + Python），安装完成后可直接运行验收
4. **Zabbix**：Server 7.0 安装脚本；告警脚本对接了钉钉、企业微信、邮件三种渠道，均为生产环境实际使用的版本；另附可直接导入的监控模板文件
5. **OpenVPN**：服务端一键部署脚本
6. **others**：SSH 公钥批量推送、批量创建用户、系统代理配置、企业微信和钉钉消息推送等通用脚本

## 快速获取单个脚本
```bash
# GitHub（国内可用 ghproxy 加速）
wget https://raw.githubusercontent.com/zqli6/scripts/main/path/to/file
wget https://ghproxy.net/https://raw.githubusercontent.com/zqli6/scripts/main/path/to/file

# Gitee（国内推荐）
wget https://gitee.com/zqli6/scripts/raw/main/path/to/file
```

## 克隆仓库
```bash
git clone https://github.com/zqli6/scripts/
git clone https://gitee.com/zqli6/scripts/
```

> 环境：Ubuntu 20.04+ / Rocky Linux 8+
