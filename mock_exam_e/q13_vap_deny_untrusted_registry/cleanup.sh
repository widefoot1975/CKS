#!/usr/bin/env bash
# e13 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete validatingadmissionpolicybinding trusted-registry-only-binding --ignore-not-found
kubectl delete validatingadmissionpolicy trusted-registry-only --ignore-not-found
kubectl delete ns factory playground --ignore-not-found
rm -rf /opt/course/e13
