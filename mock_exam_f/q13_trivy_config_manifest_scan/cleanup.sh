#!/usr/bin/env bash
# f13 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# Trivy 는 공용 도구라 지우지 않는다.
set -euo pipefail

kubectl delete ns f13 --ignore-not-found
rm -rf /opt/course/f13
