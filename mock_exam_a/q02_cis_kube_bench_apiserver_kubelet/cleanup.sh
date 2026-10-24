#!/usr/bin/env bash
# a02 — 실습 후 정리 (원본 apiserver 매니페스트와 워커 kubelet 설정 복구)
# 실행: sudo bash cleanup.sh
# kube-bench 는 다른 문항도 쓰므로 지우지 않는다.
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a02/backup

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

wait_new_apiserver() {
  local old=$1 cur
  for i in $(seq 1 90); do
    cur=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
    if [ -n "$cur" ] && [ "$cur" != "$old" ]; then break; fi
    sleep 2
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

# 1) apiserver 매니페스트 복구 (내용이 다를 때만 → 재기동 대기)
if [ -f "$BK/kube-apiserver.yaml" ] && ! cmp -s "$BK/kube-apiserver.yaml" "$MANIFEST"; then
  OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
  cp "$BK/kube-apiserver.yaml" "$MANIFEST"
  wait_new_apiserver "$OLD"
fi
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

# 2) 워커 kubelet 설정 복구 후 재시작
node_exec 'if [ -f /opt/course/a02/backup/config.yaml ]; then cp /opt/course/a02/backup/config.yaml /var/lib/kubelet/config.yaml; fi; rm -rf /opt/course/a02; systemctl restart kubelet; echo kubelet restored'

rm -rf /opt/course/a02
kubectl get nodes
