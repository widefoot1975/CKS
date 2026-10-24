#!/usr/bin/env bash
# f16 — Audit Secret access at Metadata level · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

M=/etc/kubernetes/manifests/kube-apiserver.yaml
B=/opt/course/f16/backup/kube-apiserver.yaml

# 0) 이전 실습 흔적 정리: 이전 실행의 백업이 있고 지금 매니페스트와 다르면 먼저 되돌린다
if [ -f "$B" ] && ! cmp -s "$B" "$M"; then
  echo "이전 실습의 kube-apiserver 변경을 백업으로 되돌린다"
  cp "$B" "$M"
  sleep 15
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
kubectl delete ns f16 --ignore-not-found --wait=true
rm -rf /opt/course/f16
rm -f /etc/kubernetes/audit/policy.yaml

# 1) 원래 매니페스트 백업 (cleanup 이 이 파일로 복원한다)
mkdir -p /opt/course/f16/backup
cp "$M" "$B"
if grep -q -- '--audit-policy-file' "$M"; then
  echo "주의: kube-apiserver 에 이미 --audit-policy-file 이 있다 (다른 문제의 흔적일 수 있음)"
fi

# 2) namespace 와 Secret
kubectl create ns f16
kubectl -n f16 create secret generic api-key --from-literal=token=f16-not-in-the-log

# 3) 시작 상태 확인
grep -c -- '--audit' "$M" || true
ls -l /opt/course/f16/backup
kubectl -n f16 get secret api-key
