#!/usr/bin/env bash
# f11 — Run a Deployment in a user namespace · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# 노드가 Linux 6.3+, containerd 2.0+ (runc 1.2+) 여야 hostUsers: false 가 동작한다.
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns f11 --ignore-not-found --wait=true
rm -rf /opt/course/f11

# 1) namespace 와 root 로 도는 Deployment (hostUsers 기본값 true)
kubectl create ns f11
mkdir -p /opt/course/f11
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: isolated
  namespace: f11
spec:
  replicas: 1
  selector:
    matchLabels:
      app: isolated
  template:
    metadata:
      labels:
        app: isolated
    spec:
      containers:
      - name: sleeper
        image: busybox:1.36
        command: ["sleep", "86400"]
YAML
kubectl -n f11 rollout status deploy isolated --timeout=120s

# 2) 시작 상태 확인: uid_map 이 0 0 4294967295 (호스트 user namespace)
kubectl get nodes -o custom-columns=NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
kubectl -n f11 exec deploy/isolated -- cat /proc/self/uid_map
