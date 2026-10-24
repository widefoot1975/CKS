#!/usr/bin/env bash
# e01 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns orion watchtower guest --ignore-not-found
rm -rf /opt/course/e01
