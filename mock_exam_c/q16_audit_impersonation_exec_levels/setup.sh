#!/usr/bin/env bash
# c16 — Audit impersonation and pods/exec · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/c16/backup/kube-apiserver.yaml

wait_apiserver() { until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; }

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본 매니페스트로 되돌린다
if [ -f "$BK" ]; then
  cp "$BK" "$MAN"
  sleep 20   # kubelet 이 매니페스트 변경을 감지해 재시작할 시간
  wait_apiserver
fi
if grep -q -- '--audit-policy-file' "$MAN"; then
  echo "kube-apiserver 에 이미 감사 로그가 설정되어 있다. 다른 문제의 cleanup.sh 를 먼저 실행하라."
  exit 1
fi
kubectl delete ns c16 --ignore-not-found --wait=true
kubectl delete clusterrole c16-impersonate-jane --ignore-not-found
kubectl delete clusterrolebinding c16-impersonate-jane --ignore-not-found
rm -rf /opt/course/c16 /etc/kubernetes/audit /var/log/kubernetes/audit

# 1) 원본 매니페스트 백업
mkdir -p /opt/course/c16/backup
cp "$MAN" "$BK"

# 2) 가장(impersonation) 권한: SA robot 은 사용자 jane 으로만 가장할 수 있고, jane 은 c16 의 configmaps 를 읽을 수 있다
kubectl create ns c16
kubectl -n c16 create sa robot
cat <<'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: c16-impersonate-jane
rules:
- apiGroups: [""]
  resources: ["users"]
  verbs: ["impersonate"]
  resourceNames: ["jane"]
YAML
kubectl create clusterrolebinding c16-impersonate-jane --clusterrole=c16-impersonate-jane --serviceaccount=c16:robot
kubectl -n c16 create role cm-reader --verb=get,list --resource=configmaps
kubectl -n c16 create rolebinding jane-cm-reader --role=cm-reader --user=jane

# 3) 1분마다 jane 으로 가장해 configmaps 를 조회하는 CronJob, exec 대상 Pod
cat <<'YAML' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sync
  namespace: c16
spec:
  schedule: "* * * * *"
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 0
      template:
        spec:
          serviceAccountName: robot
          restartPolicy: Never
          containers:
          - name: curl
            image: curlimages/curl:8.10.1
            command:
            - sh
            - -c
            - >-
              curl -sk -o /dev/null -w '%{http_code}\n'
              -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
              -H "Impersonate-User: jane"
              https://kubernetes.default.svc/api/v1/namespaces/c16/configmaps
---
apiVersion: v1
kind: Pod
metadata:
  name: shell
  namespace: c16
spec:
  containers:
  - name: shell
    image: busybox:1.36
    command: ["sleep", "1d"]
YAML
kubectl -n c16 wait pod/shell --for=condition=Ready --timeout=180s

# 4) 시작 상태 확인: 감사 플래그 없음
grep -c -- '--audit' "$MAN" || true
kubectl -n c16 get cronjob,pod
