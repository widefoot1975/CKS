#!/usr/bin/env bash
# e07 — Run a Deployment with the RuntimeDefault seccomp profile · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns fin --ignore-not-found --wait=true
rm -rf /opt/course/e07
mkdir -p /opt/course/e07

# 1) seccomp 설정이 없는 app + Unconfined 를 명시한 helper
kubectl create ns fin
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger
  namespace: fin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ledger
  template:
    metadata:
      labels:
        app: ledger
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
      - name: helper
        image: busybox:1.36
        command: ["sleep", "1d"]
        securityContext:
          seccompProfile:
            type: Unconfined
YAML
kubectl -n fin rollout status deploy ledger --timeout=120s

# 2) 시작 상태 확인: Seccomp 0 (kubelet seccompDefault 가 켜진 노드라면 app 은 2 일 수 있다)
POD=$(kubectl -n fin get pod -l app=ledger -o jsonpath='{.items[0].metadata.name}')
kubectl -n fin exec "$POD" -c app -- grep Seccomp: /proc/1/status
kubectl -n fin exec "$POD" -c helper -- grep Seccomp: /proc/1/status
