#!/usr/bin/env bash
# c05 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns tenant-x --ignore-not-found
kubectl delete clusterrole tenant-x-helper --ignore-not-found
rm -rf /opt/course/c05
