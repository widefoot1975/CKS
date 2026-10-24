#!/usr/bin/env bash
# d01 — Default-deny ingress with one allowed client · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# root 로 실행할 때 kubectl 이 admin kubeconfig 를 쓰게 한다
[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns ruby --ignore-not-found --wait=true
rm -rf /opt/course/d01

# 1) 서버 Deployment 와 Service
kubectl create ns ruby
kubectl -n ruby create deployment web --image=nginx:1.27-alpine --port=80
kubectl -n ruby expose deployment web --port=80 --target-port=80

# 2) 클라이언트 두 개: 허용할 client(role=client), 막을 stranger(role=guest)
kubectl -n ruby run client --image=curlimages/curl:8.10.1 --labels=role=client --command -- sleep 86400
kubectl -n ruby run stranger --image=curlimages/curl:8.10.1 --labels=role=guest --command -- sleep 86400
mkdir -p /opt/course/d01

# 3) 시작 상태 확인: 정책이 없으므로 둘 다 200
kubectl -n ruby rollout status deploy web --timeout=180s
kubectl -n ruby wait --for=condition=Ready pod --all --timeout=180s
kubectl -n ruby get pod,svc,netpol --show-labels
for p in client stranger; do
  echo -n "$p → web: "
  kubectl -n ruby exec "$p" -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://web || true
done
