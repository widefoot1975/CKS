#!/usr/bin/env bash
# e10 — Switch encryption at rest from identity to aescbc · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# kube-apiserver 매니페스트를 고친다. 원본은 /opt/course/e10/backup/ 에 두고 cleanup.sh 가 복구한다.
set -euo pipefail

export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
MANI=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/e10/backup
ENC_DIR=/etc/kubernetes/enc

apiserver_id() { crictl ps --name kube-apiserver --state running -q 2>/dev/null | head -1; }

# kube-apiserver 컨테이너가 바뀌고(/readyz OK) 다시 응답할 때까지 대기. 사용: wait_apiserver <이전 컨테이너 ID>
wait_apiserver() {
  local old="$1" i cur
  for i in $(seq 1 60); do
    cur=$(apiserver_id)
    [ -n "$cur" ] && [ "$cur" != "$old" ] && break
    sleep 3
  done
  for i in $(seq 1 100); do
    kubectl get --raw=/readyz >/dev/null 2>&1 && return 0
    sleep 3
  done
  echo "kube-apiserver 가 돌아오지 않는다 — /var/log/pods/kube-system_kube-apiserver-*/ 확인, 백업: $BK" >&2
  return 1
}

# identity 를 첫째로 둔 설정 (쓰기는 평문, 읽기는 aescbc/key1 도 가능)
write_enc_identity_first() {
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
  chmod 600 "$ENC_DIR/enc.yaml"
}

# 0) 이전 실행 흔적이 있으면: Secret 을 평문으로 되돌리고 원본 매니페스트 복구
if [ -f "$BK/kube-apiserver.yaml" ]; then
  echo "이전 실습 상태를 되돌리는 중 ..."
  if [ -f "$BK/key" ] && [ -d "$ENC_DIR" ]; then
    write_enc_identity_first
    old=$(apiserver_id); [ -n "$old" ] && crictl stop "$old" >/dev/null
    wait_apiserver "$old"
    kubectl get secrets -A -o json | kubectl replace -f - >/dev/null || true
  fi
  kubectl delete ns vault --ignore-not-found --wait=true
  old=$(apiserver_id)
  cp "$BK/kube-apiserver.yaml" "$MANI"
  wait_apiserver "$old" || true
  rm -rf "$ENC_DIR"
fi
kubectl delete ns vault --ignore-not-found --wait=true
rm -rf /opt/course/e10
mkdir -p "$BK"

# 1) 다른 문항이 이미 암호화 설정을 걸어 두었으면 건드리지 않고 멈춘다
if grep -q -- '--encryption-provider-config' "$MANI"; then
  echo "kube-apiserver 에 이미 --encryption-provider-config 가 있다. 해당 문항의 cleanup.sh 를 먼저 실행할 것." >&2
  exit 1
fi

# 2) 원본 매니페스트 백업 + 키 생성 + identity 가 첫째인 설정 파일
cp "$MANI" "$BK/kube-apiserver.yaml"
mkdir -p "$ENC_DIR"
head -c 32 /dev/urandom | base64 > "$BK/key"
write_enc_identity_first

# 3) kube-apiserver 에 플래그 + hostPath 볼륨/마운트 추가
old=$(apiserver_id)
sed -i 's|^    - kube-apiserver$|&\n    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml|' "$MANI"
sed -i 's|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/enc\n      name: enc\n      readOnly: true|' "$MANI"
sed -i 's|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate\n    name: enc|' "$MANI"
if [ "$(grep -c -e 'encryption-provider-config=' -e 'path: /etc/kubernetes/enc' -e 'mountPath: /etc/kubernetes/enc' "$MANI")" -ne 3 ]; then
  echo "매니페스트 수정 실패 (kubeadm 형식이 아님?) — 원본 복구" >&2
  cp "$BK/kube-apiserver.yaml" "$MANI"
  exit 1
fi
echo "kube-apiserver 재시작 대기 ..."
wait_apiserver "$old"

# 4) 평문으로 저장될 Secret 두 개
kubectl create ns vault
kubectl -n vault create secret generic db-pass --from-literal=password=S3cr3t-e10
kubectl -n vault create secret generic api-key --from-literal=key=ak-7f3e19-e10

# 5) 시작 상태 확인: etcd 의 값이 평문(k8s\0 ... S3cr3t-e10)
ETCD=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec "$ETCD" -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/vault/db-pass --print-value-only | tr -c '[:print:]' '.' | head -c 160; echo
