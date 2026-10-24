#!/usr/bin/env bash
# b17 — Trace a malicious process from the node to its Pod · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}
W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}

# 0) 이전 실습 흔적 정리
kubectl delete ns batch frontend --ignore-not-found --wait=true
rm -rf /opt/course/b17
mkdir -p /opt/course/b17
kubectl create ns batch
kubectl create ns frontend

# 1) 워크로드 (모두 워커에 고정). report-gen 이 /tmp/xmrig 스크립트를 exec 한다 (CPU 는 쓰지 않음)
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-gen
  namespace: batch
spec:
  replicas: 1
  selector:
    matchLabels:
      app: report-gen
  template:
    metadata:
      labels:
        app: report-gen
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: report
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          printf '#!/bin/sh\nwhile true; do sleep 5; done\n' > /tmp/xmrig
          chmod +x /tmp/xmrig
          exec /tmp/xmrig --donate-level 1 -o stratum+tcp://pool.b17.invalid:3333
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: etl
  namespace: batch
spec:
  replicas: 1
  selector:
    matchLabels:
      app: etl
  template:
    metadata:
      labels:
        app: etl
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: etl
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo transform; sleep 30; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
  namespace: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: shop
        image: nginx:1.27-alpine
YAML
kubectl -n batch rollout status deploy report-gen --timeout=120s
kubectl -n batch rollout status deploy etl --timeout=120s
kubectl -n frontend rollout status deploy shop --timeout=120s

# 2) 시작 상태 확인
kubectl get pod -n batch -o wide
kubectl get pod -n frontend -o wide
kubectl get ns batch frontend --show-labels
