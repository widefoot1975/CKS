#!/usr/bin/env bash
# d12 — Pin the base image and run as non-root in a Dockerfile · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요: docker.io)
set -euo pipefail

# 0) podman 이 있는지 확인 (없으면 여기서 멈춘다)
command -v podman >/dev/null || { echo "podman 이 필요하다"; exit 1; }

# 1) 이전 실습 흔적 정리: 이미지, 결과 파일
podman rmi -f d12-app:v1 localhost/d12-app:v1 >/dev/null 2>&1 || true
rm -rf /opt/course/d12

# 2) 빌드 컨텍스트: latest 태그 + root 로 실행되는 Dockerfile
mkdir -p /opt/course/d12/app
cat <<'EOF' > /opt/course/d12/app/Dockerfile
FROM docker.io/library/alpine:latest
COPY app.sh /app/app.sh
RUN chmod 0755 /app/app.sh
USER root
CMD ["/app/app.sh"]
EOF
cat <<'EOF' > /opt/course/d12/app/app.sh
#!/bin/sh
echo "app running as uid=$(id -u) gid=$(id -g)"
EOF

# 3) 시작 상태 확인: 소스만 있고 이미지는 없다
ls -l /opt/course/d12/app
podman images 2>/dev/null | grep d12-app || echo "이미지 d12-app 없음 (정상)"
