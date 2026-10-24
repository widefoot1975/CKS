#!/usr/bin/env bash
# a06 — Re-enable the NodeRestriction admission plugin and prove it · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/a06/backup

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

# 매니페스트를 바꾼 뒤 새 kube-apiserver 컨테이너가 뜨고 /readyz 가 ok 가 될 때까지 대기
wait_new_apiserver() {
  local old=$1 cur
  for i in $(seq 1 90); do
    cur=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
    if [ -n "$cur" ] && [ "$cur" != "$old" ]; then break; fi
    sleep 2
  done
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본으로 되돌린 뒤 다시 백업, 테스트 라벨 제거
mkdir -p "$BK"
OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
if [ -f "$BK/kube-apiserver.yaml" ] && ! cmp -s "$BK/kube-apiserver.yaml" "$MANIFEST"; then
  cp "$BK/kube-apiserver.yaml" "$MANIFEST"
  wait_new_apiserver "$OLD"
fi
find /opt/course/a06 -mindepth 1 -maxdepth 1 ! -name backup -exec rm -rf {} +
cp "$MANIFEST" "$BK/kube-apiserver.yaml"
kubectl label node --all a06-before- a06-after- a06-self- node-restriction.kubernetes.io/zone- >/dev/null 2>&1 || true
grep -q -- '--enable-admission-plugins=.*NodeRestriction' "$MANIFEST" || { echo "원본 매니페스트에 NodeRestriction 이 없다 (kubeadm 기본값이 아님)"; exit 1; }

# 1) 워커 kubelet 클라이언트 인증서로 kubeconfig 만들기 (system:node:<워커>)
node_exec 'cat /var/lib/kubelet/pki/kubelet-client-current.pem' > /opt/course/a06/w1-kubelet.pem
chmod 600 /opt/course/a06/w1-kubelet.pem
grep -q 'BEGIN CERTIFICATE' /opt/course/a06/w1-kubelet.pem || { echo "kubelet 인증서를 가져오지 못했다"; exit 1; }
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KK=/opt/course/a06/w1-kubelet.kubeconfig
kubectl config set-cluster kubernetes --server="$SERVER" --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs --kubeconfig=$KK >/dev/null
kubectl config set-credentials "system:node:$W" --client-certificate=/opt/course/a06/w1-kubelet.pem --client-key=/opt/course/a06/w1-kubelet.pem --embed-certs --kubeconfig=$KK >/dev/null
kubectl config set-context kubelet --cluster=kubernetes --user="system:node:$W" --kubeconfig=$KK >/dev/null
kubectl config use-context kubelet --kubeconfig=$KK >/dev/null
chmod 600 $KK

# 2) 고장 내기: NodeRestriction 을 enable 목록에서 빼고 disable 목록에 넣는다
OLD=$(crictl ps --name kube-apiserver -q 2>/dev/null | head -1 || true)
sed -i 's/--enable-admission-plugins=.*$/--enable-admission-plugins=NamespaceLifecycle,ServiceAccount/' "$MANIFEST"
sed -i '/^    - kube-apiserver$/a\    - --disable-admission-plugins=NodeRestriction' "$MANIFEST"
wait_new_apiserver "$OLD"

# 3) 시작 상태 확인
grep -n admission-plugins "$MANIFEST"
kubectl --kubeconfig=$KK get nodes
