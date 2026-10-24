#!/usr/bin/env bash
# d10 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl delete ns topaz --ignore-not-found
rm -rf /opt/course/d10
