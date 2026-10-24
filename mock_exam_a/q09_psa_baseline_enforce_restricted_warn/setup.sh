#!/usr/bin/env bash
# a09 — Enforce Pod Security baseline while warning on restricted · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns atlas --ignore-not-found --wait=true
rm -rf /opt/course/a09
mkdir -p /opt/course/a09

# 1) PSA 라벨 없는 namespace + 성격이 다른 Deployment 세 개
#    atlas-web   : restricted 준수
#    atlas-cache : 기본값(root) → baseline OK, restricted 위반
#    atlas-agent : privileged + hostPath → baseline 위반
kubectl create ns atlas
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlas-web
  namespace: atlas
spec:
  replicas: 1
  selector:
    matchLabels:
      app: atlas-web
  template:
    metadata:
      labels:
        app: atlas-web
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlas-cache
  namespace: atlas
spec:
  replicas: 1
  selector:
    matchLabels:
      app: atlas-cache
  template:
    metadata:
      labels:
        app: atlas-cache
    spec:
      containers:
      - name: cache
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlas-agent
  namespace: atlas
spec:
  replicas: 1
  selector:
    matchLabels:
      app: atlas-agent
  template:
    metadata:
      labels:
        app: atlas-agent
    spec:
      containers:
      - name: agent
        image: busybox:1.36
        command: ["sh", "-c", "while true; do ls /host/log > /dev/null; sleep 30; done"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-log
          mountPath: /host/log
          readOnly: true
      volumes:
      - name: host-log
        hostPath:
          path: /var/log
          type: Directory
YAML
for d in atlas-web atlas-cache atlas-agent; do
  kubectl -n atlas rollout status deploy $d --timeout=120s
done

# 2) 시작 상태 확인: 라벨 없음, 파드 3개 Running
kubectl get ns atlas --show-labels
kubectl -n atlas get pod
