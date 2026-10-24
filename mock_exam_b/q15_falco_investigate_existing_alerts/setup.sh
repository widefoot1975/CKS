#!/usr/bin/env bash
# b15 — Investigate existing Falco alerts · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
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

# 0) Falco 설치 (워커에 없을 때만). 설치가 오래 걸리므로 systemd-run 으로 워커에서 백그라운드 실행 후 대기
if [ "$(node_exec 'command -v falco >/dev/null && echo yes || echo no')" != "yes" ]; then
  INSTALL=$(cat <<'EOS'
#!/bin/bash
set -e
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" > /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
DEBIAN_FRONTEND=noninteractive FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
systemctl enable --now falco-modern-bpf.service
EOS
)
  B64=$(printf '%s\n' "$INSTALL" | base64 -w0)
  node_exec "echo $B64 | base64 -d > /tmp/cks-falco-install.sh; systemd-run --unit=cks-falco-install --collect bash /tmp/cks-falco-install.sh; true"
  echo "Falco 설치 중 (최대 10분)..."
  for i in $(seq 1 40); do
    [ "$(node_exec 'systemctl is-active falco-modern-bpf 2>/dev/null || true')" = "active" ] && break
    sleep 15
  done
fi
node_exec "systemctl is-active falco-modern-bpf || systemctl restart falco-modern-bpf; true"

# 1) 이전 실습 흔적 정리: 로컬 규칙 파일 원복 후 다시 백업
kubectl delete ns retail logistics --ignore-not-found --wait=true
rm -rf /opt/course/b15
mkdir -p /opt/course/b15
node_exec "if [ -d /opt/course/b15/backup ]; then if [ -f /opt/course/b15/backup/falco_rules.local.yaml ]; then cp -p /opt/course/b15/backup/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml; else rm -f /etc/falco/falco_rules.local.yaml; fi; systemctl restart falco-modern-bpf; fi; rm -rf /opt/course/b15; mkdir -p /opt/course/b15/backup; if [ -f /etc/falco/falco_rules.local.yaml ]; then cp -p /etc/falco/falco_rules.local.yaml /opt/course/b15/backup/; fi; true"

# 2) 워크로드 (모두 워커에 고정). cache·tracker 가 수상한 행동을 반복한다
kubectl create ns retail
kubectl create ns logistics
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: retail
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: cache
        image: nginx:1.27-alpine
        command: ["sh", "-c", "while true; do cat /etc/shadow >/dev/null; sleep 20; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storefront
  namespace: retail
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storefront
  template:
    metadata:
      labels:
        app: storefront
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: storefront
        image: nginx:1.27-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tracker
  namespace: logistics
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tracker
  template:
    metadata:
      labels:
        app: tracker
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: tracker
        image: busybox:1.36
        command: ["sh", "-c", "while true; do cp /bin/busybox /tmp/ls; /tmp/ls / >/dev/null; sleep 20; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: router
  namespace: logistics
spec:
  replicas: 1
  selector:
    matchLabels:
      app: router
  template:
    metadata:
      labels:
        app: router
    spec:
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: router
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date; sleep 30; done"]
YAML
for d in cache storefront; do kubectl -n retail rollout status deploy $d --timeout=120s; done
for d in tracker router; do kubectl -n logistics rollout status deploy $d --timeout=120s; done

# 3) 경고가 쌓일 시간을 준다
echo "Falco 경고가 쌓이도록 60초 대기..."
sleep 60
kubectl get pod -n retail -o wide
kubectl get pod -n logistics -o wide
