#!/usr/bin/env bash
# a09 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns atlas --ignore-not-found
rm -rf /opt/course/a09
