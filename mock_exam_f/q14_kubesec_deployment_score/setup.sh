#!/usr/bin/env bash
# f14 — Raise the kubesec score of a Deployment · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# kubesec 이 없으면 GitHub 릴리스에서 받으므로 인터넷 연결이 필요하다.
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns f14 --ignore-not-found --wait=true
rm -rf /opt/course/f14

# 1) kubesec v2.14.2 설치 (없을 때만)
if ! command -v kubesec >/dev/null; then
  T=$(mktemp -d)
  curl -fsSL https://github.com/controlplaneio/kubesec/releases/download/v2.14.2/kubesec_linux_amd64.tar.gz -o "$T/kubesec.tgz"
  tar -xzf "$T/kubesec.tgz" -C "$T" kubesec
  install -m 0755 "$T/kubesec" /usr/local/bin/kubesec
  rm -rf "$T"
fi
kubesec version 2>/dev/null || true

# 2) privileged 컨테이너 하나뿐인 매니페스트 (critical -30)
kubectl create ns f14
mkdir -p /opt/course/f14
cat <<'YAML' > /opt/course/f14/deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing
  namespace: f14
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing
  template:
    metadata:
      labels:
        app: billing
    spec:
      containers:
      - name: billing
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          privileged: true
YAML

# 3) 시작 상태 확인
cat /opt/course/f14/deploy.yaml
kubectl -n f14 get all
