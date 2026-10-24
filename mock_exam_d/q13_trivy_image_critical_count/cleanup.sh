#!/usr/bin/env bash
# d13 — 실습 후 정리 (trivy 와 캐시는 다른 문제도 쓰므로 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl delete ns quartz --ignore-not-found
rm -rf /opt/course/d13
