#!/usr/bin/env bash
# e06 — Block Pod egress to the Kubernetes API · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns sandbox --ignore-not-found --wait=true
rm -rf /opt/course/e06
mkdir -p /opt/course/e06

# 1) 신뢰할 수 없는 작업을 흉내 내는 curl 파드
kubectl create ns sandbox
kubectl -n sandbox run runner --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 1d
kubectl -n sandbox wait pod runner --for=condition=Ready --timeout=120s

# 2) 시작 상태 확인: 정책이 없어 API 서버에 닿는다
kubectl -n sandbox get networkpolicy
kubectl -n sandbox exec runner -- curl -sk -m 5 https://kubernetes.default.svc/version || true
