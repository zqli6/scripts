#!/bin/bash
# 作者：李芝全
# 功能：拉取镜像改tag并上传

echo "请确定脚本中的镜像名已修改"
echo "请确定脚本中私有仓库地址已修改"
echo "请确定已登录私有仓库"

# 华为云 SWR 仓库前缀
SWR_PREFIX="swr.cn-southwest-2.myhuaweicloud.com/zqli"

# 定义核心版本 (来自你的 Chart.yaml)
OP_VER="v0.90.1"

# 生产级显式清单：格式为 "源镜像地址"
# 这里我帮你手动修正了所有域名和对应的 appVersion
declare -a IMAGES=(
"quay.io/prometheus/blackbox-exporter:v0.28.0"
"ghcr.io/jimmidyson/configmap-reload:v0.15.0"
"quay.io/brancz/kube-rbac-proxy:v0.21.0"
"quay.io/prometheus/alertmanager:v0.31.1"
"grafana/grafana:12.4.1"
"registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.18.0"
"quay.io/brancz/kube-rbac-proxy:v0.21.0"
"quay.io/brancz/kube-rbac-proxy:v0.21.0"
"quay.io/prometheus/prometheus:v3.10.0"
"quay.io/prometheus-operator/prometheus-operator:v0.89.0"
"quay.io/brancz/kube-rbac-proxy:v0.21.0"
"registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.12.0"
"quay.io/prometheus/node-exporter:v1.10.2"
"quay.io/brancz/kube-rbac-proxy:v0.21.0"
)

echo "========== 开始生产级同步 (共 ${#IMAGES[@]} 个镜像) =========="

for full_src in "${IMAGES[@]}"; do
    # 拼接镜像名和标签 SWR
    target_img="${SWR_PREFIX}/${IMAGES}"

    echo "------------------------------------------------"
    echo "同步中: $full_src"
    
    # 尝试拉取 (增加重试逻辑处理网络波动)
    MAX_RETRIES=3
    for ((i=1; i<=MAX_RETRIES; i++)); do
        docker pull "$full_src" && break
        echo "拉取失败，尝试第 $i 次重试..."
        sleep 2
    done

    if [ $? -eq 0 ]; then
        docker tag "$full_src" "$target_img"
        docker push "$target_img"
        echo "成功: $target_img"
    else
        echo ">>> 严重警告: $full_src 同步失败，请检查网络！"
    fi
done

echo "========== 同步任务结束 =========="
