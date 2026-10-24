#!/usr/bin/env bash
# a15 — Falco rule for shells spawned in payment containers · 사전 환경 설정
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
# 여러 줄 스크립트(표준입력)를 base64 로 감싸 워커에서 실행. 사용: worker_sh <<'EOF' ... EOF
worker_sh() { node_exec "echo $(base64 -w0) | base64 -d | sh"; }

# 0) 이전 실습 흔적 정리 (cks-c1)
kubectl delete ns payments billing --ignore-not-found --wait=true
rm -rf /opt/course/a15
mkdir -p /opt/course/a15

# 1) 워커: Falco 설치(없을 때만, falco.org 공식 apt 저장소, 드라이버 modern_ebpf)
#    설치가 수 분 걸릴 수 있어 helper 파드가 아니라 워커의 systemd 임시 유닛(systemd-run)으로 돌리고 끝날 때까지 기다린다.
worker_sh <<'EOF'
set -e
command -v falco >/dev/null 2>&1 && { echo "falco already installed"; exit 0; }
systemctl is-active --quiet cks-a15-falco-install 2>/dev/null && { echo "falco install already running"; exit 0; }
mkdir -p /opt/course/a15
cat > /opt/course/a15/install-falco.sh <<'INST'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl gnupg
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" > /etc/apt/sources.list.d/falcosecurity.list
apt-get update -qq
FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y -qq falco
INST
systemctl reset-failed cks-a15-falco-install >/dev/null 2>&1 || true
systemd-run --unit=cks-a15-falco-install /bin/sh /opt/course/a15/install-falco.sh
echo "falco install started"
EOF
for i in $(seq 1 60); do
  if node_exec 'command -v falco >/dev/null 2>&1 && ! systemctl is-active --quiet cks-a15-falco-install && echo FALCO_READY' | grep -q FALCO_READY; then break; fi
  echo "Falco 설치 대기 중... ($i/60)"; sleep 10
done

# 2) 워커: 로컬 규칙 파일 백업(처음 한 번) 후 주석만 남기고 초기화, 서비스 재시작
worker_sh <<'EOF'
set -e
command -v falco >/dev/null 2>&1 || { echo "ERROR: falco 가 설치되지 않았다 (journalctl -u cks-a15-falco-install 확인)"; exit 1; }
mkdir -p /opt/course/a15/backup
if [ ! -f /opt/course/a15/backup/falco_rules.local.yaml ]; then
  if [ -f /etc/falco/falco_rules.local.yaml ]; then cp /etc/falco/falco_rules.local.yaml /opt/course/a15/backup/; else : > /opt/course/a15/backup/falco_rules.local.yaml; fi
fi
cat > /etc/falco/falco_rules.local.yaml <<'RULES'
# Local Falco rules. This file is loaded after /etc/falco/falco_rules.yaml
# and is not overwritten by package upgrades. Add your custom rules below.
RULES
systemctl enable falco-modern-bpf.service >/dev/null 2>&1 || true
systemctl restart falco-modern-bpf.service
sleep 3
systemctl is-active falco-modern-bpf.service
falco --version | head -1
EOF

# 3) 워크로드: payments-worker(10초마다 sh 실행), payments-web(셸 없음), billing-worker(다른 ns, sh 실행)
kubectl create ns payments
kubectl create ns billing
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-worker
  namespace: payments
spec:
  replicas: 1
  selector:
    matchLabels: {app: payments-worker}
  template:
    metadata:
      labels: {app: payments-worker}
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "while true; do sh -c 'echo settle > /dev/null'; sleep 10; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-web
  namespace: payments
spec:
  replicas: 1
  selector:
    matchLabels: {app: payments-web}
  template:
    metadata:
      labels: {app: payments-web}
    spec:
      containers:
      - name: web
        image: hashicorp/http-echo:1.0
        args: ["-text=payments"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-worker
  namespace: billing
spec:
  replicas: 1
  selector:
    matchLabels: {app: billing-worker}
  template:
    metadata:
      labels: {app: billing-worker}
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "while true; do sh -c 'echo invoice > /dev/null'; sleep 10; done"]
YAML
kubectl -n payments rollout status deploy payments-worker --timeout=120s
kubectl -n payments rollout status deploy payments-web --timeout=120s
kubectl -n billing rollout status deploy billing-worker --timeout=120s

# 4) 시작 상태 확인
kubectl get deploy -n payments
kubectl get deploy -n billing
