#!/usr/bin/env bash
# e08 — 실습 후 정리 (워커에서 사용자와 vsftpd 를 지운다)
# 실행: sudo bash cleanup.sh
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

node_exec "systemctl stop e08-legacy-ftp 2>/dev/null; pkill -KILL -u legacy-ftp 2>/dev/null; sleep 1; userdel -r legacy-ftp 2>/dev/null; DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq vsftpd >/dev/null 2>&1; rm -f /tmp/e08-install.sh; echo done"
rm -rf /opt/course/e08
