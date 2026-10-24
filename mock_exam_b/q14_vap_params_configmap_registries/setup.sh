#!/usr/bin/env bash
# b14 — ValidatingAdmissionPolicy with ConfigMap parameters · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# 0) 이전 실습 흔적 정리 (정책·바인딩은 클러스터 범위)
kubectl delete validatingadmissionpolicybinding allowed-registries-binding --ignore-not-found
kubectl delete validatingadmissionpolicy allowed-registries --ignore-not-found
kubectl delete ns policy-config team-red team-blue --ignore-not-found --wait=true
rm -rf /opt/course/b14
mkdir -p /opt/course/b14

# 1) 파라미터 ConfigMap 과 대상 namespace (라벨 없음)
kubectl create ns policy-config
kubectl create ns team-red
kubectl create ns team-blue
kubectl -n policy-config create configmap registry-allowlist \
  --from-literal=registries='registry.k8s.io/,docker.io/library/'

# 2) initContainer 만 허용되지 않은 레지스트리를 쓰는 테스트 Pod
cat > /opt/course/b14/bad-init.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: bad-init
  namespace: team-red
spec:
  initContainers:
  - name: fetch
    image: quay.io/prometheus/busybox:latest
    command: ["sh", "-c", "echo init done"]
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
YAML

# 3) 시작 상태 확인
kubectl -n policy-config get cm registry-allowlist -o jsonpath='{.data.registries}{"\n"}'
kubectl get ns team-red team-blue --show-labels
