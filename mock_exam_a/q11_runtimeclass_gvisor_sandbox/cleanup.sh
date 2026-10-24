#!/usr/bin/env bash
# a11 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# 워커의 gVisor(runsc)·containerd 핸들러·노드 라벨은 다른 문항도 쓰므로 지우지 않는다.
set -euo pipefail

kubectl delete ns sandbox --ignore-not-found
kubectl delete runtimeclass gvisor --ignore-not-found
rm -rf /opt/course/a11
