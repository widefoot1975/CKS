#!/usr/bin/env bash
# a01 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns aurora --ignore-not-found
rm -rf /opt/course/a01
