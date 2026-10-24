#!/usr/bin/env bash
# c09 — 실습 후 정리
# 실행: sudo bash cleanup.sh
set -euo pipefail

kubectl delete validatingadmissionpolicybinding tenant-pod-security-binding --ignore-not-found
kubectl delete validatingadmissionpolicy tenant-pod-security --ignore-not-found
kubectl delete ns tenant-a tenant-b --ignore-not-found
rm -rf /opt/course/c09
