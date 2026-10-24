#!/usr/bin/env bash
# c03 — 실습 후 정리 (ingress-nginx 는 공용 구성요소라 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns store --ignore-not-found
kubectl delete secret store-tls -n default --ignore-not-found
rm -rf /opt/course/c03
