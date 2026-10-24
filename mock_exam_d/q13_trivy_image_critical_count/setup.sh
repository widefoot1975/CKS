#!/usr/bin/env bash
# d13 — Count CRITICAL vulnerabilities with Trivy · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요: trivy 설치·DB)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns quartz --ignore-not-found --wait=true
rm -rf /opt/course/d13

# 1) Trivy 가 없으면 고정 버전 v0.69.3 설치 (v0.69.4 는 악성 릴리스 — latest 금지)
if ! command -v trivy >/dev/null 2>&1; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/v0.69.3/contrib/install.sh | sh -s -- -b /usr/local/bin v0.69.3
fi
trivy --version | head -1

# 2) 오래된 이미지와 최신 이미지를 쓰는 Deployment 두 개
kubectl create ns quartz
kubectl -n quartz create deployment legacy --image=nginx:1.19
kubectl -n quartz create deployment current --image=nginx:1.27-alpine
mkdir -p /opt/course/d13

# 3) 시작 상태 확인
kubectl -n quartz rollout status deploy legacy --timeout=180s
kubectl -n quartz rollout status deploy current --timeout=180s
kubectl -n quartz get deploy -o wide
