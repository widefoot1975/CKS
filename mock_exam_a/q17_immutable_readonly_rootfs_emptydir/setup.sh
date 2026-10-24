#!/usr/bin/env bash
# a17 — Immutable Pods with read-only root filesystems · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns glacier --ignore-not-found --wait=true
rm -rf /opt/course/a17
mkdir -p /opt/course/a17

# 1) Deployment glacier-web (쓰기 가능한 루트 FS) + 단독 Pod 4개
#    glacier-cache   : 읽기 전용 + emptyDir            → immutable (유지)
#    glacier-tool    : 읽기 전용이지만 privileged       → 삭제 대상
#    glacier-logger  : securityContext 없음, 루트 FS 에 로그 기록 → 삭제 대상
#    glacier-sidecar : 메인은 읽기 전용, init 컨테이너가 쓰기 가능 → 삭제 대상
kubectl create ns glacier
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: glacier-web
  namespace: glacier
spec:
  replicas: 1
  selector:
    matchLabels: {app: glacier-web}
  template:
    metadata:
      labels: {app: glacier-web}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: glacier-cache
  namespace: glacier
spec:
  containers:
  - name: cache
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date > /cache/last; sleep 30; done"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
---
apiVersion: v1
kind: Pod
metadata:
  name: glacier-tool
  namespace: glacier
spec:
  containers:
  - name: tool
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      privileged: true
      readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Pod
metadata:
  name: glacier-logger
  namespace: glacier
spec:
  containers:
  - name: logger
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /var/log/app.log; sleep 10; done"]
---
apiVersion: v1
kind: Pod
metadata:
  name: glacier-sidecar
  namespace: glacier
spec:
  initContainers:
  - name: seed
    image: busybox:1.36
    command: ["sh", "-c", "echo seeded > /seed.txt"]
  containers:
  - name: main
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      readOnlyRootFilesystem: true
YAML
kubectl -n glacier rollout status deploy glacier-web --timeout=120s
kubectl -n glacier wait pod/glacier-cache pod/glacier-tool pod/glacier-logger pod/glacier-sidecar --for=condition=Ready --timeout=120s

# 2) 시작 상태 확인
kubectl -n glacier get deploy,pod
