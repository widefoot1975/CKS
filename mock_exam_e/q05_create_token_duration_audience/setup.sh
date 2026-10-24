#!/usr/bin/env bash
# e05 — Short-lived ServiceAccount token with a custom audience · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns cicd --ignore-not-found --wait=true
rm -rf /opt/course/e05
mkdir -p /opt/course/e05

# 1) namespace 와 ServiceAccount (토큰 Secret 은 만들지 않는다)
kubectl create ns cicd
kubectl -n cicd create serviceaccount ci-deployer

# 2) 디코딩 도구 확인
command -v jq >/dev/null || echo "주의: jq 가 없다 — apt-get install -y jq 로 설치하거나 python3 -m json.tool 을 쓴다"

# 3) 시작 상태 확인: SA 만 있고 토큰 Secret 은 없다
kubectl -n cicd get sa ci-deployer
kubectl -n cicd get secret
