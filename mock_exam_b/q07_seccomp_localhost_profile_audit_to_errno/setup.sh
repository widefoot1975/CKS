#!/usr/bin/env bash
# b07 — Turn a logging seccomp profile into a blocking one · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

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

# 0) 이전 실습 흔적 정리 (워커의 프로필 포함)
kubectl delete ns forge --ignore-not-found --wait=true
rm -rf /opt/course/b07
node_exec "rm -f /var/lib/kubelet/seccomp/profiles/no-chmod.json; mkdir -p /var/lib/kubelet/seccomp/profiles"
mkdir -p /opt/course/b07
kubectl create ns forge

# 1) 기록만 하는(SCMP_ACT_LOG) 프로필 초안
cat > /opt/course/b07/no-chmod.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": ["chmod", "fchmod", "fchmodat", "fchmodat2"],
      "action": "SCMP_ACT_LOG"
    }
  ]
}
EOF

# 2) securityContext 가 없는 Pod 매니페스트 (워커에 고정)
cat > /opt/course/b07/pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: chmod-test
  namespace: forge
spec:
  nodeSelector:
    kubernetes.io/hostname: $W
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "1d"]
  - name: helper
    image: busybox:1.36
    command: ["sleep", "1d"]
EOF

# 3) 시작 상태 확인
cat /opt/course/b07/pod.yaml
node_exec "ls -l /var/lib/kubelet/seccomp/profiles/"
