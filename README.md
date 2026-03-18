# scripts

运维自动化脚本合集，收录日常运维工作中常用工具的安装与配置脚本，覆盖监控、CI/CD、数据库、VPN 等多个方向。所有脚本均在 CentOS / Rocky Linux 环境下验证，支持通过 GitHub 或 Gitee 获取单个文件使用。

## 目录说明

| 目录 | 说明 |
|------|------|
| `Jenkins/` | Jenkins 安装与初始化配置脚本 |
| `Prometheus/` | Prometheus 及 Exporter 安装脚本 |
| `Redis/` | Redis 安装与基础配置脚本 |
| `zabbix/` | Zabbix Server / Agent 安装脚本 |
| `openvpn/` | OpenVPN 服务端安装与客户端配置脚本 |
| `others/` | 其他常用运维脚本（系统初始化、日志清理等）|

## 快速获取单个脚本

**GitHub（国内可用 ghproxy 加速）：**
```bash
wget https://raw.githubusercontent.com/zqli6/scripts/main/path/to/file
# 或使用代理
wget https://ghproxy.net/https://raw.githubusercontent.com/zqli6/scripts/main/path/to/file
```

**Gitee：**
```bash
wget https://gitee.com/zqli6/scripts/raw/main/path/to/file
```

## 克隆仓库
```bash
# HTTPS - GitHub
git clone https://github.com/zqli6/scripts/

# HTTPS - Gitee（国内推荐）
git clone https://gitee.com/zqli6/scripts/

# SSH - GitHub
git clone git@github.com:zqli6/scripts.git

# SSH - Gitee
git clone git@gitee.com:zqli6/scripts.git
```

# 3. Clone this repostory with ssh
## 3.1 Cpoy public key to github
```
cat ~/.ssh/id_rsa.pub
```
1. GitHub  
GitHub → Setting → SSH and GPG keys → New SSH key
3. Gitee  
Gitee → 设置 → SSH公钥 → 添加公钥
## 3.2 Test connect
1. GitHub 
```
ssh -T git@github.com
```
2. Gitee
```
ssh -T git@gitee.com
```
## 3.3 Clone
1. GitHub
```python
git clone git@github.com:zqli6/scripts.git
```
2. Gitee
```
git clone git@gitee.com:zqli6/scripts.git
```
