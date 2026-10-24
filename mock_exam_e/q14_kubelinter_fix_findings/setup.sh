#!/usr/bin/env bash
# e14 — Fix KubeLinter findings in a Deployment manifest · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요)
set -euo pipefail

KL_VERSION=v0.7.2

# 0) 이전 실습 흔적 정리
kubectl delete ns lint --ignore-not-found --wait=true
rm -rf /opt/course/e14
mkdir -p /opt/course/e14

# 1) kube-linter 가 없으면 설치 (공용 도구, 버전 고정)
if ! command -v kube-linter >/dev/null; then
  curl -fsSL "https://github.com/stackrox/kube-linter/releases/download/${KL_VERSION}/kube-linter-linux.tar.gz" \
    | tar -xz -C /usr/local/bin kube-linter
  chmod +x /usr/local/bin/kube-linter
fi

# 2) 대상 namespace (비어 있음)
kubectl create ns lint

# 3) 문제가 있는 매니페스트 (latest 태그, privileged, root, 쓰기 가능한 루트 FS)
#    아래 nginx:latest 는 이 문제에서 고쳐야 할 의도된 나쁜 예다
cat <<'YAML' > /opt/course/e14/catalog.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: lint
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
      - name: catalog
        image: nginx:latest
        ports:
        - containerPort: 80
        securityContext:
          privileged: true
YAML

# 4) 시작 상태 확인
kube-linter version || true
cat /opt/course/e14/catalog.yaml
kubectl -n lint get all
