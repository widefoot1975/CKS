#!/usr/bin/env bash
# b05 — Clean up legacy ServiceAccount token Secrets · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# 0) 이전 실습 흔적 정리
kubectl delete ns legacy --ignore-not-found --wait=true
rm -rf /opt/course/b05
mkdir -p /opt/course/b05
kubectl create ns legacy

# 1) ServiceAccount 세 개와 직접 만든 레거시 토큰 Secret (v1.24+ 에서는 자동 생성되지 않는다)
for sa in ci-bot old-app metrics; do
  kubectl -n legacy create sa $sa
  cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $sa-token
  namespace: legacy
  annotations:
    kubernetes.io/service-account.name: $sa
type: kubernetes.io/service-account-token
YAML
done

# 2) 토큰 컨트롤러가 token 을 채울 때까지 대기
for sa in ci-bot old-app metrics; do
  for i in $(seq 1 30); do
    [ -n "$(kubectl -n legacy get secret $sa-token -o jsonpath='{.data.token}')" ] && break
    sleep 1
  done
done

# 3) ci-bot 토큰만 실제 API 호출에 사용 → apiserver 가 legacy-token-last-used 라벨을 붙인다
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(kubectl -n legacy get secret ci-bot-token -o jsonpath='{.data.token}' | base64 -d)
curl -sk -o /dev/null -H "Authorization: Bearer $TOKEN" "$APISERVER/api" || true
for i in $(seq 1 30); do
  kubectl -n legacy get secret ci-bot-token -o jsonpath='{.metadata.labels}' | grep -q legacy-token-last-used && break
  sleep 2
done

# 4) API 를 쓰지 않는데 토큰이 마운트되는 Deployment
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report
  namespace: legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: report
  template:
    metadata:
      labels:
        app: report
    spec:
      serviceAccountName: metrics
      containers:
      - name: report
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date > /tmp/report.txt; sleep 30; done"]
YAML
kubectl -n legacy rollout status deploy report --timeout=120s

# 5) 시작 상태 확인
kubectl -n legacy get sa,secret -L kubernetes.io/legacy-token-last-used
kubectl -n legacy exec deploy/report -- ls /var/run/secrets/kubernetes.io/serviceaccount
