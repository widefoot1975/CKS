#!/usr/bin/env bash
# f14 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# kubesec 은 공용 도구라 지우지 않는다.
set -euo pipefail

kubectl delete ns f14 --ignore-not-found
rm -rf /opt/course/f14
