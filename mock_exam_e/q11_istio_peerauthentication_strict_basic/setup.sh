#!/usr/bin/env bash
# e11 — Enforce mTLS STRICT with Istio PeerAuthentication · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요)
set -euo pipefail

ISTIO_VERSION=1.26.2

# 0) 이전 실습 흔적 정리
kubectl delete ns mesh-app legacy --ignore-not-found --wait=true
rm -rf /opt/course/e11
mkdir -p /opt/course/e11

# 1) istioctl / Istio 컨트롤 플레인이 없으면 설치 (공용 구성요소, profile minimal = istiod 만)
if ! command -v istioctl >/dev/null; then
  curl -fsSL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istioctl-${ISTIO_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin istioctl
  chmod +x /usr/local/bin/istioctl
fi
if ! kubectl -n istio-system get deploy istiod >/dev/null 2>&1; then
  istioctl install --set profile=minimal -y
fi
kubectl -n istio-system rollout status deploy istiod --timeout=300s

# 2) 메시 namespace: 사이드카 자동 주입 라벨 → api + client
kubectl create ns mesh-app
kubectl label ns mesh-app istio-injection=enabled
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: mesh-app
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
        args: ["-text=mesh-api", "-listen=:8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: mesh-app
spec:
  selector:
    app: api
  ports:
  - name: http
    port: 80
    targetPort: 8080
YAML
kubectl -n mesh-app run client --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 1d

# 3) 메시 밖 namespace: 사이드카 없는 client
kubectl create ns legacy
kubectl -n legacy run client --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 1d

kubectl -n mesh-app rollout status deploy api --timeout=180s
kubectl -n mesh-app wait pod client --for=condition=Ready --timeout=180s
kubectl -n legacy wait pod client --for=condition=Ready --timeout=120s

# 4) 시작 상태 확인: 사이드카(2/2) 확인, PERMISSIVE 라서 legacy 에서도 응답이 온다
kubectl -n mesh-app get pod
kubectl get peerauthentication -A 2>/dev/null || true
kubectl -n legacy exec client -- curl -s -m 5 http://api.mesh-app || true
