#!/usr/bin/env bash
# e11 — 실습 후 정리 (Istio 자체는 공용 구성요소라 지우지 않는다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns mesh-app legacy --ignore-not-found
rm -rf /opt/course/e11
