#!/usr/bin/env bash
# d09 — Enforce Pod Security restricted and fix a Pod · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns coral --ignore-not-found --wait=true
rm -rf /opt/course/d09

# 1) 라벨 없는 namespace
kubectl create ns coral
mkdir -p /opt/course/d09

# 2) securityContext 가 없는 Pod 매니페스트 (아직은 문제없이 뜬다)
cat <<'YAML' > /opt/course/d09/api.yaml
apiVersion: v1
kind: Pod
metadata:
  name: api
  namespace: coral
  labels:
    app: api
spec:
  containers:
  - name: api
    image: nginxinc/nginx-unprivileged:1.27-alpine
    ports:
    - containerPort: 8080
YAML
kubectl apply -f /opt/course/d09/api.yaml

# 3) 시작 상태 확인: 라벨 없음, Pod Running
kubectl -n coral wait --for=condition=Ready pod/api --timeout=180s
kubectl get ns coral --show-labels
kubectl -n coral get pod api
