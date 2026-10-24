#!/usr/bin/env bash
# f08 — Remove a setuid bit and a login shell on a node · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# 워커 노드의 파일과 사용자는 privileged 파드(node_exec)로 다룬다.
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

# 0) 이전 실습 흔적 정리 (cks-c1 의 답안 디렉터리)
rm -rf /opt/course/f08
mkdir -p /opt/course/f08

# 1) 워커: setuid root 가 붙은 find 복사본 + 평범한 스크립트 하나 (미끼)
node_exec "cp /usr/bin/find /usr/local/bin/f08-find && chmod 4755 /usr/local/bin/f08-find && printf '#!/bin/sh\necho report\n' > /usr/local/bin/f08-report && chmod 755 /usr/local/bin/f08-report"

# 2) 워커: 로그인 셸이 bash 인 서비스 사용자 svc-backup
node_exec "id svc-backup >/dev/null 2>&1 || useradd -m -s /bin/bash svc-backup; usermod -s /bin/bash svc-backup"

# 3) 시작 상태 확인
echo "워커 노드: $W"
node_exec "ls -l /usr/local/bin/f08-find /usr/local/bin/f08-report; getent passwd svc-backup"
