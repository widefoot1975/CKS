#!/usr/bin/env bash
# c17 — 실습 후 정리: kube-apiserver 원본 매니페스트 복구, 감사 정책·로그 삭제, 워커의 표식 파일 삭제
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

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/c17/backup/kube-apiserver.yaml

if [ -f "$BK" ]; then
  cp "$BK" "$MAN"
  echo "kube-apiserver 매니페스트 복구, API 서버 대기 중..."
  sleep 20   # kubelet 이 매니페스트 변경을 감지해 재시작할 시간
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
kubectl delete ns marketing --ignore-not-found --wait=true
node_exec "rm -f /tmp/.analytics-cache; echo cleaned"
rm -rf /etc/kubernetes/audit /var/log/kubernetes/audit /opt/course/c17
kubectl get --raw=/readyz; echo
