#!/usr/bin/env bash
# b13 — 실습 후 정리 (kube-linter·kubesec 은 다른 문항도 쓰므로 지우지 않는다)
# 실행: sudo bash cleanup.sh
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

kubectl delete ns catalog --ignore-not-found
rm -rf /opt/course/b13
