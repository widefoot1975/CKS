#!/usr/bin/env bash
# f15 — Falco rule for writes below /etc · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# 워커에 Falco 가 없으면 falco.org 공식 apt 저장소로 설치하므로 인터넷 연결이 필요하다 (수 분).
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

# 0) 이전 실습 흔적 정리
kubectl delete ns f15 --ignore-not-found --wait=true
rm -rf /opt/course/f15
mkdir -p /opt/course/f15

# 1) Falco 설치 (없을 때만) — 설치가 오래 걸리므로 systemd-run 으로 호스트에서 백그라운드 실행 후 기다린다
if ! node_exec "command -v falco || true" | grep falco >/dev/null; then
  echo "워커 $W 에 Falco 설치 중 (modern_ebpf) ..."
  INSTALL="curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --yes --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg && echo 'deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main' > /etc/apt/sources.list.d/falcosecurity.list && apt-get update -y && DEBIAN_FRONTEND=noninteractive FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco && systemctl enable --now falco-modern-bpf.service"
  node_exec "systemd-run --unit=f15-falco-install --collect sh -c \"$INSTALL\"; true"
  for i in $(seq 1 60); do
    node_exec "systemctl is-active falco-modern-bpf.service 2>/dev/null; true" | grep -x active >/dev/null && break
    sleep 10
  done
fi

# 2) local 규칙 파일: 처음이면 백업, 백업이 있으면 원본으로 되돌린 뒤 Falco 재시작
node_exec "touch /etc/falco/falco_rules.local.yaml; if [ -f /etc/falco/falco_rules.local.yaml.f15.bak ]; then cp /etc/falco/falco_rules.local.yaml.f15.bak /etc/falco/falco_rules.local.yaml; else cp /etc/falco/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml.f15.bak; fi; systemctl restart falco-modern-bpf.service; sleep 5; systemctl is-active falco-modern-bpf.service; true"

# 3) 워크로드: config-writer 는 컨테이너의 /etc 아래 파일에 10초마다 쓰고, config-reader 는 읽기만 한다
kubectl create ns f15
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-writer
  namespace: f15
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-writer
  template:
    metadata:
      labels:
        app: config-writer
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${W}
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date >> /etc/f15-app.conf; sleep 10; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-reader
  namespace: f15
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-reader
  template:
    metadata:
      labels:
        app: config-reader
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${W}
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "while true; do cat /etc/hostname > /dev/null; sleep 10; done"]
YAML
kubectl -n f15 rollout status deploy config-writer --timeout=120s
kubectl -n f15 rollout status deploy config-reader --timeout=120s

# 4) 시작 상태 확인
echo "워커 노드: $W"
node_exec "systemctl is-active falco-modern-bpf.service; falco --version | head -1; true"
kubectl -n f15 get pod -o wide
