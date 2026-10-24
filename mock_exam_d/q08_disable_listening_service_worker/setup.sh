#!/usr/bin/env bash
# d08 — Disable a listening service on the worker node · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
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
# 여러 줄 스크립트를 따옴표 걱정 없이 워커에서 실행 (base64 로 전달)
node_script() { node_exec "echo $(printf '%s\n' "$1" | base64 -w0) | base64 -d | sh"; }

# 0) 결과 디렉터리 초기화 (워커 쪽 이전 흔적은 아래 스크립트가 먼저 지운다)
rm -rf /opt/course/d08
mkdir -p /opt/course/d08

# 1) 워커에 불필요한 서비스를 만든다: python3 http.server 를 0.0.0.0:20800 에 띄우는 systemd 유닛
node_script "$(cat <<'EOF'
systemctl disable --now pkgcache-sync.service >/dev/null 2>&1 || true
systemctl unmask pkgcache-sync.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/pkgcache-sync.service /usr/local/bin/pkgcache-sync
systemctl daemon-reload
if ! command -v python3 >/dev/null 2>&1; then echo NO_PYTHON3; exit 0; fi
mkdir -p /var/lib/pkgcache-sync
cat > /usr/local/bin/pkgcache-sync <<'EOS'
#!/bin/sh
# legacy package cache sync agent (CKS lab d08)
exec python3 -m http.server 20800 --bind 0.0.0.0 --directory /var/lib/pkgcache-sync
EOS
chmod 0755 /usr/local/bin/pkgcache-sync
cat > /etc/systemd/system/pkgcache-sync.service <<'EOS'
[Unit]
Description=Package cache sync agent
After=network-online.target

[Service]
ExecStart=/usr/local/bin/pkgcache-sync
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload
systemctl enable --now pkgcache-sync.service
sleep 3
ss -ltnp | grep 20800 || echo NOT_LISTENING
EOF
)"

# 2) 시작 상태 확인
echo "worker: $W — TCP 20800 이 열려 있어야 한다"
