#!/usr/bin/env bash
# d11 — 실습 후 정리 (gVisor 와 containerd 핸들러는 다른 문제도 쓰므로 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl delete ns onyx --ignore-not-found
kubectl delete runtimeclass gvisor --ignore-not-found
rm -rf /opt/course/d11
