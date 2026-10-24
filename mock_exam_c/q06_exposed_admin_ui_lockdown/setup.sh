#!/usr/bin/env bash
# c06 — Lock down an exposed admin UI · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns ops --ignore-not-found --wait=true
kubectl delete clusterrolebinding ops-monitoring legacy-tooling --ignore-not-found
rm -rf /opt/course/c06

# 1) namespace, ServiceAccount
kubectl create ns ops
kubectl -n ops create sa admin-ui

# 2) 고장 내기 ①: 이름으로는 티가 안 나는 cluster-admin 바인딩 2개 (SA 직접 / SA 그룹)
kubectl create clusterrolebinding ops-monitoring --clusterrole=cluster-admin --serviceaccount=ops:admin-ui
kubectl create clusterrolebinding legacy-tooling --clusterrole=cluster-admin --group=system:serviceaccounts:ops

# 3) 고장 내기 ②: hostNetwork Deployment + NodePort Service
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-ui
  namespace: ops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: admin-ui
  template:
    metadata:
      labels:
        app: admin-ui
    spec:
      serviceAccountName: admin-ui
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: ui
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: admin-ui
  namespace: ops
spec:
  type: NodePort
  selector:
    app: admin-ui
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30880
YAML
kubectl -n ops rollout status deploy/admin-ui --timeout=180s
mkdir -p /opt/course/c06

# 4) 시작 상태 확인
kubectl -n ops get deploy,svc,pod -o wide
kubectl auth can-i delete nodes --as=system:serviceaccount:ops:admin-ui || true
