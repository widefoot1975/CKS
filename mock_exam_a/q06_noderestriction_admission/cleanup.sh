#!/usr/bin/env bash
# a06 — 실습 후 정리 (원본 apiserver 매니페스트 복구, 테스트 라벨 제거)
# 실행: sudo bash cleanup.sh
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a06/backup

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

kubectl label node --all a06-before- a06-after- a06-self- node-restriction.kubernetes.io/zone- >/dev/null 2>&1 || true
rm -rf /opt/course/a06
kubectl get nodes
