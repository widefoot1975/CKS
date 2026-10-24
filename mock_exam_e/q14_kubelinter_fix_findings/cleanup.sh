#!/usr/bin/env bash
# e14 — 실습 후 정리 (kube-linter 바이너리는 공용 도구라 지우지 않는다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns lint --ignore-not-found
rm -rf /opt/course/e14
