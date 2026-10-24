#!/usr/bin/env bash
# f02 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# kube-bench 는 공용 도구라 지우지 않는다.
set -euo pipefail

# 백업한 원래 권한으로 복원 (백업이 없으면 kubeadm 기본값)
if [ -f /opt/course/f02/backup/perms.txt ]; then
  while read -r mode path; do
    chmod "$mode" "$path" 2>/dev/null || true
  done < /opt/course/f02/backup/perms.txt
else
  chmod 600 /etc/kubernetes/manifests/*.yaml
  chmod 700 /var/lib/etcd 2>/dev/null || true
fi
stat -c '%a %n' /etc/kubernetes/manifests/*.yaml
rm -rf /opt/course/f02
