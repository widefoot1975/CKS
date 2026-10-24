#!/usr/bin/env bash
# b01 — L7 HTTP policy with CiliumNetworkPolicy · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# 0) Cilium 확인 (CiliumNetworkPolicy CRD 가 없으면 여기서 멈춘다)
kubectl get crd ciliumnetworkpolicies.cilium.io >/dev/null 2>&1 || { echo "Cilium(CiliumNetworkPolicy CRD)이 필요하다"; exit 1; }

# 1) 이전 실습 흔적 정리
kubectl delete ns orion --ignore-not-found --wait=true
rm -rf /opt/course/b01
mkdir -p /opt/course/b01
kubectl create ns orion

# 2) backend: 어떤 메서드·경로든 200 "backend" 로 응답하는 http-echo (8080)
kubectl -n orion create deploy backend --image=hashicorp/http-echo:1.0 --port=8080 -- /http-echo -listen=:8080 -text=backend
kubectl -n orion expose deploy backend --port=8080 --target-port=8080

# 3) 클라이언트 Pod 두 개 (라벨만 다르다)
kubectl -n orion run client --image=curlimages/curl:8.10.1 --labels=role=client --command -- sleep 1d
kubectl -n orion run intruder --image=curlimages/curl:8.10.1 --labels=role=guest --command -- sleep 1d

kubectl -n orion rollout status deploy backend --timeout=120s
kubectl -n orion wait pod/client pod/intruder --for=condition=Ready --timeout=120s

# 4) 시작 상태 확인: 정책이 없어 POST 도 200
kubectl -n orion get deploy,svc,pod --show-labels
kubectl -n orion exec client -- curl -s -m 3 -o /dev/null -w 'client POST -> %{http_code}\n' -X POST http://backend:8080/api/v1/items || true
