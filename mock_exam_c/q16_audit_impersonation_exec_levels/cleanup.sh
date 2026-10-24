#!/usr/bin/env bash
# c16 — 실습 후 정리: kube-apiserver 원본 매니페스트 복구 후 API 서버 대기, 감사 정책·로그 삭제
# 실행: sudo bash cleanup.sh
set -euo pipefail

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/c16/backup/kube-apiserver.yaml

if [ -f "$BK" ]; then
  cp "$BK" "$MAN"
  echo "kube-apiserver 매니페스트 복구, API 서버 대기 중..."
  sleep 20   # kubelet 이 매니페스트 변경을 감지해 재시작할 시간
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
kubectl delete ns c16 --ignore-not-found
kubectl delete clusterrolebinding c16-impersonate-jane --ignore-not-found
kubectl delete clusterrole c16-impersonate-jane --ignore-not-found
rm -rf /etc/kubernetes/audit /var/log/kubernetes/audit /opt/course/c16
kubectl get --raw=/readyz; echo
