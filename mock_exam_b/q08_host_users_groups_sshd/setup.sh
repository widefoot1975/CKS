#!/usr/bin/env bash
# b08 — Harden host users, groups, sshd and setuid files · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

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

# 0) 이전 실습 흔적 정리 (cks-c1 의 답안 디렉터리 + 워커의 사용자·파일)
rm -rf /opt/course/b08
mkdir -p /opt/course/b08
node_exec "if id ops-tmp >/dev/null 2>&1; then userdel -r ops-tmp 2>/dev/null; fi; rm -f /etc/ssh/sshd_config.d/50-legacy.conf /etc/ssh/sshd_config.d/00-cks-hardening.conf /usr/local/bin/netdiag /usr/local/bin/report-mail /usr/local/bin/rotate-logs; true"

# 1) 임시 운영 계정: 비밀번호 + sudo·docker 그룹 (docker 그룹이 없으면 만들고 표시해 둔다)
node_exec "getent group docker >/dev/null || { groupadd docker && touch /var/lib/cks-b08-docker-group; }; useradd -m -s /bin/bash ops-tmp; echo ops-tmp:Tmp-b08-Passw0rd | chpasswd; usermod -aG sudo,docker ops-tmp; id ops-tmp"

# 2) sshd drop-in: root 로그인·비밀번호 인증 허용 (50- 이므로 99- 파일로는 덮어쓸 수 없다)
node_exec "mkdir -p /etc/ssh/sshd_config.d; echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/50-legacy.conf; echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/50-legacy.conf; sshd -t && (systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true); sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|passwordauthentication)'; true"

# 3) /usr/local/bin: setuid(find 복사본) 1개, setgid 1개(함정: setuid 아님), 일반 스크립트 1개
node_exec "cp /usr/bin/find /usr/local/bin/netdiag; chmod 4755 /usr/local/bin/netdiag; cp /bin/true /usr/local/bin/report-mail; chmod 2755 /usr/local/bin/report-mail; echo 'find /var/log -name *.gz -mtime +7 -delete' > /usr/local/bin/rotate-logs; chmod 755 /usr/local/bin/rotate-logs; ls -l /usr/local/bin/"
