#!/usr/bin/env bash
# c01 — 실습 후 정리 (ingress-nginx 는 공용 구성요소라 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns shop --ignore-not-found
kubectl delete pod outsider -n default --ignore-not-found
rm -rf /opt/course/c01
