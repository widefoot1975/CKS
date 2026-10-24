#!/usr/bin/env bash
# a05 — Lock down ServiceAccount tokens and use an audience-bound projected token · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete clusterrolebinding ledger-ops-admin ledger-break-glass ledger-metrics-view --ignore-not-found
kubectl delete ns ledger --ignore-not-found --wait=true
rm -rf /opt/course/a05
mkdir -p /opt/course/a05

# 1) namespace, SA monitor
kubectl create ns ledger
kubectl -n ledger create sa monitor

# 2) 과도한 권한: SA default 에 직접, ledger 의 모든 SA(그룹)에 cluster-admin. view 바인딩은 정상(지우면 안 됨)
kubectl create clusterrolebinding ledger-ops-admin --clusterrole=cluster-admin --serviceaccount=ledger:default
kubectl create clusterrolebinding ledger-break-glass --clusterrole=cluster-admin --group=system:serviceaccounts:ledger
kubectl create clusterrolebinding ledger-metrics-view --clusterrole=view --serviceaccount=ledger:monitor

# 3) Deployment: Pod 수준에서 automountServiceAccountToken: true (SA 설정을 덮어쓰는 함정)
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger-api
  namespace: ledger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ledger-api
  template:
    metadata:
      labels:
        app: ledger-api
    spec:
      automountServiceAccountToken: true
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
YAML
kubectl -n ledger rollout status deploy ledger-api --timeout=120s

# 4) 시작 상태 확인: 기본 토큰이 마운트되어 있고 cluster-admin 권한이 있다
kubectl get clusterrolebinding -o wide | grep ledger
kubectl -n ledger exec deploy/ledger-api -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl auth can-i '*' '*' --as=system:serviceaccount:ledger:default || true
