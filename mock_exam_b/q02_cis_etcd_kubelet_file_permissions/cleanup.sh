#!/usr/bin/env bash
# b02 — 실습 후 정리 (etcd 매니페스트·데이터 디렉터리 권한·워커 kubelet 설정 원복)
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

BK=/opt/course/b02/backup
if [ -f $BK/etcd.yaml ]; then
  cp $BK/etcd.yaml /etc/kubernetes/manifests/etcd.yaml
  sleep 20
fi
if [ -f $BK/etcd-dir.mode ]; then chmod "$(cat $BK/etcd-dir.mode)" /var/lib/etcd; fi
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

node_exec "if [ -f /opt/course/b02/backup/config.yaml ]; then cp -p /opt/course/b02/backup/config.yaml /var/lib/kubelet/config.yaml; systemctl restart kubelet; fi; rm -rf /opt/course/b02"
kubectl wait node "$W" --for=condition=Ready --timeout=120s || true
rm -rf /opt/course/b02
# kube-bench 는 다른 문항도 쓰므로 지우지 않는다
