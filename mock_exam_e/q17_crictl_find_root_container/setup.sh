#!/usr/bin/env bash
# e17 — Find the container running as root with crictl · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}

# 0) 이전 실습 흔적 정리
kubectl delete ns stack --ignore-not-found --wait=true
rm -rf /opt/course/e17
mkdir -p /opt/course/e17

# 1) 세 Deployment 를 모두 워커에 고정
#    web     : 이미지 USER 101 (securityContext 없음)
#    cache   : runAsUser 1000
#    reports : 아무 설정 없음 → root (찾아야 할 대상)
kubectl create ns stack
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: stack
spec:
  replicas: 1
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: stack
spec:
  replicas: 1
  selector:
    matchLabels: {app: cache}
  template:
    metadata:
      labels: {app: cache}
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
      containers:
      - name: cache
        image: busybox:1.36
        command: ["sleep", "1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reports
  namespace: stack
spec:
  replicas: 1
  selector:
    matchLabels: {app: reports}
  template:
    metadata:
      labels: {app: reports}
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: reports
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date > /tmp/report.txt; sleep 30; done"]
YAML

for d in web cache reports; do kubectl -n stack rollout status deploy "$d" --timeout=120s; done

# 2) 시작 상태 확인: 세 파드 모두 워커에서 Running
kubectl -n stack get pod -o wide
