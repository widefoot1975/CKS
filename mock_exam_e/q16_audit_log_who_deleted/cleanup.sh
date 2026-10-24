#!/usr/bin/env bash
# e16 — 실습 후 정리 (원본 kube-apiserver 매니페스트 복구, 감사 정책·로그 삭제)
# 실행: sudo bash cleanup.sh
set -euo pipefail

export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
MANI=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/e16/backup

apiserver_id() { crictl ps --name kube-apiserver --state running -q 2>/dev/null | head -1; }

wait_apiserver() {
  local old="$1" i cur
  for i in $(seq 1 60); do
    cur=$(apiserver_id)
    [ -n "$cur" ] && [ "$cur" != "$old" ] && break
    sleep 3
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

kubectl delete ns billing --ignore-not-found

if [ -f "$BK/kube-apiserver.yaml" ]; then
  old=$(apiserver_id)
  cp "$BK/kube-apiserver.yaml" "$MANI"
  echo "kube-apiserver 재시작 대기 ..."
  wait_apiserver "$old"
  kubectl -n kube-system get pod -l component=kube-apiserver
fi

rm -f /etc/kubernetes/audit/e16-policy.yaml /var/log/kubernetes/audit/audit*.log
rm -rf /opt/course/e16
