#!/usr/bin/env bash
# b02 — Fix kube-bench findings for etcd and the worker kubelet · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

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

M=/etc/kubernetes/manifests/etcd.yaml
BK=/opt/course/b02/backup
KB_URL=https://github.com/aquasecurity/kube-bench/releases/download/v0.10.4/kube-bench_0.10.4_linux_amd64.deb

# 0) kube-bench v0.10.4 설치 (없을 때만, 두 노드 모두)
if ! command -v kube-bench >/dev/null; then
  curl -fsSLo /tmp/kube-bench.deb "$KB_URL" && dpkg -i /tmp/kube-bench.deb
fi
node_exec "command -v kube-bench >/dev/null || (curl -fsSLo /tmp/kube-bench.deb $KB_URL && dpkg -i /tmp/kube-bench.deb)"

# 1) 이전 실습 흔적 정리: 백업이 있으면 먼저 원래대로 되돌린다
if [ -f $BK/etcd.yaml ]; then cp $BK/etcd.yaml $M; fi
if [ -f $BK/etcd-dir.mode ]; then chmod "$(cat $BK/etcd-dir.mode)" /var/lib/etcd; fi
node_exec "if [ -f /opt/course/b02/backup/config.yaml ]; then cp -p /opt/course/b02/backup/config.yaml /var/lib/kubelet/config.yaml; systemctl restart kubelet; fi; rm -rf /opt/course/b02"
rm -rf /opt/course/b02
mkdir -p $BK
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

# 2) 원본 백업 (manifests 디렉터리 밖)
cp $M $BK/etcd.yaml
stat -c %a /var/lib/etcd > $BK/etcd-dir.mode
grep -q -- '- --client-cert-auth=true' $M || { echo "etcd.yaml 에 --client-cert-auth=true 가 없다 (kubeadm 기본 매니페스트가 아님)"; exit 1; }

# 3) 고장 내기 (컨트롤 플레인): etcd 클라이언트 인증서 인증 끄기 + 데이터 디렉터리 755
sed -i 's/- --client-cert-auth=true/- --client-cert-auth=false/' $M
chmod 755 /var/lib/etcd
echo "etcd 재기동 대기..."
sleep 25
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done

# 4) 고장 내기 (워커): 원본 백업 후 readOnlyPort 10255, 파일 권한 644, kubelet 재시작
node_exec "mkdir -p /opt/course/b02/backup; cp -p /var/lib/kubelet/config.yaml /opt/course/b02/backup/config.yaml; sed -i '/^readOnlyPort:/d' /var/lib/kubelet/config.yaml; echo 'readOnlyPort: 10255' >> /var/lib/kubelet/config.yaml; chmod 644 /var/lib/kubelet/config.yaml; systemctl restart kubelet; sleep 5; ss -ltn | grep 10255 || true"
kubectl wait node "$W" --for=condition=Ready --timeout=120s

# 5) 시작 상태 확인
grep -- 'cert-auth' $M
ls -ld /var/lib/etcd
kubectl get nodes
