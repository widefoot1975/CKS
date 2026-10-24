#!/usr/bin/env bash
# f16 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

M=/etc/kubernetes/manifests/kube-apiserver.yaml
B=/opt/course/f16/backup/kube-apiserver.yaml

# 백업한 매니페스트로 kube-apiserver 복원 후 API 서버가 다시 뜰 때까지 기다린다
if [ -f "$B" ] && ! cmp -s "$B" "$M"; then
  cp "$B" "$M"
  sleep 15
fi
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

kubectl delete ns f16 --ignore-not-found
rm -f /etc/kubernetes/audit/policy.yaml
rm -f /var/log/kubernetes/audit/audit*.log
rm -rf /opt/course/f16
