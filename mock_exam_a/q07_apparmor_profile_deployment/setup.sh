#!/usr/bin/env bash
# a07 — Confine a Deployment with a Localhost AppArmor profile · 사전 환경 설정
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
kubectl delete ns tide --ignore-not-found --wait=true
rm -rf /opt/course/a07
mkdir -p /opt/course/a07

# 1) 워커: AppArmor 확인, 프로필 파일을 두되 로드하지 않은 상태로 만든다
worker_sh <<'EOF'
set -e
if [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" != "Y" ]; then echo "ERROR: AppArmor 가 꺼져 있다"; exit 1; fi
command -v apparmor_parser >/dev/null || { echo "ERROR: apparmor_parser 가 없다 (apparmor 패키지 필요)"; exit 1; }
if [ -f /etc/apparmor.d/cks-a07-deny-write ]; then apparmor_parser -R /etc/apparmor.d/cks-a07-deny-write 2>/dev/null || true; fi
cat > /etc/apparmor.d/cks-a07-deny-write <<'PROFILE'
#include <tunables/global>

profile cks-a07-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # deny every write, everywhere
  deny /** w,
}
PROFILE
echo "profile file written; loaded? ->"
aa-status 2>/dev/null | grep cks-a07 || echo "not loaded (정상)"
EOF

# 2) Deployment: 옛 어노테이션(unconfined)만 있고 노드 고정 없음
kubectl create ns tide
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tide-writer
  namespace: tide
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tide-writer
  template:
    metadata:
      labels:
        app: tide-writer
      annotations:
        container.apparmor.security.beta.kubernetes.io/writer: unconfined
    spec:
      containers:
      - name: writer
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date >> /tmp/heartbeat; sleep 5; done"]
YAML
kubectl -n tide rollout status deploy tide-writer --timeout=120s

# 3) 시작 상태 확인: 지금은 /tmp 에 쓸 수 있다
kubectl -n tide get pod -o wide
kubectl -n tide exec deploy/tide-writer -- cat /proc/1/attr/current || true
