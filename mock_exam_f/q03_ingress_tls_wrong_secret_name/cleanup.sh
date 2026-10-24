#!/usr/bin/env bash
# f03 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# ingress-nginx 는 공용 인프라라 지우지 않는다.
set -euo pipefail

kubectl delete ns shop --ignore-not-found
rm -rf /opt/course/f03
