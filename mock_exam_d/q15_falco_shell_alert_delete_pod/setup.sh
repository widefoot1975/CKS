#!/usr/bin/env bash
# d15 — Stop a Pod that Falco reports spawning shells · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요: Falco 설치)
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

# 0) 이전 실습 흔적 정리
kubectl delete ns garnet jet --ignore-not-found --wait=true
rm -rf /opt/course/d15

# 1) 워커에 Falco 설치(없을 때만) + 보안팀 규칙 배치 + 재시작
#    apt 설치가 helper 파드 제한 시간(180초)을 넘을 수 있어 systemd-run 으로 백그라운드 실행 후 완료 표시 파일을 기다린다
PREP=$(cat <<'EOF'
exec >/var/log/cks-d15-falco.log 2>&1
set -e
trap 'echo fail > /var/tmp/cks-d15-falco.done' ERR
if ! command -v falco >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor --yes -o /usr/share/keyrings/falco-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" > /etc/apt/sources.list.d/falcosecurity.list
  apt-get update -y
  FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf FALCOCTL_ENABLED=no apt-get install -y falco
  systemctl enable falco-modern-bpf.service
fi
mkdir -p /etc/falco/rules.d
cat > /etc/falco/rules.d/d15-shell.yaml <<'EOR'
# security team rule (CKS lab d15)
- rule: Shell spawned in container
  desc: A shell process was started inside a container outside kube-system/default
  condition: >
    spawned_process and container.id != host
    and proc.name in (ash, bash, dash, sh, zsh)
    and not k8s.ns.name in (kube-system, default)
  output: >
    Shell spawned in container (ns=%k8s.ns.name pod=%k8s.pod.name container=%container.id
    cmdline=%proc.cmdline user=%user.name)
  priority: WARNING
  tags: [cks, d15, shell]
EOR
grep -q 'rules.d' /etc/falco/falco.yaml || echo "WARN: /etc/falco/falco.yaml rules_files 에 /etc/falco/rules.d 가 없다"
systemctl restart falco-modern-bpf.service
sleep 5
systemctl is-active falco-modern-bpf.service
echo ok > /var/tmp/cks-d15-falco.done
EOF
)
B64=$(printf '%s\n' "$PREP" | base64 -w0)
node_exec "rm -f /var/tmp/cks-d15-falco.done; echo $B64 | base64 -d > /root/cks-d15-falco.sh; systemctl stop cks-d15-falco >/dev/null 2>&1; systemctl reset-failed cks-d15-falco >/dev/null 2>&1; systemd-run --unit=cks-d15-falco --collect sh /root/cks-d15-falco.sh; true"

echo "워커($W)에서 Falco 준비 대기 (최대 약 10분)..."
STATE=""
for i in $(seq 1 40); do
  STATE=$(node_exec "cat /var/tmp/cks-d15-falco.done 2>/dev/null; true" | tr -d '[:space:]')
  [ -n "$STATE" ] && break
  sleep 10
done
if [ "$STATE" != "ok" ]; then
  echo "Falco 준비 실패(state='${STATE}'). 워커의 /var/log/cks-d15-falco.log 를 확인한다."
  node_exec "tail -n 30 /var/log/cks-d15-falco.log; true"
  exit 1
fi

# 2) 워크로드: report-gen 만 15초마다 자식 셸을 띄운다. 나머지는 셸을 쓰지 않는다
kubectl create ns garnet
kubectl create ns jet
mkdir -p /opt/course/d15
# nodeSelector 의 WORKER 를 실제 워커 이름으로 바꿔 적용 (Falco 가 도는 노드에 고정)
cat <<'YAML' | sed "s/WORKER/$W/" | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-gen
  namespace: garnet
spec:
  replicas: 1
  selector:
    matchLabels: {app: report-gen}
  template:
    metadata:
      labels: {app: report-gen}
    spec:
      nodeSelector:
        kubernetes.io/hostname: WORKER
      containers:
      - name: report
        image: busybox:1.36
        command: ["sh", "-c", "while true; do sh -c 'date > /tmp/last-run'; sleep 15; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: garnet
spec:
  replicas: 1
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      nodeSelector:
        kubernetes.io/hostname: WORKER
      containers:
      - name: echo
        image: hashicorp/http-echo:1.0
        args: ["-text=garnet", "-listen=:8080"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ticker
  namespace: jet
spec:
  replicas: 1
  selector:
    matchLabels: {app: ticker}
  template:
    metadata:
      labels: {app: ticker}
    spec:
      nodeSelector:
        kubernetes.io/hostname: WORKER
      containers:
      - name: ticker
        image: busybox:1.36
        command: ["sleep", "86400"]
YAML
kubectl -n garnet rollout status deploy report-gen --timeout=180s
kubectl -n garnet rollout status deploy web --timeout=180s
kubectl -n jet rollout status deploy ticker --timeout=180s

# 3) 시작 상태 확인: 경보가 쌓이기 시작한다
sleep 20
node_exec "journalctl -u falco-modern-bpf --since '2 min ago' --no-pager | grep -c 'Shell spawned' ; true"
kubectl get deploy -n garnet
kubectl get deploy -n jet
