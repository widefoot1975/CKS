#!/usr/bin/env bash
# a04 — Certificate user via a CSR with a least-privilege Role · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

command -v openssl >/dev/null || { echo "openssl 이 필요하다"; exit 1; }

# 0) 이전 실습 흔적 정리: namespace, CSR 객체, 결과 파일
kubectl delete ns team-ana --ignore-not-found --wait=true
kubectl delete csr dev-ana --ignore-not-found
rm -rf /opt/course/a04
mkdir -p /opt/course/a04

# 1) namespace 와 대상 리소스
kubectl create ns team-ana
kubectl -n team-ana create deploy ana-app --image=nginx:1.27-alpine --replicas=1
kubectl -n team-ana create secret generic ana-db --from-literal=password=a04-not-for-ana
kubectl -n team-ana rollout status deploy ana-app --timeout=120s

# 2) 시작 상태 확인: Role·RoleBinding·CSR 없음
kubectl -n team-ana get deploy,secret,role,rolebinding
kubectl get csr dev-ana 2>/dev/null || echo "CSR dev-ana 없음 (정상)"
