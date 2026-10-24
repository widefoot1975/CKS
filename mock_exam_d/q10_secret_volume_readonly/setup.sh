#!/usr/bin/env bash
# d10 — Mount a Secret as a read-only volume · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns topaz --ignore-not-found --wait=true
rm -rf /opt/course/d10

# 1) namespace 와 Secret
kubectl create ns topaz
kubectl -n topaz create secret generic db-cred --from-literal=username=app --from-literal=password=S3cr3t-d10!
mkdir -p /opt/course/d10

# 2) 고장 내기: Secret 을 환경 변수로 넣는 Deployment
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: topaz
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-cred
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-cred
              key: password
YAML

# 3) 시작 상태 확인: env 로 비밀번호가 보인다
kubectl -n topaz rollout status deploy app --timeout=180s
kubectl -n topaz exec deploy/app -- sh -c 'env | grep DB_'
