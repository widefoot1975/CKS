#!/usr/bin/env bash
# a03 — TLS Ingress with a SAN certificate and a forced HTTPS redirect · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) openssl 확인
command -v openssl >/dev/null || { echo "openssl 이 필요하다"; exit 1; }

# 1) ingress-nginx controller-v1.12.1 (baremetal = NodePort). 이미 있으면 그대로 쓴다 (인터넷 필요)
if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/baremetal/deploy.yaml
fi
kubectl -n ingress-nginx rollout status deploy ingress-nginx-controller --timeout=300s
kubectl -n ingress-nginx wait --for=condition=complete job --all --timeout=180s || true

# 2) 이전 실습 흔적 정리 후 namespace shop
kubectl delete ns shop --ignore-not-found --wait=true
rm -rf /opt/course/a03
mkdir -p /opt/course/a03
kubectl create ns shop

# 3) 백엔드: http-echo(5678) → Service :80
kubectl -n shop create deploy shop-web --image=hashicorp/http-echo:1.0 -- /http-echo -text=shop-ok
kubectl -n shop expose deploy shop-web --port=80 --target-port=5678
kubectl -n shop rollout status deploy shop-web --timeout=120s

# 4) 시작 상태 확인: Service 만 있고 Secret·Ingress 는 없다
kubectl get ingressclass
kubectl -n ingress-nginx get svc ingress-nginx-controller
kubectl -n shop get deploy,svc,secret,ingress
