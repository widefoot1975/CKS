#!/usr/bin/env bash
# a13 — Scan workload images with Trivy and stop the CRITICAL ones · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) Trivy v0.69.3 설치 (없을 때만). v0.69.4 는 악성 릴리스(CVE-2026-33634) → latest 금지, 버전 고정
if ! command -v trivy >/dev/null; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/v0.69.3/contrib/install.sh | sh -s -- -b /usr/local/bin v0.69.3
fi
trivy --version | head -1
trivy --version | grep -q '0.69.4' && { echo "경고: 악성 릴리스 v0.69.4 가 설치되어 있다. 제거 후 v0.69.3 을 설치하라"; exit 1; }

# 1) 이전 실습 흔적 정리
kubectl delete ns kobra --ignore-not-found --wait=true
rm -rf /opt/course/a13 /tmp/a13-images.txt
mkdir -p /opt/course/a13

# 2) 워크로드: 안전(busybox, pause) / 취약(nginx:1.19.0, httpd:2.4.39, init 컨테이너 python:3.7.0-slim)
kubectl create ns kobra
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kobra-web
  namespace: kobra
spec:
  replicas: 1
  selector:
    matchLabels: {app: kobra-web}
  template:
    metadata:
      labels: {app: kobra-web}
    spec:
      containers:
      - name: web
        image: busybox:1.36.1
        command: ["sh", "-c", "sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kobra-api
  namespace: kobra
spec:
  replicas: 1
  selector:
    matchLabels: {app: kobra-api}
  template:
    metadata:
      labels: {app: kobra-api}
    spec:
      containers:
      - name: api
        image: nginx:1.19.0
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kobra-report
  namespace: kobra
spec:
  replicas: 1
  selector:
    matchLabels: {app: kobra-report}
  template:
    metadata:
      labels: {app: kobra-report}
    spec:
      initContainers:
      - name: prepare
        image: python:3.7.0-slim
        command: ["python", "-c", "print('report schema ready')"]
      containers:
      - name: report
        image: busybox:1.36.1
        command: ["sh", "-c", "sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kobra-pause
  namespace: kobra
spec:
  replicas: 1
  selector:
    matchLabels: {app: kobra-pause}
  template:
    metadata:
      labels: {app: kobra-pause}
    spec:
      containers:
      - name: pause
        image: registry.k8s.io/pause:3.10
---
apiVersion: v1
kind: Pod
metadata:
  name: kobra-debug
  namespace: kobra
  labels: {app: kobra-debug}
spec:
  containers:
  - name: debug
    image: httpd:2.4.39
YAML
for d in kobra-web kobra-api kobra-report kobra-pause; do
  kubectl -n kobra rollout status deploy $d --timeout=300s
done
kubectl -n kobra wait pod/kobra-debug --for=condition=Ready --timeout=300s

# 3) 시작 상태 확인
kubectl -n kobra get deploy,pod
