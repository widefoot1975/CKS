#!/usr/bin/env bash
# d15 — 실습 후 정리 (워크로드와 규칙 파일 삭제, Falco 자체는 다른 문제도 쓰므로 남겨 둔다)
# 실행: sudo bash cleanup.sh
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

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

kubectl delete ns garnet jet --ignore-not-found --wait=true
node_exec "rm -f /etc/falco/rules.d/d15-shell.yaml /root/cks-d15-falco.sh /var/tmp/cks-d15-falco.done; systemctl restart falco-modern-bpf.service >/dev/null 2>&1; true"
rm -rf /opt/course/d15
