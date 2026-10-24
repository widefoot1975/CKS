#!/usr/bin/env bash
# a14 — ValidatingAdmissionPolicy for trusted registries and pinned tags · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete validatingadmissionpolicybinding trusted-registries-binding --ignore-not-found
kubectl delete validatingadmissionpolicy trusted-registries --ignore-not-found
kubectl delete ns orbit playground --ignore-not-found --wait=true
rm -rf /opt/course/a14
mkdir -p /opt/course/a14

# 1) 대상 namespace(라벨 있음)와 대조군(라벨 없음)
kubectl create ns orbit
kubectl label ns orbit registry-policy=enforced
kubectl create ns playground

# 2) init 컨테이너만 위반하는 테스트 Pod (메인 컨테이너는 정상)
cat <<'YAML' > /opt/course/a14/init-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: t5
  namespace: orbit
spec:
  initContainers:
  - name: fetch
    image: ghcr.io/example/fetcher:1.0
    command: ["sh", "-c", "true"]
  containers:
  - name: main
    image: docker.io/library/busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
YAML

# 3) 시작 상태 확인
kubectl get ns orbit playground --show-labels
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding 2>/dev/null || true
