#!/usr/bin/env bash
# a11 — Run an untrusted workload in a gVisor RuntimeClass · 사전 환경 설정
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

# 0) 이전 실습 흔적 정리
kubectl delete ns sandbox --ignore-not-found --wait=true
kubectl delete runtimeclass gvisor --ignore-not-found
rm -rf /opt/course/a11
mkdir -p /opt/course/a11

# 1) 워커: gVisor 설치(없을 때만) + containerd 런타임 핸들러 runsc 등록(없을 때만)
#    containerd 2.x(config version 3)와 1.x(version 2)의 플러그인 이름이 다르다.
#    kubelet 이 systemd cgroup 드라이버를 쓰면 runsc 에도 systemd-cgroup 을 켠다.
worker_sh <<'EOF'
set -e
if ! command -v runsc >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq ca-certificates curl gnupg >/dev/null
  curl -fsSL https://gvisor.dev/archive.key | gpg --batch --yes --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" > /etc/apt/sources.list.d/gvisor.list
  apt-get update -qq && apt-get install -y -qq runsc >/dev/null
fi
CFG=/etc/containerd/config.toml
MAJOR=$(containerd --version | sed -E 's/.* v?([0-9]+)\..*/\1/')
if [ "$MAJOR" -ge 2 ]; then P='io.containerd.cri.v1.runtime'; V=3; else P='io.containerd.grpc.v1.cri'; V=2; fi
if [ ! -f "$CFG" ]; then mkdir -p /etc/containerd; echo "version = $V" > "$CFG"; fi
if ! grep -q 'runtimes.runsc\]' "$CFG"; then
  cat >> "$CFG" <<TOML

[plugins."$P".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
[plugins."$P".containerd.runtimes.runsc.options]
  TypeUrl = "io.containerd.runsc.v1.options"
  ConfigPath = "/etc/containerd/runsc.toml"
TOML
  if grep -q 'cgroupDriver: systemd' /var/lib/kubelet/config.yaml 2>/dev/null; then
    printf '[runsc_config]\n  systemd-cgroup = "true"\n' > /etc/containerd/runsc.toml
  else
    printf '[runsc_config]\n' > /etc/containerd/runsc.toml
  fi
  systemctl restart containerd
  sleep 5
fi
runsc --version | head -1
grep -A1 'runtimes.runsc\]' "$CFG"
EOF

# 2) 워커 라벨 + runc 로 도는 Deployment
kubectl label node "$W" sandbox.cks.io/gvisor=true --overwrite
kubectl create ns sandbox
kubectl -n sandbox create deploy untrusted-render --image=nginx:1.27-alpine --replicas=2
kubectl -n sandbox rollout status deploy untrusted-render --timeout=180s

# 3) 시작 상태 확인: RuntimeClass 없음, 일반 runc 로 실행 중
kubectl get runtimeclass
kubectl get nodes -L sandbox.cks.io/gvisor
kubectl -n sandbox get pod -o wide
