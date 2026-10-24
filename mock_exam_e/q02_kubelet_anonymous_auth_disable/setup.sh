#!/usr/bin/env bash
# e02 — Disable anonymous access to the kubelet API · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
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

# 0) 이전 실습 흔적 정리 (cks-c1 쪽 답안 디렉터리)
rm -rf /opt/course/e02
mkdir -p /opt/course/e02

# 1) 워커: 원본 kubelet 설정 백업 (이미 백업이 있으면 그것으로 먼저 되돌린 뒤 다시 고장 낸다)
# 2) 고장 내기: 익명 인증 허용 + AlwaysAllow 인가
node_exec "mkdir -p /opt/course/e02/backup; if [ -f /opt/course/e02/backup/config.yaml ]; then cp /opt/course/e02/backup/config.yaml /var/lib/kubelet/config.yaml; else cp /var/lib/kubelet/config.yaml /opt/course/e02/backup/config.yaml; fi; sed -i '/^  anonymous:/,/enabled:/ s/enabled: false/enabled: true/' /var/lib/kubelet/config.yaml; sed -i 's/^  mode: Webhook/  mode: AlwaysAllow/' /var/lib/kubelet/config.yaml; systemctl restart kubelet; grep -A1 -E '^  anonymous:|^authorization:' /var/lib/kubelet/config.yaml"

# 3) kubelet 이 다시 Ready 가 될 때까지 대기
sleep 5
kubectl wait node "$W" --for=condition=Ready --timeout=120s

# 4) 시작 상태 확인: 인증서 없이도 파드 목록이 보인다
WIP=$(kubectl get node "$W" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -sk "https://$WIP:10250/pods" | head -c 120; echo
