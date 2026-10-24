#!/usr/bin/env bash
# a05 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete clusterrolebinding ledger-ops-admin ledger-break-glass ledger-metrics-view --ignore-not-found
kubectl delete ns ledger --ignore-not-found
rm -rf /opt/course/a05
