#!/usr/bin/env bash
# b08 — 실습 후 정리 (워커의 사용자·sshd drop-in·심어 둔 파일 제거)
# 실행: sudo bash cleanup.sh
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

node_exec "if id ops-tmp >/dev/null 2>&1; then userdel -r ops-tmp 2>/dev/null; fi; if [ -f /var/lib/cks-b08-docker-group ]; then groupdel docker; rm -f /var/lib/cks-b08-docker-group; fi; rm -f /etc/ssh/sshd_config.d/50-legacy.conf /etc/ssh/sshd_config.d/00-cks-hardening.conf /usr/local/bin/netdiag /usr/local/bin/report-mail /usr/local/bin/rotate-logs; sshd -t && (systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true); true"
rm -rf /opt/course/b08
