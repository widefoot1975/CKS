#!/usr/bin/env bash
# c10 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns billing --ignore-not-found
rm -rf /opt/course/c10
