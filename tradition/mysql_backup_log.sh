#!/bin/bash
# *************************************
# * 功能: 自动化导出mysql日志
# * 适配: Ubuntu系统 + MySQL 8.0+
# * 作者: 李芝全
# * 版本: 2025-12-27
# *************************************

set -e  # 错误立即退出

# ==================== 基础配置参数（可按需修改默认值） ====================
BACKUP_FILE="all.sql"  # 备份文件名
BACKUP_PATH="/root"       # 备份文件存放路径（默认当前目录）
FULL_BACKUP_FILE="${BACKUP_PATH}/${BACKUP_FILE}"
# 从节点配置
SLAVE_USER="root"      # 从节点登录用户（默认root）
SLAVE_BACKUP_PATH="/root"  # 备份文件在从节点的存放路径
SLAVE_PASS="123456"    # 从节点登录密码（固定为123456，无需手动输入）

# ==================== 交互式手动输入Slave节点IP ====================
read -p "请输入目标Slave节点的IP地址：" SLAVE_IP
# 验证IP输入非空
if [ -z "${SLAVE_IP}" ]; then
    echo "错误：Slave节点IP地址不能为空！"
    exit 1
fi
echo "已确认目标从节点：${SLAVE_USER}@${SLAVE_IP}:${SLAVE_BACKUP_PATH}"

# ==================== 步骤0：检查并安装sshpass（实现自动密码认证） ====================
echo -e "\n【前置步骤】检查并安装sshpass依赖（用于自动输入密码）..."
if ! command -v sshpass > /dev/null 2>&1; then
    echo "未检测到sshpass，正在自动安装..."
    apt update && apt install sshpass -y > /dev/null 2>&1
else
    echo "sshpass已存在，无需重复安装"
fi

# ==================== 新增：前置检测all.sql文件是否存在 ====================
echo -e "\n【前置检测】检查备份文件 ${FULL_BACKUP_FILE} 是否存在..."
if [ -f "${FULL_BACKUP_FILE}" ]; then
    # 文件存在，交互式询问是否重新生成
    read -p "检测到 ${FULL_BACKUP_FILE} 已存在，是否重新生成备份文件？(y/n)：" REGENERATE
    # 统一转换为小写，兼容大小写输入（Y/y/N/n）
    REGENERATE=$(echo "${REGENERATE}" | tr 'A-Z' 'a-z')
    # 判断用户输入
    if [ "${REGENERATE}" != "y" ] && [ "${REGENERATE}" != "yes" ]; then
        echo "用户选择不重新生成备份文件，将使用已存在的 ${FULL_BACKUP_FILE}"
        # 跳过备份步骤，直接进入传输流程
        SKIP_BACKUP=1
    else
        echo "用户选择重新生成备份文件，将覆盖原有 ${FULL_BACKUP_FILE}"
        SKIP_BACKUP=0
    fi
else
    # 文件不存在，直接标记为执行备份
    echo "未检测到 ${FULL_BACKUP_FILE}，将自动执行备份生成流程"
    SKIP_BACKUP=0
fi

# ==================== 步骤1：清理二进制日志（reset master） ====================
# 仅当需要重新生成备份时，执行日志清理（若不重新备份，无需清理日志）
if [ ${SKIP_BACKUP} -eq 0 ]; then
    echo -e "\n【步骤1/3】执行reset master清理二进制日志..."
    # 修复原有语法错误，单独输出提示
    mysql -e "
    RESET MASTER;
    SHOW MASTER STATUS;
    "
    echo "二进制日志清理完成！"
    echo -e "\n请记录上述MASTER STATUS中的 File 和 Position 值，用于从节点配置！"
else
    echo -e "\n【跳过步骤1】无需清理二进制日志（使用已存在的备份文件）"
fi

# ==================== 步骤2：全量备份所有数据 ====================
# 仅当需要重新生成备份时，执行mysqldump备份
if [ ${SKIP_BACKUP} -eq 0 ]; then
    echo -e "\n【步骤2/3】执行mysqldump全量备份（包含二进制日志标记）..."
    # 参数说明：
    # -A：备份所有数据库
    # -F：备份后刷新二进制日志
    # --source-data=2：在备份文件中记录主节点的二进制日志文件名和位置（注释格式）
    # --single-transaction：InnoDB引擎无锁备份
    mysqldump -A -F --source-data=2 --single-transaction > "${FULL_BACKUP_FILE}"
    echo "全量备份完成！备份文件：${FULL_BACKUP_FILE}"
else
    echo -e "\n【跳过步骤2】无需生成备份文件（使用已存在的 ${FULL_BACKUP_FILE}）"
fi

# ==================== 步骤3：自动使用密码123456传输备份文件到Slave节点 ====================
echo -e "\n【步骤3/3】自动传输备份文件到从节点 ${SLAVE_IP}（无需手动输入密码）..."

# 使用sshpass + scp 自动传入密码，无需手动输入
# -p：指定密码；
echo "正在通过scp传输文件（自动使用密码认证）..."
sshpass -p "${SLAVE_PASS}" scp -o StrictHostKeyChecking=no "${FULL_BACKUP_FILE}" "${SLAVE_USER}@${SLAVE_IP}:${SLAVE_BACKUP_PATH}/"

# 使用sshpass + ssh 远程验证传输是否成功
echo "正在验证备份文件是否传输成功..."
if sshpass -p "${SLAVE_PASS}" ssh -o StrictHostKeyChecking=no "${SLAVE_USER}@${SLAVE_IP}" "test -f ${SLAVE_BACKUP_PATH}/${BACKUP_FILE}"; then
    echo "备份文件传输成功！已保存至从节点：${SLAVE_USER}@${SLAVE_IP}:${SLAVE_BACKUP_PATH}/${BACKUP_FILE}"
else
    echo "警告：备份文件传输后验证失败，请手动确认从节点是否存在该文件！"
fi

# ==================== 备份+传输完成提示 ====================
echo -e "\n======================================"
echo "  MySQL主节点备份+Slave自动传输流程完成！"
echo "  核心信息："
echo "    备份文件：${FULL_BACKUP_FILE}"
echo "    目标从节点：${SLAVE_IP}"
echo "    从节点密码：123456（已自动使用，无需手动输入）"
echo "    下一步：在从节点执行 mysql < ${SLAVE_BACKUP_PATH}/${BACKUP_FILE} 导入数据"
echo "======================================"