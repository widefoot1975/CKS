#!/usr/bin/env bash
# f01 — Block Pod egress to the cloud metadata endpoint · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# NetworkPolicy 를 적용하는 CNI(Cilium)가 필요하다.
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns berlin --ignore-not-found --wait=true
rm -rf /opt/course/f01

# 1) namespace, 웹 서버 webapp(+Service), 테스트용 client 파드
kubectl create ns berlin
mkdir -p /opt/course/f01
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: berlin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: berlin
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: berlin
  labels:
    app: client
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sleep", "86400"]
YAML
kubectl -n berlin rollout status deploy webapp --timeout=120s
kubectl -n berlin wait pod client --for=condition=Ready --timeout=120s

# 2) 시작 상태 확인: NetworkPolicy 없음, webapp 응답 200
kubectl -n berlin get deploy,svc,pod,networkpolicy
kubectl -n berlin exec client -- curl -s -o /dev/null -w 'webapp: %{http_code}\n' http://webapp || true
