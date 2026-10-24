#!/usr/bin/env bash
# f04 — Remove a wildcard rule from a Role · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns finance --ignore-not-found --wait=true
rm -rf /opt/course/f04

# 1) namespace, ServiceAccount, Role 두 개, RoleBinding 두 개
#    app-manager 의 마지막 규칙이 와일드카드(모든 그룹·리소스·동사)다
kubectl create ns finance
mkdir -p /opt/course/f04
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: finance-app
  namespace: finance
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader
  namespace: finance
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-manager
  namespace: finance
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: finance-app-reader
  namespace: finance
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-reader
subjects:
- kind: ServiceAccount
  name: finance-app
  namespace: finance
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: finance-app-manager
  namespace: finance
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-manager
subjects:
- kind: ServiceAccount
  name: finance-app
  namespace: finance
YAML

# 2) 시작 상태 확인: Secret 삭제가 yes
kubectl -n finance get role,rolebinding
kubectl auth can-i delete secrets -n finance --as=system:serviceaccount:finance:finance-app || true
