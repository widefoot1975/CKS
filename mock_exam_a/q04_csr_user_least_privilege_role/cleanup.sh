#!/usr/bin/env bash
# a04 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns team-ana --ignore-not-found
kubectl delete csr dev-ana --ignore-not-found
rm -rf /opt/course/a04
