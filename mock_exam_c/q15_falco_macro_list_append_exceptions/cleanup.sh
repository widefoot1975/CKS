#!/usr/bin/env bash
# c15 — 실습 후 정리: 워크로드 삭제, 워커의 Falco 설정을 백업본으로 복구 (Falco 자체는 남겨 둔다)
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

kubectl delete ns web build --ignore-not-found
node_exec "if [ -f /opt/course/c15/backup/falco.yaml ]; then cp /opt/course/c15/backup/falco.yaml /etc/falco/falco.yaml; cp /opt/course/c15/backup/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml; systemctl restart falco-modern-bpf; echo restored; fi; rm -f /var/log/falco/c15-events.log; rm -rf /opt/course/c15"
rm -rf /opt/course/c15
