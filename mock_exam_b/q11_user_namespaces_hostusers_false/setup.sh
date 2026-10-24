#!/usr/bin/env bash
# b11 — Run a Deployment in a user namespace · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}
W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}

# 0) 워커의 커널·런타임 버전 확인 (user namespace: Linux 6.3+, containerd 2.0+ 권장)
KV=$(kubectl get node "$W" -o jsonpath='{.status.nodeInfo.kernelVersion}')
RV=$(kubectl get node "$W" -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}')
echo "worker $W: kernel=$KV runtime=$RV"
KMAJ=${KV%%.*}; KREST=${KV#*.}; KMIN=${KREST%%.*}
if [ "$KMAJ" -lt 6 ] || { [ "$KMAJ" -eq 6 ] && [ "$KMIN" -lt 3 ]; }; then
  echo "경고: 커널이 6.3 미만이라 hostUsers: false Pod 가 뜨지 않을 수 있다"
fi
case "$RV" in containerd://1.*) echo "경고: containerd 1.x 는 user namespace 지원이 불완전하다 (2.0+ 권장)";; esac

# 1) 이전 실습 흔적 정리
kubectl delete ns tenant --ignore-not-found --wait=true
rm -rf /opt/course/b11
mkdir -p /opt/course/b11
kubectl create ns tenant

# 2) 호스트 네트워크를 쓰고 호스트 user namespace 에서 root 로 도는 Deployment
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sandbox
  namespace: tenant
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sandbox
  template:
    metadata:
      labels:
        app: sandbox
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/hostname: $W
      containers:
      - name: sandbox
        image: busybox:1.36
        command: ["sleep", "1d"]
YAML
kubectl -n tenant rollout status deploy sandbox --timeout=120s

# 3) 시작 상태 확인: uid_map 이 전체 항등 매핑
kubectl -n tenant get pod -o wide
kubectl -n tenant exec deploy/sandbox -- cat /proc/self/uid_map
