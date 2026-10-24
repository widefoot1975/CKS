#!/usr/bin/env bash
# e15 — 실습 후 정리 (Falco 는 공용 구성요소라 지우지 않고, 로컬 규칙 파일만 백업본으로 되돌린다)
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

kubectl delete ns frontdesk --ignore-not-found
node_exec "if [ -f /opt/course/e15/backup/falco_rules.local.yaml ]; then cp /opt/course/e15/backup/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml; systemctl restart falco-modern-bpf 2>/dev/null; echo restored; fi; rm -rf /opt/course/e15 /tmp/cks-falco-install.sh"
rm -rf /opt/course/e15
