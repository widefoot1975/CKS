#!/usr/bin/env bash
# c12 — 실습 후 정리 (Trivy 는 공용 도구라 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

if command -v podman >/dev/null; then
  podman rm -f c12-test >/dev/null 2>&1 || true
  podman rmi -f c12-app:v2 localhost/c12-app:v2 >/dev/null 2>&1 || true
fi
rm -rf /opt/course/c12
