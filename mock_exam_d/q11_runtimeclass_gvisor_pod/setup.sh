#!/usr/bin/env bash
# d11 — Run a Pod in gVisor with a RuntimeClass · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요: gVisor 설치)
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
kubectl delete ns onyx --ignore-not-found --wait=true
kubectl delete runtimeclass gvisor --ignore-not-found
rm -rf /opt/course/d11

# 1) 워커에 gVisor(runsc) + containerd 핸들러 runsc 준비 (이미 있으면 건너뛴다)
#    apt 설치가 helper 파드 제한 시간(180초)을 넘을 수 있어 systemd-run 으로 백그라운드 실행 후 완료 표시 파일을 기다린다
INSTALL=$(cat <<'EOF'
exec >/var/log/cks-d11-install.log 2>&1
set -e
trap 'echo fail > /var/tmp/cks-d11-install.done' ERR
if ! command -v runsc >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  curl -fsSL https://gvisor.dev/archive.key | gpg --dearmor --yes -o /usr/share/keyrings/gvisor-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" > /etc/apt/sources.list.d/gvisor.list
  apt-get update -y
  apt-get install -y runsc
fi
C=/etc/containerd/config.toml
if [ ! -f "$C" ]; then mkdir -p /etc/containerd; containerd config default > "$C"; fi
if ! grep -q 'runtimes.runsc' "$C"; then
  cp "$C" "$C.bak-cks-d11"
  if grep -qE '^version *= *3' "$C"; then
    cat >> "$C" <<'EOT'

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
  runtime_type = 'io.containerd.runsc.v1'
EOT
  else
    cat >> "$C" <<'EOT'

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOT
  fi
  systemctl restart containerd
fi
runsc --version | head -1
echo ok > /var/tmp/cks-d11-install.done
EOF
)
B64=$(printf '%s\n' "$INSTALL" | base64 -w0)
node_exec "rm -f /var/tmp/cks-d11-install.done; echo $B64 | base64 -d > /root/cks-d11-install.sh; systemctl stop cks-d11-install >/dev/null 2>&1; systemctl reset-failed cks-d11-install >/dev/null 2>&1; systemd-run --unit=cks-d11-install --collect sh /root/cks-d11-install.sh; true"

echo "워커($W)에서 gVisor 준비 대기 (최대 약 10분)..."
STATE=""
for i in $(seq 1 40); do
  STATE=$(node_exec "cat /var/tmp/cks-d11-install.done 2>/dev/null; true" | tr -d '[:space:]')
  [ -n "$STATE" ] && break
  sleep 10
done
if [ "$STATE" != "ok" ]; then
  echo "gVisor 준비 실패(state='${STATE}'). 워커의 /var/log/cks-d11-install.log 를 확인한다."
  node_exec "tail -n 20 /var/log/cks-d11-install.log; true"
  exit 1
fi
node_exec "runsc --version | head -1; grep -A1 'runtimes.runsc' /etc/containerd/config.toml; true"

# 2) 빈 namespace 와 결과 디렉터리
kubectl create ns onyx
mkdir -p /opt/course/d11

# 3) 시작 상태 확인
kubectl get runtimeclass
kubectl -n onyx get pod
