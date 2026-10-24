#!/usr/bin/env bash
# c13 — Configure the ImagePolicyWebhook admission plugin · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

command -v openssl >/dev/null || { echo "openssl 이 필요하다"; exit 1; }
MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/c13/backup/kube-apiserver.yaml
DIR=/etc/kubernetes/policywebhook

wait_apiserver() { until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; }

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본 매니페스트로 되돌리고 API 서버를 기다린다
if [ -f "$BK" ]; then
  cp "$BK" "$MAN"
  sleep 20   # kubelet 이 매니페스트 변경을 감지해 재시작할 시간
  wait_apiserver
fi
if grep -q ImagePolicyWebhook "$MAN"; then
  echo "kube-apiserver 매니페스트에 이미 ImagePolicyWebhook 이 있다. 원본으로 되돌린 뒤 다시 실행하라."
  exit 1
fi
kubectl delete pod c13-test --ignore-not-found
rm -rf /opt/course/c13 "$DIR"

# 1) 원본 매니페스트 백업
mkdir -p /opt/course/c13/backup
cp "$MAN" "$BK"

# 2) 인증서: CA 와 API 서버용 클라이언트 인증서 (백엔드 서버는 일부러 만들지 않는다)
mkdir -p "$DIR"
cd "$DIR"
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -keyout ca.key -out ca.crt -subj "/CN=image-checker-ca" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -keyout apiserver-client.key -out apiserver-client.csr -subj "/CN=kube-apiserver" 2>/dev/null
openssl x509 -req -in apiserver-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver-client.crt -days 365 2>/dev/null
rm -f apiserver-client.csr ca.key ca.srl
chmod 600 apiserver-client.key

# 3) 미완성 설정 파일 두 개
cat <<'EOF' > "$DIR/admission-config.yaml"
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: TODO
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: true
EOF
cat <<'EOF' > "$DIR/kubeconfig.yaml"
apiVersion: v1
kind: Config
clusters:
- name: image-checker
  cluster:
    certificate-authority: /etc/kubernetes/policywebhook/ca.crt
    server: TODO
contexts:
- name: image-checker
  context:
    cluster: image-checker
    user: api-server
current-context: image-checker
users:
- name: api-server
  user:
    client-certificate: TODO
    client-key: TODO
EOF

# 4) 시작 상태 확인
ls -l "$DIR"
grep -o 'enable-admission-plugins=[^ ]*' "$MAN"
