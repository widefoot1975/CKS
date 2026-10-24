#!/usr/bin/env bash
# c08 — 실습 후 정리: 차단 설정 삭제, setup 이 설치한 telnet 서버 패키지 제거 (워커)
# 실행: sudo bash cleanup.sh
set -euo pipefail

# 워커 노드 호스트에서 명령 실행 (privileged 파드 + nsenter). 사용: node_exec "<명령>"
W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}
node_exec() {
  kubectl delete pod node-exec-helper -n default --ignore-not-found --wait=true >/dev/null
  kubectl run node-exec-helper -n default --restart=Never --image=busybox:1.36 \
    --overrides='{"spec":{"nodeName":"'"$W"'","hostPID":true,"tolerations":[{"operator":"Exists"}],"containers":[{"name":"x","image":"busybox:1.36","command":["nsenter","-t","1","-m","-u","-i","-n","-p","--","sh","-c","'"${1//\"/\\\"}"'"],"securityContext":{"privileged":true}}]}}' >/dev/null
  kubectl wait pod/node-exec-helper -n default --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s >/dev/null || true
  kubectl logs node-exec-helper -n default
  kubectl delete pod node-exec-helper -n default --ignore-not-found >/dev/null
}

node_exec "rm -f /etc/modprobe.d/cks-blacklist.conf; export DEBIAN_FRONTEND=noninteractive; (dpkg -s inetutils-telnetd >/dev/null 2>&1 && apt-get purge -y -qq inetutils-telnetd >/dev/null 2>&1); for m in dccp sctp rds tipc; do modprobe -r \$m 2>/dev/null || true; done; echo done"
rm -rf /opt/course/c08
