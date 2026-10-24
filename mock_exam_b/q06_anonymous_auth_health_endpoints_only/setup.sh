#!/usr/bin/env bash
# b06 — Allow anonymous access only to health endpoints · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

M=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/b06/backup

# 0) 이전 실습 흔적 정리: 백업이 있으면 원래 매니페스트로 되돌린다
if [ -f $BK/kube-apiserver.yaml ]; then
  cp $BK/kube-apiserver.yaml $M
  sleep 20
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
kubectl delete clusterrolebinding anon-ns-reader --ignore-not-found
kubectl delete clusterrole anon-ns-reader --ignore-not-found
rm -rf /opt/course/b06 /etc/kubernetes/authn
mkdir -p $BK

if grep -qE -- '--anonymous-auth|--authentication-config' $M; then
  echo "kube-apiserver 에 이미 --anonymous-auth 또는 --authentication-config 가 있다. 다른 문항 cleanup 후 다시 실행"; exit 1
fi

# 1) 원본 백업 후 --anonymous-auth=true 를 명시 (함정: 설정 파일의 anonymous 와 함께 쓸 수 없다)
cp $M $BK/kube-apiserver.yaml
sed -i 's/^\(\s*\)- kube-apiserver$/&\n\1- --anonymous-auth=true/' $M
grep -n -- '--anonymous-auth' $M
echo "kube-apiserver 재기동 대기..."
sleep 25
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

# 2) 익명 사용자에게 namespaces 조회 권한
kubectl create clusterrole anon-ns-reader --verb=get,list --resource=namespaces
kubectl create clusterrolebinding anon-ns-reader --clusterrole=anon-ns-reader --user=system:anonymous

# 3) 시작 상태 확인: 익명으로 namespaces 가 보인다
IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
mkdir -p /opt/course/b06
for p in /livez /version /api/v1/namespaces; do
  echo "$p $(curl -sk -o /dev/null -w '%{http_code}' https://$IP:6443$p)"
done
