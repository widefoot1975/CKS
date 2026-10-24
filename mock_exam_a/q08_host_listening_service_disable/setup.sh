#!/usr/bin/env bash
# a08 — Find and remove a disguised listening service on the worker · 사전 환경 설정
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

# 0) cks-c1 쪽 결과 디렉터리 초기화
rm -rf /opt/course/a08
mkdir -p /opt/course/a08

# 1) 워커: 이전 흔적 정리 후, 이름을 숨긴 서비스(sys-telemetry.service → /usr/local/sbin/legacy-agent :20494) 설치
worker_sh <<'EOF'
set -e
systemctl disable --now sys-telemetry.service >/dev/null 2>&1 || true
systemctl unmask sys-telemetry.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/sys-telemetry.service /usr/local/sbin/legacy-agent
mkdir -p /usr/local/sbin

if [ -x /usr/bin/python3 ]; then
  cat > /usr/local/sbin/legacy-agent <<'PY'
#!/usr/bin/python3
# legacy-agent: answers every TCP connection with a banner
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", 20494))
s.listen(5)
while True:
    c, _ = s.accept()
    c.sendall(b"legacy-agent 0.3 ready\n")
    c.close()
PY
  chmod 755 /usr/local/sbin/legacy-agent
  EXEC=/usr/local/sbin/legacy-agent
elif command -v nc >/dev/null 2>&1 && nc -h 2>&1 | grep -q -- '-k'; then
  cp "$(readlink -f "$(command -v nc)")" /usr/local/sbin/legacy-agent
  chmod 755 /usr/local/sbin/legacy-agent
  EXEC="/usr/local/sbin/legacy-agent -lk 20494"
else
  echo "ERROR: 워커에 python3 또는 OpenBSD nc 가 필요하다"; exit 1
fi

cat > /etc/systemd/system/sys-telemetry.service <<UNIT
[Unit]
Description=System telemetry collector
After=network.target

[Service]
ExecStart=$EXEC
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now sys-telemetry.service
sleep 2
ss -tlnp | grep 20494 || echo "WARN: 20494 가 아직 열리지 않았다"
EOF

# 2) 시작 상태 확인 (cks-c1 에서 워커 포트로 접속)
W_IP=$(kubectl get node "$W" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
timeout 3 bash -c "exec 3<>/dev/tcp/$W_IP/20494 && echo 'port 20494 open on $W'" || echo "포트 확인 실패"
