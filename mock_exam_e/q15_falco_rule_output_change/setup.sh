#!/usr/bin/env bash
# e15 — Change the output of a Falco rule with an override · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# Falco 가 워커에 없으면 falco.org 공식 apt 저장소로 설치한다 (인터넷 필요, 공용 구성요소)
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

# 오래 걸리는 작업은 워커의 systemd 임시 유닛으로 띄운다 (node_exec 파드가 끝나도 계속 돈다)
# 사용: node_bg <유닛이름> "<스크립트 내용>"   — 스크립트는 base64 로 넘겨 따옴표 문제를 피한다
node_bg() {
  local b64
  b64=$(printf '%s\n' "$2" | base64 -w0)
  node_exec "systemctl stop $1 2>/dev/null; systemctl reset-failed $1 2>/dev/null; echo $b64 | base64 -d > /tmp/$1.sh && systemd-run --unit=$1 --collect bash /tmp/$1.sh"
}

FALCO_INSTALL=$(cat <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor --yes -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" > /etc/apt/sources.list.d/falcosecurity.list
apt-get update -qq
FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf FALCOCTL_ENABLED=no apt-get install -y -qq falco
systemctl enable --now falco-modern-bpf
EOF
)

# 0) 이전 실습 흔적 정리 (cks-c1)
kubectl delete ns frontdesk --ignore-not-found --wait=true
rm -rf /opt/course/e15
mkdir -p /opt/course/e15

# 1) 워커에 Falco(modern_ebpf)가 없으면 설치하고 서비스가 active 가 될 때까지 대기
if ! node_exec "command -v falco >/dev/null && echo yes" | grep -qx yes; then
  echo "워커에 Falco 설치 중 ... (최대 10분)"
  node_bg cks-falco-install "$FALCO_INSTALL"
fi
ok=""
for i in $(seq 1 60); do
  st=$(node_exec "systemctl is-active falco-modern-bpf 2>/dev/null || systemctl start falco-modern-bpf 2>/dev/null; systemctl is-active falco-modern-bpf 2>/dev/null" | tail -1 || true)
  [ "$st" = active ] && { ok=1; break; }
  sleep 10
done
[ -n "$ok" ] || { echo "falco-modern-bpf 가 active 가 아니다: 워커에서 journalctl -u cks-falco-install / -u falco-modern-bpf 확인" >&2; exit 1; }

# 2) 워커: 로컬 규칙 파일 백업 (이미 백업이 있으면 그것으로 먼저 되돌린다) + 기본 규칙 파일 체크섬
node_exec "mkdir -p /opt/course/e15/backup; touch /etc/falco/falco_rules.local.yaml; if [ -f /opt/course/e15/backup/falco_rules.local.yaml ]; then cp /opt/course/e15/backup/falco_rules.local.yaml /etc/falco/falco_rules.local.yaml; else cp /etc/falco/falco_rules.local.yaml /opt/course/e15/backup/falco_rules.local.yaml; fi; md5sum /etc/falco/falco_rules.yaml > /opt/course/e15/backup/falco_rules.yaml.md5; systemctl restart falco-modern-bpf; sleep 3; systemctl is-active falco-modern-bpf"

# 3) 셸을 열어 볼 대상 파드 (Falco 가 도는 워커에 고정)
kubectl create ns frontdesk
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: shell-target
  namespace: frontdesk
spec:
  nodeName: $W
  containers:
  - name: shell-target
    image: nginx:1.27-alpine
YAML
kubectl -n frontdesk wait pod shell-target --for=condition=Ready --timeout=120s

# 4) 시작 상태 확인
kubectl -n frontdesk get pod -o wide
node_exec "grep -c 'Terminal shell in container' /etc/falco/falco_rules.local.yaml || true"
