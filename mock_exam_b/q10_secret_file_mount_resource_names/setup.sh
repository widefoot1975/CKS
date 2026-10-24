#!/usr/bin/env bash
# b10 — Mount a Secret as a file and restrict access by resourceNames · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# 0) 이전 실습 흔적 정리 (immutable Secret 은 namespace 째 지운다)
kubectl delete ns pay --ignore-not-found --wait=true
rm -rf /opt/course/b10
mkdir -p /opt/course/b10
kubectl create ns pay

# 1) Secret 두 개와 권한 없는 ServiceAccount
kubectl -n pay create secret generic db-cred --from-literal=username=app --from-literal=password=b10-S3cr3t-pw
kubectl -n pay create secret generic stripe-key --from-literal=key=sk_test_b10_not_real
kubectl -n pay create sa api

# 2) 비밀번호를 환경 변수로 받는 Deployment
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: pay
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      serviceAccountName: api
      containers:
      - name: api
        image: busybox:1.36
        command: ["sh", "-c", "echo started; sleep 1d"]
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-cred
              key: password
YAML
kubectl -n pay rollout status deploy api --timeout=120s

# 3) 시작 상태 확인
kubectl -n pay get secret,sa,deploy
kubectl -n pay exec deploy/api -- env | grep DB_PASSWORD
command -v etcdctl >/dev/null && echo "host etcdctl: $(command -v etcdctl)" || echo "호스트에 etcdctl 없음 → etcd Pod 안의 etcdctl 사용"
