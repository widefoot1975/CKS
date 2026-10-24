#!/usr/bin/env bash
# d05 — Stop mounting the ServiceAccount token · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns opal --ignore-not-found --wait=true
rm -rf /opt/course/d05

# 1) namespace 와 비교용 Pod (default SA, 토큰 자동 마운트)
kubectl create ns opal
kubectl -n opal run legacy --image=nginx:1.27-alpine
mkdir -p /opt/course/d05

# 2) 시작 상태 확인: legacy 에는 토큰이 보인다
kubectl -n opal wait --for=condition=Ready pod/legacy --timeout=180s
kubectl -n opal exec legacy -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n opal get sa,pod
