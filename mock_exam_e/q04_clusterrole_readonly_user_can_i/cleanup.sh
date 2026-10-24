#!/usr/bin/env bash
# e04 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete clusterrolebinding e04-readonly-audit-joe --ignore-not-found
kubectl delete clusterrole e04-readonly --ignore-not-found
rm -rf /opt/course/e04
