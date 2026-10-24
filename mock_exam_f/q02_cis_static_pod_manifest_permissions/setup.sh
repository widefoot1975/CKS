#!/usr/bin/env bash
# f02 — Fix CIS file permission findings with kube-bench · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# kube-bench 가 없으면 GitHub 릴리스에서 설치하므로 인터넷 연결이 필요하다.
set -euo pipefail

# 0) 이전 실습 흔적 정리: 백업이 있으면 먼저 원래 권한으로 되돌린다
if [ -f /opt/course/f02/backup/perms.txt ]; then
  while read -r mode path; do
    chmod "$mode" "$path" 2>/dev/null || true
  done < /opt/course/f02/backup/perms.txt
fi
rm -rf /opt/course/f02
mkdir -p /opt/course/f02/backup

# 1) kube-bench v0.10.4 설치 (없을 때만)
if ! command -v kube-bench >/dev/null; then
  curl -fsSLo /tmp/kube-bench_0.10.4_linux_amd64.deb \
    https://github.com/aquasecurity/kube-bench/releases/download/v0.10.4/kube-bench_0.10.4_linux_amd64.deb
  apt-get install -y /tmp/kube-bench_0.10.4_linux_amd64.deb
  rm -f /tmp/kube-bench_0.10.4_linux_amd64.deb
fi

# 2) etcd 데이터 디렉터리 확인 후 원래 권한 백업 (cleanup 이 이 파일로 복원한다)
ETCD_DIR=$(grep -o -- '--data-dir=[^ ]*' /etc/kubernetes/manifests/etcd.yaml | head -1 | cut -d= -f2 || true)
ETCD_DIR=${ETCD_DIR:-/var/lib/etcd}
stat -c '%a %n' /etc/kubernetes/manifests/*.yaml "$ETCD_DIR" > /opt/course/f02/backup/perms.txt

# 3) 고장 내기: 매니페스트 644, etcd 데이터 디렉터리 755
#    (권한만 바뀌고 내용은 그대로라 kubelet 은 static Pod 를 다시 만들지 않는다)
chmod 644 /etc/kubernetes/manifests/*.yaml
chmod 755 "$ETCD_DIR"

# 4) 시작 상태 확인
stat -c '%a %U:%G %n' /etc/kubernetes/manifests/*.yaml "$ETCD_DIR"
command -v kube-bench
