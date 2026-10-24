#!/usr/bin/env bash
# b12 — Generate SBOMs and scan them for vulnerabilities · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 도구 설치 (없을 때만, 버전 고정). Trivy 는 절대 latest 를 쓰지 않는다 (v0.69.4 = 악성 릴리스)
if ! command -v trivy >/dev/null; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/v0.69.3/contrib/install.sh | sh -s -- -b /usr/local/bin v0.69.3
fi
TV=$(trivy --version 2>/dev/null | sed -n 's/^Version: *//p' | head -1)
echo "trivy version: $TV"
if [ "$TV" = "0.69.4" ]; then
  echo "위험: trivy 0.69.4 는 악성 릴리스(CVE-2026-33634)다. 삭제 후 0.69.3 을 설치하고 자격 증명을 교체할 것"; exit 1
fi
if ! command -v bom >/dev/null; then
  curl -fsSLo /usr/local/bin/bom https://github.com/kubernetes-sigs/bom/releases/download/v0.6.0/bom-amd64-linux
  chmod 755 /usr/local/bin/bom
fi
command -v jq >/dev/null || { apt-get update -y >/dev/null && apt-get install -y jq >/dev/null; }

# 1) 이전 실습 흔적 정리
rm -rf /opt/course/b12
mkdir -p /opt/course/b12

# 2) 시작 상태 확인
bom version 2>/dev/null | head -5 || true
ls -la /opt/course/b12
