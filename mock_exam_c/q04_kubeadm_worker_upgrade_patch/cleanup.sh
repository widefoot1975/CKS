#!/usr/bin/env bash
# c04 — 실습 후 정리 (업그레이드한 패키지 버전은 되돌리지 않는다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}
kubectl uncordon "$W" || true
kubectl delete ns upg --ignore-not-found
rm -rf /opt/course/c04
