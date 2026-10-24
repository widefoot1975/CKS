#!/usr/bin/env bash
# e12 — Generate an SPDX SBOM with bom · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요)
set -euo pipefail

BOM_VERSION=v0.6.0

# 0) 이전 실습 흔적 정리
rm -rf /opt/course/e12
mkdir -p /opt/course/e12

# 1) bom 이 없으면 설치 (공용 도구, 버전 고정)
if ! command -v bom >/dev/null; then
  curl -fsSL -o /usr/local/bin/bom "https://github.com/kubernetes-sigs/bom/releases/download/${BOM_VERSION}/bom-amd64-linux"
  chmod +x /usr/local/bin/bom
fi
command -v jq >/dev/null || echo "주의: jq 가 없다 — JSON 확인은 python3 -m json.tool 로 대신한다"

# 2) 시작 상태 확인
bom version 2>/dev/null | head -5 || true
ls -la /opt/course/e12
