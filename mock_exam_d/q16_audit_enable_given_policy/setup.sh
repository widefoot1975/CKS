#!/usr/bin/env bash
# d16 — Enable API server auditing with a given policy · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

M=/etc/kubernetes/manifests/kube-apiserver.yaml
D=/opt/course/d16

wait_api() {
  sleep 10
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본 매니페스트를 먼저 되돌린다
if [ -f "$D/backup/kube-apiserver.yaml" ]; then
  cp "$D/backup/kube-apiserver.yaml" "$M"
  echo "이전 실습의 매니페스트를 복원했다. API 서버 재시작 대기..."
  wait_api
fi
kubectl -n default delete secret audit-probe --ignore-not-found

# 1) 감사가 이미 켜져 있으면 멈춘다 (다른 문제의 cleanup 을 먼저)
if grep -q -- '--audit-policy-file' "$M"; then
  echo "kube-apiserver 에 이미 --audit-policy-file 이 있다. 해당 문제의 cleanup.sh 를 먼저 실행한다."
  exit 1
fi
rm -rf "$D"
mkdir -p "$D/backup"
cp "$M" "$D/backup/kube-apiserver.yaml"
rm -f /var/log/kubernetes/audit/audit*.log

# 2) 주어진 감사 정책
mkdir -p /etc/kubernetes/audit
cat <<'YAML' > /etc/kubernetes/audit/d16-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  # 시끄러운 시스템 요청은 기록하지 않는다
  - level: None
    users: ["system:kube-proxy"]
  - level: None
    resources:
      - group: ""
        resources: ["events"]
  # Secret·ConfigMap 은 값이 남지 않도록 Metadata 만
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
  # 그 밖의 요청은 기록하지 않는다
  - level: None
YAML

# 3) 시작 상태 확인: 정책 파일은 있지만 apiserver 에 audit 플래그가 없다
ls -l /etc/kubernetes/audit/d16-policy.yaml
grep -c -- '--audit' "$M" || true
