#!/usr/bin/env bash
# c10 — Hunt down leaked secret values · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns billing --ignore-not-found --wait=true
rm -rf /opt/course/c10

# 1) namespace
kubectl create ns billing

# 2) 고장 내기: ConfigMap 에 비밀번호, apply 로 만든 Secret(stringData → last-applied 어노테이션에 평문),
#    Deployment env 리터럴. (Secret 만 apply 로 만들고 나머지는 create 로 만들어 어노테이션을 남기지 않는다)
cat <<'YAML' | kubectl create -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: billing
data:
  DB_HOST: db.billing.svc.cluster.local
  LOG_LEVEL: info
  DB_PASSWORD: Pa55-billing-2025
YAML

cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: billing-db
  namespace: billing
type: Opaque
stringData:
  DB_PASSWORD: Pa55-billing-2025
  API_TOKEN: tok-7f3a9c
YAML

cat <<'YAML' | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-api
  namespace: billing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing-api
  template:
    metadata:
      labels:
        app: billing-api
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        envFrom:
        - configMapRef:
            name: app-config
        env:
        - name: DB_PASSWORD
          value: Pa55-billing-2025
        - name: API_TOKEN
          value: tok-7f3a9c
YAML
kubectl -n billing rollout status deploy/billing-api --timeout=180s
mkdir -p /opt/course/c10

# 3) 시작 상태 확인
kubectl -n billing get cm,secret,deploy,rs
