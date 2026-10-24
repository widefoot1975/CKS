#!/usr/bin/env bash
# a15 — 실습 후 정리 (워크로드 삭제, 워커의 로컬 규칙 파일 복구 후 Falco 재시작)
# 실행: sudo bash cleanup.sh
# Falco 자체는 다른 문항도 쓰므로 지우지 않는다.
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

kubectl delete ns payments billing --ignore-not-found
node_exec 'if [ -f /opt/course/a15/backup/falco_rules.local.yaml ]; then cp /opt/course/a15/backup/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml; fi; rm -rf /opt/course/a15; systemctl restart falco-modern-bpf.service 2>/dev/null; echo falco local rules restored'
rm -rf /opt/course/a15
