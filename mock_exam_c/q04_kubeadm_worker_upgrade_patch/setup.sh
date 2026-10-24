#!/usr/bin/env bash
# c04 — Upgrade the worker node with kubeadm · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# 주의: 버전을 낮추지 않는다. 워커가 이미 같은 버전이면 절차만 연습하게 된다.
set -euo pipefail

# 워커 노드 호스트에서 명령 실행 (privileged 파드 + nsenter). 사용: node_exec "<명령>"
W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}
node_exec() {
  kubectl delete pod node-exec-helper -n default --ignore-not-found --wait=true >/dev/null
  kubectl run node-exec-helper -n default --restart=Never --image=busybox:1.36 \
    --overrides='{"spec":{"nodeName":"'"$W"'","hostPID":true,"tolerations":[{"operator":"Exists"}],"containers":[{"name":"x","image":"busybox:1.36","command":["nsenter","-t","1","-m","-u","-i","-n","-p","--","sh","-c","'"${1//\"/\\\"}"'"],"securityContext":{"privileged":true}}]}}' >/dev/null
  kubectl wait pod/node-exec-helper -n default --for=jsonpath='{.status.phase}'=Succeeded --timeout=180s >/dev/null || true
  kubectl logs node-exec-helper -n default
  kubectl delete pod node-exec-helper -n default --ignore-not-found >/dev/null
}

# 0) 이전 실습 흔적 정리
kubectl uncordon "$W" >/dev/null 2>&1 || true
kubectl delete ns upg --ignore-not-found --wait=true
rm -rf /opt/course/c04
mkdir -p /opt/course/c04

# 1) 버전 기록 (컨트롤 플레인 / 워커)
{
  echo "# control plane ($(hostname))"
  echo "kubeadm: $(kubeadm version -o short)"
  echo "kubelet: $(kubelet --version)"
  echo "# worker ($W)"
  node_exec "echo kubeadm: \$(kubeadm version -o short); echo kubelet: \$(kubelet --version); apt-mark showhold | xargs echo held:"
  echo "# kubectl get nodes"
  kubectl get nodes
} > /opt/course/c04/versions-before.txt

# 2) drain 에 걸리는 워크로드: emptyDir 쓰는 Deployment + 컨트롤러 없는 단독 Pod
kubectl create ns upg
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary
  namespace: upg
spec:
  replicas: 2
  selector:
    matchLabels:
      app: canary
  template:
    metadata:
      labels:
        app: canary
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
      volumes:
      - name: cache
        emptyDir: {}
---
apiVersion: v1
kind: Pod
metadata:
  name: scratch
  namespace: upg
spec:
  nodeName: $W
  containers:
  - name: sh
    image: busybox:1.36
    command: ["sleep", "1d"]
YAML
kubectl -n upg rollout status deploy/canary --timeout=180s

# 3) 시작 상태 확인
cat /opt/course/c04/versions-before.txt
kubectl -n upg get pod -o wide
