#!/usr/bin/env bash
# e07 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns fin --ignore-not-found
rm -rf /opt/course/e07
