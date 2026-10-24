#!/usr/bin/env bash
# b09 — 실습 후 정리 (Istio 자체는 다른 문항도 쓰므로 지우지 않는다)
# 실행: sudo bash cleanup.sh
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

kubectl delete ns bank outside --ignore-not-found
rm -rf /opt/course/b09
