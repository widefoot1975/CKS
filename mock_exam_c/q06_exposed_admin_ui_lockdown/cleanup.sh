#!/usr/bin/env bash
# c06 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns ops --ignore-not-found
kubectl delete clusterrolebinding ops-monitoring legacy-tooling --ignore-not-found
rm -rf /opt/course/c06
