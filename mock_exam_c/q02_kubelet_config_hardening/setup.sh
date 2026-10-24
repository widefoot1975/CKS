#!/usr/bin/env bash
# c02 — Harden the worker kubelet configuration · 사전 환경 설정
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

CFG=/var/lib/kubelet/config.yaml
BK=/opt/course/c02/backup/config.yaml

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본으로 되돌린 뒤 다시 시작 (워커)
node_exec "if [ -f $BK ]; then cp $BK $CFG; else mkdir -p /opt/course/c02/backup && cp $CFG $BK; fi; echo backup-ok"
rm -rf /opt/course/c02
mkdir -p /opt/course/c02

# 1) 고장 내기 (워커): 익명 허용, webhook 인증 끔, AlwaysAllow, readOnlyPort 10255, 인증서 회전 끔
node_exec "sed -i '/^  anonymous:/{n;s/enabled: false/enabled: true/}' $CFG; \
sed -i '/^authentication:/,/^authorization:/{/^  webhook:/,/enabled:/s/enabled: true/enabled: false/}' $CFG; \
sed -i 's/^  mode: Webhook/  mode: AlwaysAllow/' $CFG; \
sed -i '/^readOnlyPort:/d' $CFG; echo 'readOnlyPort: 10255' >> $CFG; \
if grep -q '^rotateCertificates:' $CFG; then sed -i 's/^rotateCertificates:.*/rotateCertificates: false/' $CFG; else echo 'rotateCertificates: false' >> $CFG; fi; \
systemctl restart kubelet; sleep 5; systemctl is-active kubelet"

# 2) 노드가 다시 Ready 가 될 때까지 대기
sleep 10
kubectl wait node/"$W" --for=condition=Ready --timeout=180s

# 3) 시작 상태 확인: 인증 없이 Pod 목록이 보인다
NODE_IP=$(kubectl get node "$W" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -sk -o /dev/null -w "10250/pods (anonymous): %{http_code}\n" "https://$NODE_IP:10250/pods" || true
curl -s -m 3 -o /dev/null -w "10255/pods: %{http_code}\n" "http://$NODE_IP:10255/pods" || true
