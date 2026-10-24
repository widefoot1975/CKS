#!/usr/bin/env bash
# a01 — Default-deny a namespace and open only DNS, API and external egress · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

# 0) 이전 실습 흔적 정리
kubectl delete ns aurora --ignore-not-found --wait=true
rm -rf /opt/course/a01
mkdir -p /opt/course/a01

# 1) namespace 와 워크로드: api(8080) + Service 80→8080, frontend·batch(curl 클라이언트)
kubectl create ns aurora
kubectl -n aurora create deploy api --image=hashicorp/http-echo:1.0 -- /http-echo -text=api-ok -listen=:8080
kubectl -n aurora expose deploy api --port=80 --target-port=8080
kubectl -n aurora create deploy frontend --image=curlimages/curl:8.10.1 -- sleep 1d
kubectl -n aurora run batch --image=curlimages/curl:8.10.1 --labels=app=batch --restart=Never -- sleep 1d

kubectl -n aurora rollout status deploy api --timeout=120s
kubectl -n aurora rollout status deploy frontend --timeout=120s
kubectl -n aurora wait pod/batch --for=condition=Ready --timeout=120s

# 2) 시작 상태 확인: NetworkPolicy 없음 → batch 도 api 에 접근된다
kubectl -n aurora get deploy,pod,svc,netpol --show-labels
kubectl -n aurora exec batch -- curl -s -m 3 http://api || true
