#!/usr/bin/env bash
# c14 — 실습 후 정리 (Trivy 는 공용 도구라 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns reports --ignore-not-found
rm -rf /opt/course/c14
