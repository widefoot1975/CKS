#!/usr/bin/env bash
# d04 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl delete ns jade --ignore-not-found
rm -rf /opt/course/d04
