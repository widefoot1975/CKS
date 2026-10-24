#!/usr/bin/env bash
# a14 — 실습 후 정리 (정책을 남겨 두면 다른 문항의 배포를 막을 수 있으므로 반드시 지운다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete validatingadmissionpolicybinding trusted-registries-binding --ignore-not-found
kubectl delete validatingadmissionpolicy trusted-registries --ignore-not-found
kubectl delete ns orbit playground --ignore-not-found
rm -rf /opt/course/a14
