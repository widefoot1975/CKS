#!/usr/bin/env bash
# a16 — Audit policy with ordered rules and log rotation · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a16/backup

# 매니페스트를 바꾼 뒤 새 kube-apiserver 컨테이너가 뜨고 /readyz 가 ok 가 될 때까지 대기
wait_new_apiserver() {
  local old=$1 cur
  for i in $(seq 1 90); do
    cur=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
    if [ -n "$cur" ] && [ "$cur" != "$old" ]; then break; fi
    sleep 2
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본으로 되돌린 뒤 다시 백업
mkdir -p "$BK"
if [ -f "$BK/kube-apiserver.yaml" ] && ! cmp -s "$BK/kube-apiserver.yaml" "$MANIFEST"; then
  OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
  cp "$BK/kube-apiserver.yaml" "$MANIFEST"
  wait_new_apiserver "$OLD"
fi
if grep -q -- '--audit-policy-file' "$MANIFEST"; then
  echo "kube-apiserver 에 이미 감사 설정이 있다. 다른 문항의 cleanup.sh 를 먼저 실행하라"; exit 1
fi
find /opt/course/a16 -mindepth 1 -maxdepth 1 ! -name backup -exec rm -rf {} +
cp "$MANIFEST" "$BK/kube-apiserver.yaml"
rm -rf /etc/kubernetes/audit /var/log/kubernetes/audit

# 1) namespace prod 와 대상 리소스
kubectl delete ns prod --ignore-not-found --wait=true
kubectl create ns prod
kubectl -n prod run prod-web --image=nginx:1.27-alpine
kubectl -n prod create secret generic prod-db --from-literal=password=a16-db-pass
kubectl -n prod create configmap prod-cfg --from-literal=mode=production
kubectl -n prod wait pod/prod-web --for=condition=Ready --timeout=120s

# 2) 시작 상태 확인: 감사 플래그 없음
grep -c -- '--audit' "$MANIFEST" || echo "감사 설정 없음 (정상)"
kubectl -n prod get pod,secret,configmap
