#!/usr/bin/env bash
# f10 — Read a Secret directly from etcd · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# etcdctl 이 없으면 GitHub 릴리스에서 받으므로 인터넷 연결이 필요하다.
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns vault-demo --ignore-not-found --wait=true
rm -rf /opt/course/f10

# 1) etcdctl 설치 (없을 때만) — 클러스터 etcd 이미지 태그와 같은 버전 (예: registry.k8s.io/etcd:3.6.4-0 → v3.6.4)
if ! command -v etcdctl >/dev/null; then
  IMG=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}')
  V=${IMG##*:}; V=${V%%-*}
  echo "etcd 버전: $V → etcdctl v$V 설치"
  T=$(mktemp -d)
  if curl -fsSL "https://github.com/etcd-io/etcd/releases/download/v${V}/etcd-v${V}-linux-amd64.tar.gz" -o "$T/etcd.tgz"; then
    tar -xzf "$T/etcd.tgz" -C "$T" --strip-components=1 "etcd-v${V}-linux-amd64/etcdctl"
    install -m 0755 "$T/etcdctl" /usr/local/bin/etcdctl
  else
    echo "etcdctl 다운로드 실패 — etcd 파드 안의 etcdctl 을 쓰면 된다 (kubectl -n kube-system exec etcd-<노드> -- etcdctl ...)"
  fi
  rm -rf "$T"
fi

# 2) namespace 와 Secret
kubectl create ns vault-demo
kubectl -n vault-demo create secret generic db-cred \
  --from-literal=username=admin --from-literal=password=S3cr3t-f10
mkdir -p /opt/course/f10

# 3) 시작 상태 확인: 저장 암호화 설정이 없어야 문제 의도대로다
if grep -q -- '--encryption-provider-config' /etc/kubernetes/manifests/kube-apiserver.yaml; then
  echo "주의: kube-apiserver 에 --encryption-provider-config 가 이미 있다 (다른 문제의 흔적일 수 있음)"
fi
kubectl -n vault-demo get secret db-cred
command -v etcdctl || true
