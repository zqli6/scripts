#!/bin/bash

MY_REGISTRY="swr.cn-southwest-2.myhuaweicloud.com/zqli"

images=(
  "quay.io/metallb/controller:main"
  "quay.io/metallb/controller:v0.15.3"
  "quay.io/metallb/controller:v0.14.9"
  "goharbor/harbor-portal:v2.14.3"
  "quay.io/prometheus/alertmanager:v0.31.1"
  "quay.io/prometheus-operator/prometheus-config-reloader:v0.89.0"
  "nginx-arm64:latest"
  "nginx-arm64:alpine"
  "assaflavie/runlike:latest"
  "trivy/trivy-db:2"
  "ghcr.io/aquasecurity/trivy:latest"
  "quay.io/calico/kube-controllers:master_v3.30.7"
  "mobz/elasticsearch-head:5"
  "quay.io/metallb/speaker:main"
  "quay.io/metallb/speaker:v0.15.3"
  "quay.io/metallb/speaker:v0.14.9"
  "sonatype/nexus3:latest"
  "bitnami/mariadb:latest"
  "stefanprodan/podinfo:latest"
  "prom/statsd-exporter:v0.26.1"
  "victoriametrics/vmauth:v1.136.0"
  "victoriametrics/vmselect:v1.140.0-cluster"
  "victoriametrics/vmstorage:v1.140.0-cluster"
  "victoriametrics/vminsert:v1.140.0-cluster"
  "victoriametrics/victoria-metrics:v1.140.0"
  "victoriametrics/operator:v0.68.3"
  "cni-plugins-linux-amd64:v1.6.2"
  "redis:7.2.5"
  "mariadb:10.6"
  "jumpserver/jms_all:v4.10.16-lts"
  "quay.io/brancz/kube-rbac-proxy:v0.21.0"
  "quay.io/prometheus/node-exporter:v1.10.2"
  "registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.12.0"
  "quay.io/prometheus-operator/prometheus-operator:v0.89.0"
  "quay.io/prometheus/prometheus:v3.10.0"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.18.0"
  "grafana/grafana:12.4.1"
  "ghcr.io/jimmidyson/configmap-reload:v0.15.0"
  "quay.io/prometheus/blackbox-exporter:v0.28.0"
  "quay.io/calico/cni:master_v3.30.7"
  "alpine:3.18"
  "kubectl:1.31.0"
  "grafana-image-renderer:latest"
  "curl:8.19.0"
  "bats:1.13.0"
  "thanos:v0.41.0"
  "k8s-sidecar:2.6.0"
  "admission-webhook:v0.90.1"
  "prometheus-config-reloader:v0.90.1"
  "busybox:latest"
  "busybox:1.37.0"
  "goharbor/harbor-registryctl:v2.14.3"
  "ghcr.io/kube-vip/kube-vip:v1.1.2"
  "ghcr.io/kube-vip/kube-vip:v1.0.4"
  "ghcr.io/kube-vip/kube-vip:v0.6.4"
  "alpine/helm:3.12.0"
  "gcr.io/kaniko-project/executor:debug"
  "jenkins/inbound-agent:latest"
  "maven:3.8.6-openjdk-11"
  "maven:3.9-eclipse-temurin-21"
  "pod-test:v0.1"
  "pod-test:v0.2"
  "quay.io/calico/node:master_v3.30.7"
  "quay.io/calico/typha:master_v3.30.7"
  "kuboard/uboard:v3"
  "kuboard/etcd:v3.4.14"
  "goharbor/harbor-exporter:v2.14.3"
  "goharbor/nginx-photon:v2.14.3"
  "goharbor/redis-photon:v2.14.3"
  "goharbor/registry-photon:v2.14.3"
  "goharbor/harbor-db:v2.14.3"
  "goharbor/harbor-jobservice:v2.14.3"
  "goharbor/harbor-core:v2.14.3"
  "goharbor/trivy-adapter-photon:v2.14.3"
  "bitnami/mysql:8.0.37-debian-12-r2"
  "ubuntu:22.04"
  "ubuntu:22.04-apt"
  "mysql:5.7"
  "xtrabackup:1.0"
  "nfs-subdir-external-provisioner:v4.0.2"
  "example/pod-test:v.01"
  "ghcr.io/flannel-io/flannel-cni-plugin:v1.8.0-flannel1"
  "jenkins-plugins:26.3.17"
  "jenkins-plugins:26.3.17.15"
  "jenkins-plugins:docker_docker_pipeline_k8s"
  "icloud.com/zqli/spring-boot-helloworld)"
  "jenkins:2.541.2-jdk21"
  "nginx-ingress-controller:v1.14.3"
  "kube-webhook-certgen:v1.6.7"
  "kube-webhook-certgen:1.8.0"
  "jimmidyson/configmap-reload:v0.8.0"
  "prom/prometheus:v2.41.0"
  "google_containers/pause:3.10.1"
  "google_containers/coredns:v1.13.1"
  "google_containers/etcd:3.6.6-0"
  "google_containers/kube-controller-manager:v1.35.0"
  "google_containers/kube-scheduler:v1.35.0"
  "google_containers/kube-proxy:v1.35.0"
  "google_containers/kube-apiserver:v1.35.0"
  "ghcr.io/flannel-io/flannel:v0.28.0"
)

for img in "${images[@]}"; do
    echo "========================================="
    echo "处理镜像: ${img}"
    
    # 1. 拉取原始镜像（自动适配当前 CPU 架构）
    if ! docker pull --platform linux/arm64 "${img}"; then
        echo "错误：拉取 ${img} 失败，跳过"
        continue
    fi

    ## 2. 生成安全的 tar 文件名（将 / 和 : 替换为 _）
    #safe_name=$(echo "${img}" | tr '/:' '_-')
    #tar_file="${safe_name}.tar"
    #
    #echo "保存为文件: ${tar_file}"
    #docker save "${img}" -o "${tar_file}"
    #
    ## 可选：检查保存是否成功
    #if [ ! -f "${tar_file}" ]; then
    #    echo "错误：保存 ${tar_file} 失败"
    #    continue
    #fi
    #echo "已保存: $(ls -lh ${tar_file} | awk '{print $5}')"
    
    # 3. 打标签，准备推送到私有仓库
    dest="${MY_REGISTRY}/${img}-arm"
    echo "目标标签: ${dest}"
    docker tag "${img}" "${dest}"
    
    # 4. 推送到华为云 SWR（如果需要）
    if docker push "${dest}"; then
        echo "推送成功: ${dest}"
    else
        echo "推送失败: ${dest}"
    fi
    
    # 5. 删除本地临时标签（不影响原始镜像）
    docker rmi "${dest}" "${img}">/dev/null 2>&1
    
    echo "-----------------------------------------"
done

echo "所有镜像处理完毕。tar 文件列表："
ls -lh *_*.tar 2>/dev/null | awk '{print $9, $5}'