#!/usr/bin/env bash
# d12 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

if command -v podman >/dev/null; then
  podman rmi -f d12-app:v1 localhost/d12-app:v1 >/dev/null 2>&1 || true
fi
rm -rf /opt/course/d12
