#!/usr/bin/env bash
# e17 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns stack --ignore-not-found
rm -rf /opt/course/e17
