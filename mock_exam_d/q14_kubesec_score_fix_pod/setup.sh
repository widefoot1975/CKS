#!/usr/bin/env bash
# d14 — Raise a Pod's kubesec score · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요: kubesec 설치)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns beryl --ignore-not-found --wait=true
rm -rf /opt/course/d14

# 1) kubesec 이 없으면 고정 버전 v2.14.2 설치
if ! command -v kubesec >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/kubesec.tgz" https://github.com/controlplaneio/kubesec/releases/download/v2.14.2/kubesec_linux_amd64.tar.gz
  tar -xzf "$tmp/kubesec.tgz" -C "$tmp"
  install -m 0755 "$tmp/kubesec" /usr/local/bin/kubesec
  rm -rf "$tmp"
fi
kubesec version 2>/dev/null || true

# 2) 빈 namespace 와 privileged Pod 매니페스트 (만들지는 않는다)
kubectl create ns beryl
mkdir -p /opt/course/d14
cat <<'YAML' > /opt/course/d14/pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: agent
  namespace: beryl
spec:
  containers:
  - name: agent
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
YAML

# 3) 시작 상태 확인
cat /opt/course/d14/pod.yaml
kubectl -n beryl get pod
