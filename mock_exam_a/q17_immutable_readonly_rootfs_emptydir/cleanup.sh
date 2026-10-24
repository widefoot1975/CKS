#!/usr/bin/env bash
# a17 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns glacier --ignore-not-found
rm -rf /opt/course/a17
