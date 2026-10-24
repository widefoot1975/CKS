#!/usr/bin/env bash
# b04 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

kubectl delete clusterrolebinding web-cluster-admin apps-secret-ops prom-view --ignore-not-found
kubectl delete clusterrole secret-ops --ignore-not-found
kubectl delete ns apps observe --ignore-not-found
rm -rf /opt/course/b04
