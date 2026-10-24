#!/usr/bin/env bash
# b13 — Fix manifests with kube-linter and kubesec · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# 0) 도구 설치 (없을 때만, 버전 고정)
if ! command -v kube-linter >/dev/null; then
  curl -fsSL https://github.com/stackrox/kube-linter/releases/download/v0.7.2/kube-linter-linux.tar.gz | tar -xz -C /usr/local/bin kube-linter
  chmod 755 /usr/local/bin/kube-linter
fi
if ! command -v kubesec >/dev/null; then
  curl -fsSL https://github.com/controlplaneio/kubesec/releases/download/v2.14.2/kubesec_linux_amd64.tar.gz | tar -xz -C /usr/local/bin kubesec
  chmod 755 /usr/local/bin/kubesec
fi
command -v jq >/dev/null || { apt-get update -y >/dev/null && apt-get install -y jq >/dev/null; }

# 1) 이전 실습 흔적 정리
kubectl delete ns catalog --ignore-not-found --wait=true
rm -rf /opt/course/b13
mkdir -p /opt/course/b13/manifests
kubectl create ns catalog

# 2) 검토 전 매니페스트 두 개
cat > /opt/course/b13/manifests/catalog.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
      - name: web
        image: nginx:latest
        ports:
        - containerPort: 80
YAML

cat > /opt/course/b13/manifests/worker.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-worker
  namespace: catalog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog-worker
  template:
    metadata:
      labels:
        app: catalog-worker
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo processing; sleep 30; done"]
        resources:
          requests:
            memory: 32Mi
YAML

# 3) 시작 상태 확인
kube-linter version || true
kubesec version 2>/dev/null || true
ls -l /opt/course/b13/manifests
