#!/usr/bin/env bash
# f06 — Sign a user certificate with a CSR and build a kubeconfig · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리 (CSR 은 클러스터 범위 리소스)
kubectl delete csr jane --ignore-not-found
kubectl delete ns dev --ignore-not-found --wait=true
rm -rf /opt/course/f06
mkdir -p /opt/course/f06

# 1) jane 의 개인 키와 CSR (CN=jane)
openssl genrsa -out /opt/course/f06/jane.key 2048 2>/dev/null
openssl req -new -key /opt/course/f06/jane.key -subj "/CN=jane" -out /opt/course/f06/jane.csr
chmod 600 /opt/course/f06/jane.key

# 2) namespace dev, 조회용 Pod, 사용자 jane 에게 Pod 조회 권한
kubectl create ns dev
kubectl -n dev run hello --image=nginx:1.27-alpine
kubectl -n dev create role pod-reader --verb=get,list,watch --resource=pods
kubectl -n dev create rolebinding jane-pod-reader --role=pod-reader --user=jane
kubectl -n dev wait pod hello --for=condition=Ready --timeout=120s

# 3) 시작 상태 확인
ls -l /opt/course/f06
kubectl get csr jane 2>&1 | tail -1
kubectl -n dev get pod,role,rolebinding
