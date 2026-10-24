#!/usr/bin/env bash
# a13 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# Trivy 와 그 캐시는 다른 문항도 쓰므로 지우지 않는다.
set -euo pipefail

kubectl delete ns kobra --ignore-not-found
rm -rf /opt/course/a13 /tmp/a13-images.txt
