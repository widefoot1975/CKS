#!/usr/bin/env bash
# f01 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns berlin --ignore-not-found
rm -rf /opt/course/f01
