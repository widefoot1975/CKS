#!/usr/bin/env bash
# e01 — Allow ingress only from one namespace · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns orion watchtower guest --ignore-not-found --wait=true
rm -rf /opt/course/e01
mkdir -p /opt/course/e01

# 1) 보호할 API: orion/api (8080)
kubectl create ns orion
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: orion
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:1.0
        args: ["-text=orion-api", "-listen=:8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: orion
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
YAML

# 2) 클라이언트: watchtower/probe (허용 대상), guest/probe (차단 대상)
for ns in watchtower guest; do
  kubectl create ns "$ns"
  kubectl -n "$ns" run probe --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 1d
done

kubectl -n orion rollout status deploy api --timeout=120s
kubectl -n watchtower wait pod probe --for=condition=Ready --timeout=120s
kubectl -n guest wait pod probe --for=condition=Ready --timeout=120s

# 3) 시작 상태 확인: 정책 없음 → 두 probe 모두 응답을 받는다
kubectl -n orion get deploy,svc,networkpolicy
kubectl -n guest exec probe -- curl -s -m 3 http://api.orion:8080 || true
