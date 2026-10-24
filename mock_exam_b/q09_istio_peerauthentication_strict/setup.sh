#!/usr/bin/env bash
# b09 — Enforce Istio mTLS with PeerAuthentication STRICT · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}
ISTIO_VERSION=1.26.2

# 0) istioctl 설치 (없을 때만)
if ! command -v istioctl >/dev/null; then
  ( cd /tmp && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=x86_64 sh - )
  install -m 0755 /tmp/istio-$ISTIO_VERSION/bin/istioctl /usr/local/bin/istioctl
fi

# 1) Istio 컨트롤 플레인 (없을 때만, 프로필 minimal = istiod 만)
if ! kubectl -n istio-system get deploy istiod >/dev/null 2>&1; then
  istioctl install --set profile=minimal -y
fi
kubectl -n istio-system rollout status deploy istiod --timeout=300s

# 2) Cilium socket LB 설정 확인 (kube-proxy 대체 모드에서 사이드카 리다이렉트에 필요)
HNS=$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.bpf-lb-sock-hostns-only}' 2>/dev/null || true)
KPR=$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.kube-proxy-replacement}' 2>/dev/null || true)
if { [ "$KPR" = "true" ] || [ "$KPR" = "strict" ]; } && [ "$HNS" != "true" ]; then
  echo "경고: Cilium kube-proxy 대체 모드인데 bpf-lb-sock-hostns-only 가 true 가 아니다. 사이드카가 Service 트래픽을 못 가로챌 수 있다"
fi

# 3) 이전 실습 흔적 정리
kubectl delete ns bank outside --ignore-not-found --wait=true
rm -rf /opt/course/b09
mkdir -p /opt/course/b09

# 4) 워크로드 (아직 주입 라벨 없음)
kubectl create ns bank
kubectl create ns outside
kubectl -n bank create deploy ledger --image=nginx:1.27-alpine --port=80
kubectl -n bank expose deploy ledger --port=80
kubectl -n bank create deploy teller --image=curlimages/curl:8.10.1 -- sleep 1d
kubectl -n outside create deploy stranger --image=curlimages/curl:8.10.1 -- sleep 1d
kubectl -n bank rollout status deploy ledger --timeout=120s
kubectl -n bank rollout status deploy teller --timeout=120s
kubectl -n outside rollout status deploy stranger --timeout=120s

# 5) 시작 상태 확인: 모두 1/1, stranger 도 200
kubectl get ns bank outside -L istio-injection
kubectl -n bank get pod
kubectl -n outside exec deploy/stranger -- curl -s -m 3 -o /dev/null -w 'stranger -> %{http_code}\n' http://ledger.bank.svc.cluster.local || true
