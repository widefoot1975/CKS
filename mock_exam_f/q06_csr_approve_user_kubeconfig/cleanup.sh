#!/usr/bin/env bash
# f06 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete csr jane --ignore-not-found
kubectl delete ns dev --ignore-not-found
rm -rf /opt/course/f06
