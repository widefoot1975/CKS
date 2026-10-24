#!/usr/bin/env bash
# f09 — Find Pod Security baseline violators with a dry run · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns legacy --ignore-not-found --wait=true
rm -rf /opt/course/f09

# 1) Pod Security 라벨이 없는 namespace (클러스터 기본값 privileged → 무엇이든 만들어진다)
kubectl create ns legacy
mkdir -p /opt/course/f09

# 2) 단독 Pod 다섯 개: web 만 baseline 준수, 나머지 넷은 각각 다른 항목 위반
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: legacy
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: debug-priv
  namespace: legacy
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      privileged: true
---
apiVersion: v1
kind: Pod
metadata:
  name: host-net
  namespace: legacy
spec:
  hostNetwork: true
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
---
apiVersion: v1
kind: Pod
metadata:
  name: log-reader
  namespace: legacy
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    volumeMounts:
    - name: logs
      mountPath: /host-logs
      readOnly: true
  volumes:
  - name: logs
    hostPath:
      path: /var/log
      type: Directory
---
apiVersion: v1
kind: Pod
metadata:
  name: cap-add
  namespace: legacy
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
YAML
kubectl -n legacy wait pod --all --for=condition=Ready --timeout=120s

# 3) 시작 상태 확인
kubectl get ns legacy --show-labels
kubectl -n legacy get pod
