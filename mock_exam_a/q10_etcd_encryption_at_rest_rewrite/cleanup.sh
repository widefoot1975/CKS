#!/usr/bin/env bash
# a10 — 실습 후 정리
# 실행: sudo bash cleanup.sh
# 순서: (1) 설정의 맨 앞에 identity 를 넣고 apiserver 재시작 → (2) 모든 Secret 을 평문으로 다시 쓰기
#       → (3) 원본 매니페스트 복구 → (4) 설정 파일 삭제. 순서를 바꾸면 Secret 을 읽을 수 없게 된다.
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a10/backup

wait_new_apiserver() {
  local old=$1 cur
  for i in $(seq 1 90); do
    cur=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
    if [ -n "$cur" ] && [ "$cur" != "$old" ]; then break; fi
    sleep 2
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

ENC=$(grep -o -- '--encryption-provider-config=[^" ]*' "$MANIFEST" | head -1 | cut -d= -f2 || true)
if [ -n "$ENC" ] && [ -f "$ENC" ] && kubectl get --raw=/readyz >/dev/null 2>&1; then
  # (1) 각 providers: 목록 맨 앞에 identity 를 넣는다 (이미 identity 가 첫 번째면 그대로)
  cp "$ENC" "$ENC.a10-orig"
  awk '
    /^[[:space:]]*providers:[[:space:]]*$/ { print; p = 1; next }
    p == 1 && /^[[:space:]]*-[[:space:]]/ {
      if ($0 !~ /identity/) { match($0, /^[[:space:]]*/); print substr($0, 1, RLENGTH) "- identity: {}" }
      p = 0
    }
    { print }
  ' "$ENC.a10-orig" > "$ENC"
  # 같은 매니페스트로 컨테이너만 재시작 → 바뀐 설정 파일을 다시 읽는다
  OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
  crictl stop "$OLD" >/dev/null
  wait_new_apiserver "$OLD"
  # (2) 평문으로 다시 쓰기
  kubectl get secrets -A -o json | kubectl replace -f - >/dev/null
  if grep -q configmaps "$ENC"; then kubectl get configmaps -A -o json | kubectl replace -f - >/dev/null; fi
  echo "모든 Secret 을 평문으로 다시 썼다"
fi

# (3) 원본 매니페스트 복구
if [ -f "$BK/kube-apiserver.yaml" ] && ! cmp -s "$BK/kube-apiserver.yaml" "$MANIFEST"; then
  OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
  cp "$BK/kube-apiserver.yaml" "$MANIFEST"
  wait_new_apiserver "$OLD"
fi
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

# (4) 나머지 정리
kubectl delete ns finance --ignore-not-found
rm -rf /etc/kubernetes/enc /opt/course/a10
kubectl get --raw=/readyz; echo
