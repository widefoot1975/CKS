#!/usr/bin/env bash
# c01 — Allow ingress only from the Ingress controller and restrict egress · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns shop --ignore-not-found --wait=true
kubectl delete pod outsider -n default --ignore-not-found --wait=true
rm -rf /opt/course/c01

# 1) ingress-nginx 가 없으면 설치 (공용 구성요소, cleanup 이 지우지 않는다)
if ! kubectl get deploy ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/baremetal/deploy.yaml
fi
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s

# 2) 앱: web(Deployment+Service+Ingress), 테스트 Pod tester
kubectl create ns shop
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: shop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
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
  name: web
  namespace: shop
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
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
            name: web
            port:
              number: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: tester
  namespace: shop
  labels:
    app: tester
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.10.1
    command: ["sleep", "1d"]
YAML

# 3) 다른 namespace 의 클라이언트
kubectl run outsider -n default --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 1d

kubectl -n shop rollout status deploy/web --timeout=180s
kubectl -n shop wait pod/tester --for=condition=Ready --timeout=180s
kubectl -n default wait pod/outsider --for=condition=Ready --timeout=180s
mkdir -p /opt/course/c01

# 4) 시작 상태 확인: NetworkPolicy 없음
kubectl -n shop get deploy,svc,ingress,pod,netpol
