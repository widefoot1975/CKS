#!/usr/bin/env bash
# c08 — Blacklist kernel modules and remove a telnet server · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
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

# 0) 이전 실습 흔적 정리: 차단 설정 파일 삭제 (워커)
node_exec "rm -f /etc/modprobe.d/cks-blacklist.conf; echo cleaned"
rm -rf /opt/course/c08
mkdir -p /opt/course/c08

# 1) telnet 서버 패키지 설치 (워커, 인터넷 필요)
node_exec "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq inetutils-telnetd >/dev/null 2>&1 && echo telnetd-installed || echo telnetd-install-failed"

# 2) 모듈 로드: 커널에 없는 모듈은 건너뛴다 (일부 배포판은 linux-modules-extra 필요)
node_exec "for m in dccp sctp rds tipc; do modprobe \$m 2>/dev/null && echo loaded:\$m || echo unavailable:\$m; done"

# 3) 시작 상태 확인
node_exec "lsmod | grep -E '^(dccp|sctp|rds|tipc) ' || true; dpkg -l | grep -i telnetd || true"
