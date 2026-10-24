#!/usr/bin/env bash
# a02 — Fix kube-bench findings on the API server and the kubelet · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a02/backup

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

# 매니페스트를 바꾼 뒤 새 kube-apiserver 컨테이너가 뜨고 /readyz 가 ok 가 될 때까지 대기
wait_new_apiserver() {
  local old=$1 cur
  for i in $(seq 1 90); do
    cur=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
    if [ -n "$cur" ] && [ "$cur" != "$old" ]; then break; fi
    sleep 2
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

# 0) 이전 실습 흔적 정리: 이전 실행의 백업이 있으면 원본으로 되돌린 뒤 다시 백업
mkdir -p "$BK"
OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
if [ -f "$BK/kube-apiserver.yaml" ] && ! cmp -s "$BK/kube-apiserver.yaml" "$MANIFEST"; then
  cp "$BK/kube-apiserver.yaml" "$MANIFEST"
  wait_new_apiserver "$OLD"
fi
find /opt/course/a02 -mindepth 1 -maxdepth 1 ! -name backup -exec rm -rf {} +
cp "$MANIFEST" "$BK/kube-apiserver.yaml"

# 1) kube-bench v0.10.4 설치 (없을 때만, 인터넷 필요)
if ! command -v kube-bench >/dev/null; then
  curl -fsSLo /tmp/kube-bench.deb https://github.com/aquasecurity/kube-bench/releases/download/v0.10.4/kube-bench_0.10.4_linux_amd64.deb
  dpkg -i /tmp/kube-bench.deb && rm -f /tmp/kube-bench.deb
fi

# 2) 워커: kube-bench 설치, kubelet 설정 백업/복구 후 고장 내기 (익명 허용 + AlwaysAllow)
worker_sh <<'EOF'
set -e
if ! command -v kube-bench >/dev/null; then
  curl -fsSLo /tmp/kube-bench.deb https://github.com/aquasecurity/kube-bench/releases/download/v0.10.4/kube-bench_0.10.4_linux_amd64.deb
  dpkg -i /tmp/kube-bench.deb && rm -f /tmp/kube-bench.deb
fi
mkdir -p /opt/course/a02/backup
if [ -f /opt/course/a02/backup/config.yaml ]; then cp /opt/course/a02/backup/config.yaml /var/lib/kubelet/config.yaml; fi
cp /var/lib/kubelet/config.yaml /opt/course/a02/backup/config.yaml
sed -i '/^  anonymous:/,/enabled:/ s/enabled: false/enabled: true/' /var/lib/kubelet/config.yaml
sed -i 's/^  mode: Webhook$/  mode: AlwaysAllow/' /var/lib/kubelet/config.yaml
systemctl restart kubelet
echo "--- worker kubelet config (변경 후)"
grep -A2 -E '^  anonymous:' /var/lib/kubelet/config.yaml
grep -A1 -E '^authorization:' /var/lib/kubelet/config.yaml
EOF

# 3) 컨트롤 플레인: profiling 켜기 + AlwaysAllow 추가
OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
sed -i 's/--authorization-mode=Node,RBAC$/--authorization-mode=Node,RBAC,AlwaysAllow/' "$MANIFEST"
sed -i '/^    - kube-apiserver$/a\    - --profiling=true' "$MANIFEST"
grep -q -- '--profiling=true' "$MANIFEST" || { echo "매니페스트 수정 실패"; exit 1; }
wait_new_apiserver "$OLD"

# 4) 시작 상태 확인
grep -E -- '--profiling|--authorization-mode' "$MANIFEST"
kubectl get nodes
