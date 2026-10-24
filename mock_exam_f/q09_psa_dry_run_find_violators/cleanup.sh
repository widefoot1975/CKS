#!/usr/bin/env bash
# f09 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns legacy --ignore-not-found
rm -rf /opt/course/f09
