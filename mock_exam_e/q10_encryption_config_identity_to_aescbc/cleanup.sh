#!/usr/bin/env bash
# e10 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# 순서: identity 를 첫째로 되돌려 재시작 → 모든 Secret 을 평문으로 다시 쓰기 → 원본 매니페스트 복구
# (aescbc 로 암호화된 Secret 이 남은 채 설정만 지우면 그 Secret 을 읽을 수 없게 된다)
set -euo pipefail

export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
MANI=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/e10/backup
ENC_DIR=/etc/kubernetes/enc

apiserver_id() { crictl ps --name kube-apiserver --state running -q 2>/dev/null | head -1; }

wait_apiserver() {
  local old="$1" i cur
  for i in $(seq 1 60); do
    cur=$(apiserver_id)
    [ -n "$cur" ] && [ "$cur" != "$old" ] && break
    sleep 3
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

if [ ! -f "$BK/kube-apiserver.yaml" ]; then
  echo "백업이 없다 — setup 이 실행되지 않았거나 이미 정리됨"
  kubectl delete ns vault --ignore-not-found
  rm -rf /opt/course/e10
  exit 0
fi

# 1) identity 첫째 + 같은 키 (암호화된 데이터도 읽을 수 있게) → 재시작
if [ -f "$BK/key" ] && [ -d "$ENC_DIR" ]; then
  cat > "$ENC_DIR/enc.yaml" <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - identity: {}
      - aescbc:
          keys:
            - name: key1
              secret: $(cat "$BK/key")
EOF
  old=$(apiserver_id); [ -n "$old" ] && crictl stop "$old" >/dev/null
  wait_apiserver "$old"
  # 2) 모든 Secret 을 평문으로 다시 쓴다
  kubectl get secrets -A -o json | kubectl replace -f - >/dev/null || true
fi

kubectl delete ns vault --ignore-not-found --wait=true

# 3) 원본 매니페스트 복구 → 재시작 대기
old=$(apiserver_id)
cp "$BK/kube-apiserver.yaml" "$MANI"
wait_apiserver "$old"
kubectl -n kube-system get pod -l component=kube-apiserver

rm -rf "$ENC_DIR" /opt/course/e10
