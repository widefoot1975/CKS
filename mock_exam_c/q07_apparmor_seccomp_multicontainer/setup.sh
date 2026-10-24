#!/usr/bin/env bash
# c07 — AppArmor and seccomp in a multi-container Pod · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
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
kubectl delete ns guard --ignore-not-found --wait=true
rm -rf /opt/course/c07
mkdir -p /opt/course/c07

# 1) AppArmor 프로필 파일 (쿠버네티스 문서의 예제와 같은 쓰기 금지 프로필)
cat <<'EOF' > /opt/course/c07/k8s-deny-write
#include <tunables/global>

profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
EOF

# 2) 워커에 같은 파일을 두고, 로드되어 있으면 내린다 (응시자가 직접 로드해야 함)
B64=$(base64 -w0 /opt/course/c07/k8s-deny-write)
node_exec "mkdir -p /opt/course/c07 && echo $B64 | base64 -d > /opt/course/c07/k8s-deny-write && (apparmor_parser -R /opt/course/c07/k8s-deny-write 2>/dev/null || true) && (aa-status 2>/dev/null | grep -c k8s-deny-write || true)"

# 3) baseline 을 강제하는 namespace
kubectl create ns guard
kubectl label ns guard pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=latest

# 4) 고장 난 매니페스트: 어노테이션 방식 AppArmor + sidecar 의 seccomp Unconfined + 노드 미지정
cat <<'YAML' > /opt/course/c07/dual.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dual
  namespace: guard
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: localhost/k8s-deny-write
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      seccompProfile:
        type: Unconfined
YAML

# 5) 시작 상태 확인: Pod 없음
kubectl get ns guard --show-labels
kubectl -n guard get pod
