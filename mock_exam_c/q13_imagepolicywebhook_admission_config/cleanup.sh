#!/usr/bin/env bash
# c13 — 실습 후 정리: kube-apiserver 원본 매니페스트 복구 후 API 서버가 돌아올 때까지 대기
# 실행: sudo bash cleanup.sh
set -euo pipefail

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/c13/backup/kube-apiserver.yaml

if [ -f "$BK" ]; then
  cp "$BK" "$MAN"
  echo "kube-apiserver 매니페스트 복구, API 서버 대기 중..."
  sleep 20   # kubelet 이 매니페스트 변경을 감지해 재시작할 시간
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
kubectl delete pod c13-test --ignore-not-found
rm -rf /etc/kubernetes/policywebhook /opt/course/c13
kubectl get --raw=/readyz; echo
