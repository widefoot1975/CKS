#!/usr/bin/env bash
# b14 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

kubectl delete validatingadmissionpolicybinding allowed-registries-binding --ignore-not-found
kubectl delete validatingadmissionpolicy allowed-registries --ignore-not-found
kubectl delete ns policy-config team-red team-blue --ignore-not-found
rm -rf /opt/course/b14
