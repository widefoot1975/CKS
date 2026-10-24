#!/usr/bin/env bash
# f12 — Pin container images by digest · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns f12 --ignore-not-found --wait=true
rm -rf /opt/course/f12

# 1) namespace 와 이미지를 태그로 참조하는 Deployment (컨테이너 두 개)
kubectl create ns f12
mkdir -p /opt/course/f12
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: f12
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
      - name: sidecar
        image: busybox:1.36
        command: ["sleep", "86400"]
YAML
kubectl -n f12 rollout status deploy api --timeout=120s

# 2) 시작 상태 확인: spec 은 태그, status 의 imageID 는 다이제스트
kubectl -n f12 get deploy api -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
kubectl -n f12 get pod -l app=api
