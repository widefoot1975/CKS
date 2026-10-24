#!/usr/bin/env bash
# f05 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns hr --ignore-not-found
rm -rf /opt/course/f05
