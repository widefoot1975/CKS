#!/usr/bin/env bash
# a03 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# ingress-nginx 는 다른 문항도 쓰므로 지우지 않는다.
set -euo pipefail

kubectl delete ns shop --ignore-not-found
rm -rf /opt/course/a03
