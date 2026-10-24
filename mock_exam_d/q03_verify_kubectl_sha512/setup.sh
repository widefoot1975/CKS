#!/usr/bin/env bash
# d03 — Verify a kubectl binary against its official SHA-512 · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요: dl.k8s.io)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
rm -rf /opt/course/d03
mkdir -p /opt/course/d03

# 1) 클러스터(API 서버) 버전의 공식 kubectl 을 받는다
V=$(kubectl get --raw /version | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p')
[ -n "$V" ] || { echo "API 서버 버전을 알 수 없다"; exit 1; }
echo "cluster version: $V"
curl -fsSL -o /opt/course/d03/kubectl "https://dl.k8s.io/release/${V}/bin/linux/amd64/kubectl"
chmod 0755 /opt/course/d03/kubectl

# 2) 고장 내기: 바이너리 끝에 몇 바이트를 덧붙인다 (실행은 되지만 해시는 달라진다)
printf 'cks-d03' >> /opt/course/d03/kubectl

# 3) 시작 상태 확인
ls -l /opt/course/d03/
