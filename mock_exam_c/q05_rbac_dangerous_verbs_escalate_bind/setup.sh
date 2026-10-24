#!/usr/bin/env bash
# c05 — Remove dangerous RBAC permissions in a tenant namespace · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns tenant-x --ignore-not-found --wait=true
kubectl delete clusterrole tenant-x-helper --ignore-not-found
rm -rf /opt/course/c05

# 1) namespace 와 ServiceAccount
kubectl create ns tenant-x
for sa in ci auditor ops web; do kubectl -n tenant-x create sa "$sa"; done

# 2) Role / ClusterRole: 정상 규칙 사이에 위험한 규칙을 섞는다
cat <<'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-deployer
  namespace: tenant-x
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "update", "patch"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create", "get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: tenant-x
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-manager
  namespace: tenant-x
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings"]
  verbs: ["get", "list", "create"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles"]
  verbs: ["escalate"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: viewer
  namespace: tenant-x
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant-x-helper
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["impersonate"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles"]
  verbs: ["bind"]
YAML

# 3) 바인딩 (기본 ClusterRole view 는 함정용 — 제외 대상)
kubectl -n tenant-x create rolebinding ci-deployer     --role=ci-deployer          --serviceaccount=tenant-x:ci
kubectl -n tenant-x create rolebinding auditor-secrets --role=secret-reader        --serviceaccount=tenant-x:auditor
kubectl -n tenant-x create rolebinding ops-roles       --role=role-manager         --serviceaccount=tenant-x:ops
kubectl -n tenant-x create rolebinding ops-helper      --clusterrole=tenant-x-helper --serviceaccount=tenant-x:ops
kubectl -n tenant-x create rolebinding web-view        --role=viewer               --serviceaccount=tenant-x:web
kubectl -n tenant-x create rolebinding auditor-view    --clusterrole=view          --serviceaccount=tenant-x:auditor

mkdir -p /opt/course/c05

# 4) 시작 상태 확인
kubectl -n tenant-x get role,rolebinding
kubectl auth can-i bind clusterroles --as=system:serviceaccount:tenant-x:ops -n tenant-x || true
