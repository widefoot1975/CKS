#!/usr/bin/env bash
# a16 — 실습 후 정리 (원본 apiserver 매니페스트 복구, 정책·로그 삭제)
# 실행: sudo bash cleanup.sh
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a16/backup

wait_new_apiserver() {
  local old=$1 cur
  for i in $(seq 1 90); do
    cur=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
    if [ -n "$cur" ] && [ "$cur" != "$old" ]; then break; fi
    sleep 2
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

if [ -f "$BK/kube-apiserver.yaml" ] && ! cmp -s "$BK/kube-apiserver.yaml" "$MANIFEST"; then
  OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
  cp "$BK/kube-apiserver.yaml" "$MANIFEST"
  wait_new_apiserver "$OLD"
fi
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

kubectl delete ns prod --ignore-not-found
rm -rf /etc/kubernetes/audit /var/log/kubernetes/audit /opt/course/a16
kubectl get --raw=/readyz; echo
