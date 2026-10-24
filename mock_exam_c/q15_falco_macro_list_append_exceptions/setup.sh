#!/usr/bin/env bash
# c15 — Falco list, macro and a namespace exception · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 워커 노드 호스트에서 명령 실행 (privileged 파드 + nsenter). 사용: node_exec "<명령>"
W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}
node_exec() {
  kubectl delete pod node-exec-helper -n default --ignore-not-found --wait=true >/dev/null
  kubectl run node-exec-helper -n default --restart=Never --image=busybox:1.36 \
    --overrides='{"spec":{"nodeName":"'"$W"'","hostPID":true,"tolerations":[{"operator":"Exists"}],"containers":[{"name":"x","image":"busybox:1.36","command":["nsenter","-t","1","-m","-u","-i","-n","-p","--","sh","-c","'"${1//\"/\\\"}"'"],"securityContext":{"privileged":true}}]}}' >/dev/null
  kubectl wait pod/node-exec-helper -n default --for=jsonpath='{.status.phase}'=Succeeded --timeout=600s >/dev/null || true
  kubectl logs node-exec-helper -n default
  kubectl delete pod node-exec-helper -n default --ignore-not-found >/dev/null
}

# 0) 이전 실습 흔적 정리
kubectl delete ns web build --ignore-not-found --wait=true
rm -rf /opt/course/c15
mkdir -p /opt/course/c15

# 1) Falco 가 없으면 공식 apt 저장소에서 설치 (드라이버 modern_ebpf, 인터넷 필요)
node_exec "command -v falco >/dev/null && echo falco-present || ( curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor --yes -o /usr/share/keyrings/falco-archive-keyring.gpg && echo 'deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main' > /etc/apt/sources.list.d/falcosecurity.list && apt-get update -qq && FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf DEBIAN_FRONTEND=noninteractive apt-get install -y -qq falco && echo falco-installed )"

# 2) 설정 백업 (워커). 백업이 이미 있으면 그것으로 되돌려 깨끗한 상태에서 시작
node_exec "mkdir -p /opt/course/c15/backup; touch /etc/falco/falco_rules.local.yaml; if [ -f /opt/course/c15/backup/falco.yaml ]; then cp /opt/course/c15/backup/falco.yaml /etc/falco/falco.yaml; cp /opt/course/c15/backup/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml; else cp /etc/falco/falco.yaml /etc/falco/falco_rules.local.yaml /opt/course/c15/backup/; fi; rm -f /var/log/falco/c15-events.log; systemctl enable falco-modern-bpf >/dev/null 2>&1; systemctl restart falco-modern-bpf; sleep 5; systemctl is-active falco-modern-bpf"

# 3) 테스트 워크로드: 워커에 고정한 alpine (apk 포함)
for ns in web build; do
  kubectl create ns "$ns"
  cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tools
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tools
  template:
    metadata:
      labels:
        app: tools
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: alpine
        image: alpine:3.20
        command: ["sleep", "1d"]
YAML
done
kubectl -n web rollout status deploy/tools --timeout=180s
kubectl -n build rollout status deploy/tools --timeout=180s

# 4) 시작 상태 확인
kubectl get pod -n web -o wide
kubectl get pod -n build -o wide
