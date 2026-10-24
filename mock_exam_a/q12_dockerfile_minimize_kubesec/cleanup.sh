#!/usr/bin/env bash
# a12 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# kubesec 은 다른 문항도 쓰므로 지우지 않는다.
set -euo pipefail

if command -v podman >/dev/null; then
  podman rmi -f localhost/a12-app:v1 localhost/a12-app:v2 >/dev/null 2>&1 || true
fi
rm -rf /opt/course/a12 /tmp/a12-before.json /tmp/a12-after.json
