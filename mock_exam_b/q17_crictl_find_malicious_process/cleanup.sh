#!/usr/bin/env bash
# b17 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

kubectl delete ns batch frontend --ignore-not-found
rm -rf /opt/course/b17
