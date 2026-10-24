#!/usr/bin/env bash
# f07 — Switch an AppArmor profile from complain to enforce · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# 워커 노드의 파일과 AppArmor 는 privileged 파드(node_exec)로 다룬다.
set -euo pipefail

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

# 0) 이전 실습 흔적 정리
kubectl delete ns f07 --ignore-not-found --wait=true
rm -rf /opt/course/f07
node_exec "apparmor_parser -R /etc/apparmor.d/k8s-f07-readonly >/dev/null 2>&1; rm -f /etc/apparmor.d/k8s-f07-readonly; true"

# 1) 프로필: 쓰기 권한(w)을 주지 않는 허용 목록형 (deny 규칙은 complain 에서도 막으므로 쓰지 않는다)
PROFILE=$(cat <<'EOF'
#include <tunables/global>

profile k8s-f07-readonly flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  network,
  capability,
  signal,
  unix,
  ptrace,

  # 파일은 읽기·mmap·실행만 허용 (쓰기 규칙 없음)
  /** mrix,
}
EOF
)
B64=$(printf '%s\n' "$PROFILE" | base64 -w0)

# 2) 워커에 파일을 쓰고 complain 모드로 로드 (-C), 파일 자체에는 complain flag 가 없다
node_exec "echo $B64 | base64 -d > /etc/apparmor.d/k8s-f07-readonly && apparmor_parser -C -r /etc/apparmor.d/k8s-f07-readonly && grep k8s-f07 /sys/kernel/security/apparmor/profiles"

# 3) namespace 와 답안 디렉터리
kubectl create ns f07
mkdir -p /opt/course/f07

# 4) 시작 상태 확인
echo "워커 노드: $W (프로필 k8s-f07-readonly, complain 모드)"
kubectl -n f07 get pod
