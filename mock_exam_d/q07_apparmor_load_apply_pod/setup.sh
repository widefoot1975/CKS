#!/usr/bin/env bash
# d07 — Load an AppArmor profile and apply it to a Pod · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

# 워커 노드 호스트에서 명령 실행 (privileged 파드 + nsenter). 사용: node_exec "<명령>"
W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}
node_exec() {
  kubectl delete pod node-exec-helper -n default --ignore-not-found --wait=true >/dev/null
  kubectl run node-exec-helper -n default --restart=Never --image=busybox:1.36 \
    --overrides='{"spec":{"nodeName":"'"$W"'","hostPID":true,"tolerations":[{"operator":"Exists"}],"containers":[{"name":"x","image":"busybox:1.36","command":["nsenter","-t","1","-m","-u","-i","-n","-p","--","sh","-c","'"${1//\"/\\\"}"'"],"securityContext":{"privileged":true}}]}}' >/dev/null
  kubectl wait pod/node-exec-helper -n default --for=jsonpath='{.status.phase}'=Succeeded --timeout=180s >/dev/null || true
  kubectl logs node-exec-helper -n default
  kubectl delete pod node-exec-helper -n default --ignore-not-found >/dev/null
}

# 0) 이전 실습 흔적 정리: Pod, 워커의 로드된 프로필
kubectl delete ns amber --ignore-not-found --wait=true
rm -rf /opt/course/d07
node_exec "apparmor_parser -R /etc/apparmor.d/d07-deny-write >/dev/null 2>&1; true"

# 1) 워커에 프로필 파일만 놓는다 (로드는 하지 않는다). 따옴표 없이 넘기려고 base64 로 전달
PROFILE=$(cat <<'EOF'
#include <tunables/global>

profile d07-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
EOF
)
B64=$(printf '%s\n' "$PROFILE" | base64 -w0)
node_exec "mkdir -p /etc/apparmor.d && echo $B64 | base64 -d > /etc/apparmor.d/d07-deny-write && echo profile-file-written; aa-status --enabled && echo apparmor=enabled || echo apparmor=DISABLED; true"

# 2) 빈 namespace 와 결과 디렉터리
kubectl create ns amber
mkdir -p /opt/course/d07

# 3) 시작 상태 확인: 파일은 있지만 로드되지 않았다
echo "worker: $W"
node_exec "ls -l /etc/apparmor.d/d07-deny-write; aa-status 2>/dev/null | grep -c d07-deny-write || true"
