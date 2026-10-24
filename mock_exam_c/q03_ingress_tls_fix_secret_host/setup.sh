#!/usr/bin/env bash
# c03 — Repair a broken TLS Ingress · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

command -v openssl >/dev/null || { echo "openssl 이 필요하다"; exit 1; }

# 0) 이전 실습 흔적 정리
kubectl delete ns store --ignore-not-found --wait=true
kubectl delete secret store-tls -n default --ignore-not-found
rm -rf /opt/course/c03

# 1) ingress-nginx 가 없으면 설치 (공용 구성요소, cleanup 이 지우지 않는다)
if ! kubectl get deploy ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/baremetal/deploy.yaml
fi
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s

# 2) 앱
kubectl create ns store
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopfront
  namespace: store
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shopfront
  template:
    metadata:
      labels:
        app: shopfront
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:1.0
        args: ["-text=store", "-listen=:8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: shopfront
  namespace: store
spec:
  selector:
    app: shopfront
  ports:
  - port: 80
    targetPort: 8080
YAML

# 3) 고장 내기 ①: 잘못된 namespace + Opaque 타입 + 키 이름 cert/key + CN 불일치(SAN 없음)
TMP=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  -keyout "$TMP/k.pem" -out "$TMP/c.pem" -subj "/CN=wrong.cks.local" 2>/dev/null
kubectl -n default create secret generic store-tls --from-file=cert="$TMP/c.pem" --from-file=key="$TMP/k.pem"
rm -rf "$TMP"

# 4) 고장 내기 ②: tls.hosts 가 rule 의 host 와 다르다
cat <<'YAML' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: store
  namespace: store
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - www.store.cks.local
    secretName: store-tls
  rules:
  - host: store.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shopfront
            port:
              number: 80
YAML

kubectl -n store rollout status deploy/shopfront --timeout=180s
mkdir -p /opt/course/c03

# 5) 시작 상태 확인
kubectl -n store get ingress store
kubectl -n default get secret store-tls
