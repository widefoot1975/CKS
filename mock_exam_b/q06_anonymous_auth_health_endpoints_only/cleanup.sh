#!/usr/bin/env bash
# b06 — 실습 후 정리 (kube-apiserver 매니페스트 원복)
# 실행: sudo bash cleanup.sh
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

BK=/opt/course/b06/backup
if [ -f $BK/kube-apiserver.yaml ]; then
  cp $BK/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
  echo "kube-apiserver 재기동 대기..."
  sleep 25
fi
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

kubectl delete clusterrolebinding anon-ns-reader --ignore-not-found
kubectl delete clusterrole anon-ns-reader --ignore-not-found
rm -rf /opt/course/b06 /etc/kubernetes/authn
