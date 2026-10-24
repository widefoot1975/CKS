#!/usr/bin/env bash
# c12 — Build a distroless non-root Go image · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) podman 확인 (없으면 여기서 멈춘다)
command -v podman >/dev/null || { echo "podman 이 필요하다"; exit 1; }

# 1) 이전 실습 흔적 정리: 컨테이너, 이미지, 결과 파일
podman rm -f c12-test >/dev/null 2>&1 || true
podman rmi -f c12-app:v2 localhost/c12-app:v2 >/dev/null 2>&1 || true
rm -rf /opt/course/c12

# 2) Trivy 가 없으면 v0.69.3 고정 설치 (latest·v0.69.4 금지)
if ! command -v trivy >/dev/null; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/v0.69.3/contrib/install.sh | sh -s -- -b /usr/local/bin v0.69.3
fi
trivy --version | head -1

# 3) Go 소스와 고쳐야 할 Dockerfile
mkdir -p /opt/course/c12/app
cat <<'EOF' > /opt/course/c12/app/main.go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "c12 app ok")
	})
	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF
cat <<'EOF' > /opt/course/c12/app/go.mod
module example.com/c12app

go 1.24
EOF
cat <<'EOF' > /opt/course/c12/app/Dockerfile
FROM golang:1.24
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/app .
EXPOSE 8080
CMD /usr/local/bin/app
EOF

# 4) 시작 상태 확인
ls -l /opt/course/c12/app
podman images 2>/dev/null | grep c12-app || echo "이미지 c12-app 없음 (정상)"
