#!/usr/bin/env bash
# f13 — Fix Trivy misconfiguration findings in a manifest · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# Trivy 가 없으면 v0.69.3 을 설치하므로 인터넷 연결이 필요하다 (v0.69.4 는 악성 릴리스 → 절대 latest 를 쓰지 않는다).
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns f13 --ignore-not-found --wait=true
rm -rf /opt/course/f13

# 1) Trivy v0.69.3 설치 (없을 때만)
if ! command -v trivy >/dev/null; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/v0.69.3/contrib/install.sh | sh -s -- -b /usr/local/bin v0.69.3
fi
trivy --version | head -1

# 2) 설정 오류가 있는 매니페스트: hostPID, privileged, 쓰기 가능한 루트 파일시스템
kubectl create ns f13
mkdir -p /opt/course/f13/manifests
cat <<'YAML' > /opt/course/f13/manifests/deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: f13
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      hostPID: true
      containers:
      - name: catalog
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          privileged: true
YAML

# 3) 시작 상태 확인
ls -l /opt/course/f13/manifests
kubectl -n f13 get all
