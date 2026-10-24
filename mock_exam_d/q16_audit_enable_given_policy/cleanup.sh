#!/usr/bin/env bash
# d16 — 실습 후 정리 (kube-apiserver 매니페스트 복원, 정책·로그 삭제)
# 실행: sudo bash cleanup.sh
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

M=/etc/kubernetes/manifests/kube-apiserver.yaml
D=/opt/course/d16

if [ -f "$D/backup/kube-apiserver.yaml" ]; then
  cp "$D/backup/kube-apiserver.yaml" "$M"
  echo "매니페스트를 복원했다. API 서버 재시작 대기..."
  sleep 10
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
kubectl -n default delete secret audit-probe --ignore-not-found
rm -f /etc/kubernetes/audit/d16-policy.yaml
rm -f /var/log/kubernetes/audit/audit*.log
rm -rf "$D"
kubectl -n kube-system get pod -l component=kube-apiserver
