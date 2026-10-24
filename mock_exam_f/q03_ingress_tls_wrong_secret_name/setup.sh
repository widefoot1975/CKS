#!/usr/bin/env bash
# f03 — Fix an Ingress that serves the wrong TLS certificate · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# ingress-nginx 가 없으면 설치하므로 인터넷 연결이 필요하다.
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns shop --ignore-not-found --wait=true
rm -rf /opt/course/f03
mkdir -p /opt/course/f03

# 1) ingress-nginx (baremetal, NodePort) — 없을 때만 설치, 정리할 때 지우지 않는다
if ! kubectl -n ingress-nginx get deploy ingress-nginx-controller >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/baremetal/deploy.yaml
fi
kubectl -n ingress-nginx rollout status deploy ingress-nginx-controller --timeout=300s

# 2) 자체 서명 인증서 (SAN shop.cks.local) → TLS Secret shop-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /opt/course/f03/tls.key -out /opt/course/f03/tls.crt \
  -subj "/CN=shop.cks.local" -addext "subjectAltName=DNS:shop.cks.local" 2>/dev/null
kubectl create ns shop
kubectl -n shop create secret tls shop-tls --cert=/opt/course/f03/tls.crt --key=/opt/course/f03/tls.key
rm -f /opt/course/f03/tls.key      # 키는 Secret 에만 남긴다

# 3) 백엔드 shop-web (http-echo) + Service
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-web
  namespace: shop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop-web
  template:
    metadata:
      labels:
        app: shop-web
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:1.0
        args: ["-text=shop-web", "-listen=:5678"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: shop-web
  namespace: shop
spec:
  selector:
    app: shop-web
  ports:
  - port: 80
    targetPort: 5678
YAML

# 4) 고장 내기: Ingress 가 존재하지 않는 Secret 이름(shop-certificate)을 가리킨다
#    (admission webhook 이 막 뜬 직후에는 실패할 수 있어 몇 번 재시도한다)
for i in $(seq 1 10); do
  cat <<'YAML' | kubectl apply -f - && break
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
  namespace: shop
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - shop.cks.local
    secretName: shop-certificate
  rules:
  - host: shop.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop-web
            port:
              number: 80
YAML
  sleep 5
done
kubectl -n shop rollout status deploy shop-web --timeout=120s

# 5) 시작 상태 확인
kubectl -n shop get deploy,svc,secret,ingress
kubectl -n ingress-nginx get svc ingress-nginx-controller
