#!/usr/bin/env bash
# e13 — Deny Pods from untrusted registries with ValidatingAdmissionPolicy · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리 (클러스터 범위 리소스 포함)
kubectl delete validatingadmissionpolicybinding trusted-registry-only-binding --ignore-not-found
kubectl delete validatingadmissionpolicy trusted-registry-only --ignore-not-found
kubectl delete ns factory playground --ignore-not-found --wait=true
rm -rf /opt/course/e13
mkdir -p /opt/course/e13

# 1) 정책을 적용할 namespace(라벨 있음)와 적용하지 않을 namespace
kubectl create ns factory
kubectl label ns factory registry-policy=trusted
kubectl create ns playground

# 2) 시작 상태 확인
kubectl get ns factory playground --show-labels
kubectl get validatingadmissionpolicy 2>/dev/null || true
