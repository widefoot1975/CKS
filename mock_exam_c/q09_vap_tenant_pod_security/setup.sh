#!/usr/bin/env bash
# c09 — Enforce tenant Pod security with a ValidatingAdmissionPolicy · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete validatingadmissionpolicybinding tenant-pod-security-binding --ignore-not-found
kubectl delete validatingadmissionpolicy tenant-pod-security --ignore-not-found
kubectl delete ns tenant-a tenant-b --ignore-not-found --wait=true
rm -rf /opt/course/c09

# 1) namespace: tenant-a 는 정책 대상, tenant-b 는 대상 아님
kubectl create ns tenant-a
kubectl label ns tenant-a tenant=true
kubectl create ns tenant-b

# 2) 테스트 매니페스트
T=/opt/course/c09/tests
mkdir -p "$T"

cat <<'YAML' > "$T/ok.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: ok
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
YAML

cat <<'YAML' > "$T/bad-init-privileged.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: bad-init-privileged
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  initContainers:
  - name: tune
    image: busybox:1.36
    command: ["sh", "-c", "true"]
    securityContext:
      privileged: true
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
YAML

cat <<'YAML' > "$T/bad-hostpath.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: bad-hostpath
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /var/log
YAML

cat <<'YAML' > "$T/bad-hostpid.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: bad-hostpid
spec:
  hostPID: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
YAML

cat <<'YAML' > "$T/bad-container-root.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: bad-container-root
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
  - name: helper
    image: busybox:1.36
    command: ["sleep", "1d"]
    securityContext:
      runAsNonRoot: false
      runAsUser: 0
YAML

cat <<'YAML' > "$T/bad-no-nonroot.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: bad-no-nonroot
spec:
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
YAML

# 3) 시작 상태 확인
kubectl get ns tenant-a tenant-b --show-labels
ls -1 "$T"
