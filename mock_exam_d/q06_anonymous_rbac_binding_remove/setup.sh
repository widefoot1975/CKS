#!/usr/bin/env bash
# d06 — Remove an anonymous RBAC binding · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 0) 이전 실습 흔적 정리
kubectl delete clusterrolebinding telemetry-readonly --ignore-not-found
rm -rf /opt/course/d06
mkdir -p /opt/course/d06

# 1) 익명 인증이 켜져 있는지 확인 (꺼져 있으면 이 문제는 401 만 보게 된다)
if grep -q -- '--anonymous-auth=false' /etc/kubernetes/manifests/kube-apiserver.yaml; then
  echo "경고: kube-apiserver 에 --anonymous-auth=false 가 있다. 익명 요청이 401 이 되어 문제를 재현할 수 없다."
fi

# 2) 고장 내기: system:anonymous 에 ClusterRole view 를 준다 (이름은 그럴듯하게)
cat <<'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: telemetry-readonly
  labels:
    team: observability
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: system:anonymous
YAML

# 3) 시작 상태 확인: 인증 없이 Pod 목록이 보인다 (200)
S=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo -n "anonymous GET pods: "
curl -sk -o /dev/null -w '%{http_code}\n' "$S/api/v1/namespaces/default/pods" || true
