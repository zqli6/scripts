#!/bin/bash
# *************************************
# * 功能: Shell脚本模板
# * 作者: 李芝全
# * 联系: wangshusen@sswang.com
# * 版本: 2025-10-22
# *************************************
# 设置环境变量
USER_NAME='root'
USER_HOME="/${USER_NAME}/.ssh"
SSH_CONFIG_FILE='/etc/ssh/ssh_config'
USER_PASSWD='123456'
HOSTADDR_PRE='10.0.0'

# 解析输入的IP最后一段（支持单值、{x..y}范围、混合格式）
parse_ip_suffix() {
    local input=$1
    local suffix_list=()

    # 分割输入中的空格，处理多个参数
    for item in $input; do
        if [[ $item =~ ^\{([0-9]+)\.\.([0-9]+)\}$ ]]; then
            local start=${BASH_REMATCH[1]}
            local end=${BASH_REMATCH[2]}
            for ((i=start; i<=end; i++)); do
                suffix_list+=($i)
            done
        else
            # 单值直接添加（简单校验是否为数字）
            if [[ $item =~ ^[0-9]+$ ]]; then
                suffix_list+=($item)
            else
                echo "警告：无效的IP后缀格式 '$item'，已跳过"
            fi
        fi
    done

    # 去重并排序（可选，确保顺序和唯一性）
    echo "${suffix_list[@]}" | tr ' ' '\n' | sort -n | uniq | tr '\n' ' '
}

# 准备基本环境
base_env(){
  apt install expect -y
  [ -d ${USER_HOME} ] && rm -rf ${USER_HOME}
  ssh-keygen -t rsa -P "" -f ${USER_HOME}/id_rsa
  sed -i '/ask/{s/#/ /; s/ask/no/}' ${SSH_CONFIG_FILE}
}

# expect自动化交互过程
expect_auto(){
  remote_host=$1
  expect -c "
    spawn ssh-copy-id -i ${USER_HOME}/id_rsa.pub $1
    expect {
      \"*yes/no*\" {send \"yes\r\"; exp_continue}
      \"*password*\" {send \"$USER_PASSWD\r\"; exp_continue}
      \"*Password*\" {send \"$USER_PASSWD\r\";}
    } "
}

# 生成完整的ip地址列表
greate_ip_list(){
    # 定制基础环境变了
    local ip_suffix_input=$1
    local parsed_suffixes=$(parse_ip_suffix "${ip_suffix_input}")
    host_list=()

    # 生成完整IP列表
    for suffix in ${parsed_suffixes}; do
        host_list+=("${HOSTADDR_PRE}.${suffix}")
    done

    # 若没有有效IP，退出
    if [ ${#host_list[@]} -eq 0 ]; then
        echo "错误：未解析到有效IP地址"
        exit 1
    fi
    echo ${host_list[*]}
}

# 跨主机免认证环境
auth_auto(){
  local ip_suffix_input="$1"  # 接收IP后缀参数
  # 调用IP生成函数时传入参数
  local host_list=$(greate_ip_list "${ip_suffix_input}")

  for i in $host_list
  do
    expect_auto ${USER_NAME}@$i
  done
}

# 主函数执行
main(){
    local ip_suffix_input=""
    read -p "请输入IP最后一段（支持单值、{x..y}范围、空格分隔混合格式，例如：12 {16..19}）：" ip_suffix_input

    # 基本环境准备
    base_env
    # 跨主机免密认证
    auth_auto "${ip_suffix_input}"
}

# 执行主函数
main