#!/usr/bin/env bash
# f11 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete ns f11 --ignore-not-found
rm -rf /opt/course/f11
