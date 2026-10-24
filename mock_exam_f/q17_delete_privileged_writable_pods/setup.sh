#!/usr/bin/env bash
# f17 — Delete privileged and writable Pods · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns f17 --ignore-not-found --wait=true
rm -rf /opt/course/f17

# 1) namespace 와 단독 Pod 다섯 개
#    alpha: 불변 / beta: privileged / gamma: 설정 없음(쓰기 가능)
#    delta: 두 컨테이너 모두 읽기 전용 / epsilon: 두 번째 컨테이너만 쓰기 가능
kubectl create ns f17
mkdir -p /opt/course/f17
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: alpha
  namespace: f17
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Pod
metadata:
  name: beta
  namespace: f17
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      privileged: true
      readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Pod
metadata:
  name: gamma
  namespace: f17
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
---
apiVersion: v1
kind: Pod
metadata:
  name: delta
  namespace: f17
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
  - name: sidecar
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Pod
metadata:
  name: epsilon
  namespace: f17
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      readOnlyRootFilesystem: true
  - name: helper
    image: busybox:1.36
    command: ["sleep", "86400"]
YAML
kubectl -n f17 wait pod --all --for=condition=Ready --timeout=120s

# 2) 시작 상태 확인
kubectl -n f17 get pod
