#!/usr/bin/env bash
# e08 — Remove an unneeded package and user from a node · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 워커에 인터넷 필요)
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

# 0) 이전 실습 흔적 정리: cks-c1 답안 디렉터리, 워커의 사용자
rm -rf /opt/course/e08
mkdir -p /opt/course/e08
node_exec "systemctl stop e08-legacy-ftp 2>/dev/null; pkill -KILL -u legacy-ftp 2>/dev/null; sleep 1; userdel -r legacy-ftp 2>/dev/null; true"

# 1) 워커: FTP 서버 패키지 설치 (apt, 백그라운드 유닛) → TCP 21 대기
node_bg e08-install "set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq vsftpd
systemctl enable --now vsftpd"

echo "워커에서 패키지 설치 중 ... (최대 10분)"
ok=""
for i in $(seq 1 60); do
  if node_exec "systemctl is-active vsftpd 2>/dev/null" | grep -qx active; then ok=1; break; fi
  sleep 10
done
[ -n "$ok" ] || { echo "설치 실패: 워커에서 journalctl -u e08-install 확인"; exit 1; }

# 2) 워커: 오래된 로컬 사용자 + 그 사용자로 도는 프로세스
node_exec "useradd -m -s /bin/bash legacy-ftp && echo 'old ftp drop box' > /home/legacy-ftp/README && chown legacy-ftp: /home/legacy-ftp/README && systemd-run --unit=e08-legacy-ftp --uid=legacy-ftp sleep infinity"

# 3) 시작 상태 확인: 21 번 포트 대기, 사용자와 프로세스 존재
node_exec "ss -ltn | grep -w 21; id legacy-ftp; ps -u legacy-ftp -o pid,cmd"
