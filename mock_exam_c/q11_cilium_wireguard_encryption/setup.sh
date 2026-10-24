#!/usr/bin/env bash
# c11 — Enable Cilium WireGuard transparent encryption · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# 클러스터는 바꾸지 않는다. Cilium 이 Helm 으로 설치되어 있는지 확인하고 현재 상태만 기록한다.
set -euo pipefail

# 0) 이전 실습 흔적 정리
rm -rf /opt/course/c11
mkdir -p /opt/course/c11

# 1) 전제 조건 확인
command -v helm >/dev/null || { echo "helm 이 필요하다"; exit 1; }
if ! helm -n kube-system status cilium >/dev/null 2>&1; then
  echo "Cilium 이 Helm 릴리스 kube-system/cilium 으로 설치되어 있지 않다. 이 문제는 Helm 으로 설치한 Cilium 이 필요하다."
  exit 1
fi
kubectl -n kube-system rollout status ds/cilium --timeout=120s

# 2) 현재 상태 기록 (릴리스, 사용자 values, 현재 암호화 상태)
{
  echo "# helm list"
  helm -n kube-system list -f '^cilium$'
  echo "# helm get values"
  helm -n kube-system get values cilium
  echo "# cilium-config enable-wireguard / enable-ipsec"
  kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard} {.data.enable-ipsec}{"\n"}'
} > /opt/course/c11/before.txt

# 3) 시작 상태 확인
cat /opt/course/c11/before.txt
AG=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec "$AG" -c cilium-agent -- cilium-dbg status | grep Encryption || true
