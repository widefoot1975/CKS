#!/usr/bin/env bash
# b04 — Find and replace excessive RBAC bindings · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# 0) 이전 실습 흔적 정리 (클러스터 범위 리소스는 직접 지운다)
kubectl delete clusterrolebinding web-cluster-admin apps-secret-ops prom-view --ignore-not-found
kubectl delete clusterrole secret-ops --ignore-not-found
kubectl delete ns apps observe --ignore-not-found --wait=true
rm -rf /opt/course/b04
mkdir -p /opt/course/b04

# 1) namespace 와 ServiceAccount
kubectl create ns apps
kubectl create ns observe
for sa in web worker reporter; do kubectl -n apps create sa $sa; done
kubectl -n observe create sa prom

# 2) 과도한 권한 세 가지 + 정상 바인딩 두 개(함정용)
cat <<'YAML' | kubectl apply -f -
# (a) SA 직접 → cluster-admin
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: web-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: web
  namespace: apps
---
# (b) namespace 안의 와일드카드 Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: worker-full
  namespace: apps
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: worker-full
  namespace: apps
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: worker-full
subjects:
- kind: ServiceAccount
  name: worker
  namespace: apps
---
# (c) 그룹 system:serviceaccounts:apps → secrets 에 verb *
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-ops
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: apps-secret-ops
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: secret-ops
subjects:
- kind: Group
  name: system:serviceaccounts:apps
  apiGroup: rbac.authorization.k8s.io
---
# (정상) reporter 는 configmaps 읽기만
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: reporter-cm
  namespace: apps
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: reporter-cm
  namespace: apps
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: reporter-cm
subjects:
- kind: ServiceAccount
  name: reporter
  namespace: apps
---
# (관련 없음) 다른 namespace 의 SA → view
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prom-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: ServiceAccount
  name: prom
  namespace: observe
YAML

# 3) 시작 상태 확인
kubectl -n apps get sa,role,rolebinding
kubectl auth can-i delete secrets -n kube-system --as=system:serviceaccount:apps:reporter
