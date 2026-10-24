#!/usr/bin/env bash
# d02 — 실습 후 정리 (kube-apiserver 매니페스트 복원, kube-bench 는 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

M=/etc/kubernetes/manifests/kube-apiserver.yaml
D=/opt/course/d02

if [ -f "$D/backup/kube-apiserver.yaml" ]; then
  cp "$D/backup/kube-apiserver.yaml" "$M"
  echo "매니페스트를 복원했다. API 서버 재시작 대기..."
  sleep 10
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
rm -rf "$D"
kubectl -n kube-system get pod -l component=kube-apiserver
