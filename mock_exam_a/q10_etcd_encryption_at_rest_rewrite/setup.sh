#!/usr/bin/env bash
# a10 — Encrypt Secrets at rest and rewrite the existing data · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a10/backup
HERE=$(cd "$(dirname "$0")" && pwd)

# 0) 이전 실습이 암호화를 켠 채 남아 있으면 cleanup.sh 로 먼저 평문으로 되돌린다
if grep -q -- '--encryption-provider-config' "$MANIFEST"; then
  if [ -f "$HERE/cleanup.sh" ]; then
    echo "암호화 설정이 남아 있다 → cleanup.sh 실행"
    bash "$HERE/cleanup.sh"
  else
    echo "kube-apiserver 에 --encryption-provider-config 가 이미 있다. 이 문항의 cleanup.sh 를 먼저 실행하라"; exit 1
  fi
fi

# 1) 원본 매니페스트 백업, 이전 결과·설정 파일 정리
rm -rf /opt/course/a10
mkdir -p "$BK"
cp "$MANIFEST" "$BK/kube-apiserver.yaml"
rm -rf /etc/kubernetes/enc
command -v hexdump >/dev/null || echo "참고: hexdump 가 없다 (bsdmainutils/bsdextrautils 패키지)"

# 2) 평문으로 저장될 Secret
kubectl delete ns finance --ignore-not-found --wait=true
kubectl create ns finance
kubectl -n finance create secret generic db-creds --from-literal=username=fin-app --from-literal=password=a10-S3cretPass

# 3) 시작 상태 확인: etcd 에 평문 (비밀번호 문자열이 그대로 보인다)
ETCD_POD=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec "$ETCD_POD" -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/finance/db-creds | grep -a -c 'a10-S3cretPass' || true
grep -c -- '--encryption-provider-config' "$MANIFEST" || echo "암호화 설정 없음 (정상)"
