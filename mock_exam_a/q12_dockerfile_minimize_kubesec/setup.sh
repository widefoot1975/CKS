#!/usr/bin/env bash
# a12 — Harden a Dockerfile and raise a Deployment's kubesec score · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) podman 확인, kubesec v2.14.2 설치(없을 때만, 인터넷 필요)
command -v podman >/dev/null || { echo "podman 이 필요하다"; exit 1; }
if ! command -v kubesec >/dev/null; then
  curl -fsSLo /tmp/kubesec.tgz https://github.com/controlplaneio/kubesec/releases/download/v2.14.2/kubesec_linux_amd64.tar.gz
  tar -xzf /tmp/kubesec.tgz -C /usr/local/bin kubesec
  chmod 755 /usr/local/bin/kubesec && rm -f /tmp/kubesec.tgz
fi

# 1) 이전 실습 흔적 정리: 이미지, 결과 파일
podman rmi -f localhost/a12-app:v1 localhost/a12-app:v2 >/dev/null 2>&1 || true
rm -rf /opt/course/a12
mkdir -p /opt/course/a12/app

# 2) 소스와 문제 많은 Dockerfile
cat <<'EOF' > /opt/course/a12/app/main.go
package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	token := os.Getenv("API_TOKEN")
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "a12 ok (token set: %t)\n", token != "")
	})
	_ = http.ListenAndServe(":8080", nil)
}
EOF
cat <<'EOF' > /opt/course/a12/app/Dockerfile
FROM docker.io/library/golang:latest
ENV API_TOKEN=tok-a12-9f8e7d
WORKDIR /src
COPY main.go .
RUN apt-get update && apt-get install -y curl wget
RUN go build -o /usr/local/bin/app main.go
EXPOSE 8080
CMD ["/usr/local/bin/app"]
EOF

# 3) 적용하지 않을 Deployment 매니페스트 (critical: privileged, hostNetwork)
cat <<'EOF' > /opt/course/a12/deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: a12-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: a12-app
  template:
    metadata:
      labels:
        app: a12-app
    spec:
      hostNetwork: true
      containers:
      - name: app
        image: localhost/a12-app:v1
        env:
        - name: API_TOKEN
          value: tok-a12-9f8e7d
        securityContext:
          privileged: true
EOF

# 4) 시작 상태 확인
ls -l /opt/course/a12 /opt/course/a12/app
kubesec version 2>/dev/null || true
