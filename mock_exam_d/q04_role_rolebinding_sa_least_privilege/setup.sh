#!/usr/bin/env bash
# d04 — Least-privilege Role for a ServiceAccount · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete ns jade --ignore-not-found --wait=true
rm -rf /opt/course/d04

# 1) namespace, ServiceAccount, 읽을 대상 Pod
kubectl create ns jade
kubectl -n jade create serviceaccount reporter
kubectl -n jade run app-1 --image=nginx:1.27-alpine
kubectl -n jade run app-2 --image=nginx:1.27-alpine
kubectl -n jade create secret generic api-key --from-literal=key=d04-not-for-reporter
mkdir -p /opt/course/d04

# 2) 고장 내기: 이름만 봐서는 모르는 RoleBinding 으로 ClusterRole edit 을 준다
kubectl -n jade create rolebinding legacy-tools --clusterrole=edit --serviceaccount=jade:reporter

# 3) 시작 상태 확인: secrets 읽기, pod 삭제가 모두 yes
SA=system:serviceaccount:jade:reporter
for req in "list pods" "delete pods" "get secrets"; do
  # shellcheck disable=SC2086
  echo "$req: $(kubectl auth can-i $req -n jade --as=$SA || true)"
done
kubectl -n jade get sa,pod
