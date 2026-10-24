#!/usr/bin/env bash
# f10 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# etcdctl 은 공용 도구라 지우지 않는다.
set -euo pipefail

kubectl delete ns vault-demo --ignore-not-found
rm -rf /opt/course/f10
