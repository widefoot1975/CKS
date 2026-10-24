#!/usr/bin/env bash
# d17 — Read-only root filesystem for an nginx Deployment · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns pearl --ignore-not-found --wait=true
rm -rf /opt/course/d17

# 1) 쓰기 가능한 루트 파일시스템으로 도는 nginx Deployment
kubectl create ns pearl
mkdir -p /opt/course/d17
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: pearl
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML

# 2) 시작 상태 확인: 아무 데나 쓸 수 있다
kubectl -n pearl rollout status deploy cache --timeout=180s
kubectl -n pearl exec deploy/cache -- sh -c 'touch /usr/share/nginx/html/setup-test && echo "root fs writable" && rm /usr/share/nginx/html/setup-test'
