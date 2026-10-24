#!/usr/bin/env bash
# f17 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns f17 --ignore-not-found
rm -rf /opt/course/f17
