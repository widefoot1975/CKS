#!/usr/bin/env bash
# e09 — Drop capabilities from a privileged container · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns edge --ignore-not-found --wait=true
rm -rf /opt/course/e09
mkdir -p /opt/course/e09

# 1) 과한 권한을 가진 컨테이너: privileged + NET_ADMIN + SYS_ADMIN
kubectl create ns edge
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netmon
  namespace: edge
spec:
  replicas: 1
  selector:
    matchLabels:
      app: netmon
  template:
    metadata:
      labels:
        app: netmon
    spec:
      containers:
      - name: netmon
        image: busybox:1.36
        command: ["sleep", "1d"]
        securityContext:
          privileged: true
          capabilities:
            add: ["NET_ADMIN", "SYS_ADMIN"]
YAML
kubectl -n edge rollout status deploy netmon --timeout=120s

# 2) 시작 상태 확인: 모든 capability, 네트워크 설정 변경 가능
kubectl -n edge exec deploy/netmon -- grep CapEff /proc/1/status
kubectl -n edge exec deploy/netmon -- sh -c 'ip link set lo mtu 65536 && echo "lo 설정 변경 성공 (NET_ADMIN 있음)"' || true
