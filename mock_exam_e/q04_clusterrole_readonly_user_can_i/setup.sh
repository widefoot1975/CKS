#!/usr/bin/env bash
# e04 — Read-only ClusterRole for a user, checked with can-i · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete clusterrolebinding e04-readonly-audit-joe --ignore-not-found
kubectl delete clusterrole e04-readonly --ignore-not-found
rm -rf /opt/course/e04
mkdir -p /opt/course/e04

# 1) 시작 상태 확인: audit-joe 는 아무것도 할 수 없다
kubectl auth can-i list pods -A --as audit-joe || true
kubectl get clusterrolebinding -o wide | grep -w audit-joe || echo "audit-joe 바인딩 없음 (정상)"
