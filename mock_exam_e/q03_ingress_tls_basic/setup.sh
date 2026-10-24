#!/usr/bin/env bash
# e03 — Add TLS to an Ingress with a self-signed certificate · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns shop --ignore-not-found --wait=true
rm -rf /opt/course/e03
mkdir -p /opt/course/e03

# 1) ingress-nginx 컨트롤러가 없으면 설치 (공용 구성요소, baremetal = NodePort, 인터넷 필요)
if ! kubectl -n ingress-nginx get deploy ingress-nginx-controller >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/baremetal/deploy.yaml
fi
kubectl -n ingress-nginx wait deploy/ingress-nginx-controller --for=condition=Available --timeout=300s

# 2) 백엔드: shop (http-echo, 80 → 8080)
kubectl create ns shop
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
  namespace: shop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop
    spec:
      containers:
      - name: shop
        image: hashicorp/http-echo:1.0
        args: ["-text=shop-e03", "-listen=:8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: shop
  namespace: shop
spec:
  selector:
    app: shop
  ports:
  - port: 80
    targetPort: 8080
YAML

# 3) HTTP 전용 Ingress (admission webhook 이 막 뜬 직후일 수 있어 몇 번 재시도)
for i in $(seq 1 10); do
  cat <<'YAML' | kubectl apply -f - && break
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
  namespace: shop
spec:
  ingressClassName: nginx
  rules:
  - host: shop.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop
            port:
              number: 80
YAML
  sleep 6
done

kubectl -n shop rollout status deploy shop --timeout=120s

# 4) 시작 상태 확인: Ingress 에 tls 가 없다 (PORTS 80)
kubectl -n shop get deploy,svc,ingress
kubectl -n ingress-nginx get svc ingress-nginx-controller
