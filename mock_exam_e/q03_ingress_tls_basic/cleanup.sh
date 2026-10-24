#!/usr/bin/env bash
# e03 — 실습 후 정리 (ingress-nginx 컨트롤러는 공용 구성요소라 지우지 않는다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns shop --ignore-not-found
rm -rf /opt/course/e03
