#!/usr/bin/env bash
# c14 — Fix misconfigurations reported by trivy config · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns reports --ignore-not-found --wait=true
rm -rf /opt/course/c14

# 1) Trivy 가 없으면 v0.69.3 고정 설치 (latest·v0.69.4 금지)
if ! command -v trivy >/dev/null; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/v0.69.3/contrib/install.sh | sh -s -- -b /usr/local/bin v0.69.3
fi
trivy --version | head -1

# 2) 고쳐야 할 파일들
mkdir -p /opt/course/c14/k8s
cat <<'EOF' > /opt/course/c14/app.sh
#!/bin/sh
echo "report job started"
exec sleep infinity
EOF
chmod 755 /opt/course/c14/app.sh

cat <<'EOF' > /opt/course/c14/Dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl
COPY app.sh /app.sh
USER root
ENTRYPOINT ["/app.sh"]
EOF

cat <<'EOF' > /opt/course/c14/k8s/deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report
  namespace: reports
spec:
  replicas: 2
  selector:
    matchLabels:
      app: report
  template:
    metadata:
      labels:
        app: report
    spec:
      hostNetwork: true
      containers:
      - name: report
        image: nginx:latest
        securityContext:
          privileged: true
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
EOF

# 3) 대상 namespace (매니페스트는 적용하지 않는다)
kubectl create ns reports

# 4) 시작 상태 확인
find /opt/course/c14 -type f
