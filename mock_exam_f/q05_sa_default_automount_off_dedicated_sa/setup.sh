#!/usr/bin/env bash
# f05 — Disable token automount on the default ServiceAccount · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns hr --ignore-not-found --wait=true
rm -rf /opt/course/f05

# 1) namespace 와 Deployment 두 개 (둘 다 default SA, 토큰 자동 마운트 상태)
kubectl create ns hr
mkdir -p /opt/course/f05
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hr-portal
  namespace: hr
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hr-portal
  template:
    metadata:
      labels:
        app: hr-portal
    spec:
      containers:
      - name: portal
        image: curlimages/curl:8.10.1
        command: ["sleep", "86400"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hr-static
  namespace: hr
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hr-static
  template:
    metadata:
      labels:
        app: hr-static
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
---
# 2) hr-portal 이 쓸 권한: 아직 없는 SA hr-portal-sa 에 미리 바인딩해 둔다
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: portal-api
  namespace: hr
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: portal-api
  namespace: hr
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: portal-api
subjects:
- kind: ServiceAccount
  name: hr-portal-sa
  namespace: hr
YAML
kubectl -n hr rollout status deploy hr-portal --timeout=120s
kubectl -n hr rollout status deploy hr-static --timeout=120s

# 3) 시작 상태 확인: 두 Pod 모두 토큰이 마운트되어 있다
kubectl -n hr get deploy,sa,role,rolebinding
kubectl -n hr exec deploy/hr-static -- ls /var/run/secrets/kubernetes.io/serviceaccount
