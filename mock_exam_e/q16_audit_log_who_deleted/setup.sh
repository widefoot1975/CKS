#!/usr/bin/env bash
# e16 — Find who deleted a ConfigMap in the audit log · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# kube-apiserver 에 감사 로그를 켠다. 원본 매니페스트는 /opt/course/e16/backup/ 에 두고 cleanup.sh 가 복구한다.
set -euo pipefail

export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
MANI=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/e16/backup
POLICY=/etc/kubernetes/audit/e16-policy.yaml
LOGDIR=/var/log/kubernetes/audit

apiserver_id() { crictl ps --name kube-apiserver --state running -q 2>/dev/null | head -1; }

# kube-apiserver 컨테이너가 바뀌고 다시 응답할 때까지 대기. 사용: wait_apiserver <이전 컨테이너 ID>
wait_apiserver() {
  local old="$1" i cur
  for i in $(seq 1 60); do
    cur=$(apiserver_id)
    [ -n "$cur" ] && [ "$cur" != "$old" ] && break
    sleep 3
  done
  for i in $(seq 1 100); do
    kubectl get --raw=/readyz >/dev/null 2>&1 && return 0
    sleep 3
  done
  echo "kube-apiserver 가 돌아오지 않는다 — /var/log/pods/kube-system_kube-apiserver-*/ 확인, 백업: $BK" >&2
  return 1
}

# 0) 이전 실행 흔적이 있으면 원본 매니페스트 복구
if [ -f "$BK/kube-apiserver.yaml" ]; then
  old=$(apiserver_id)
  cp "$BK/kube-apiserver.yaml" "$MANI"
  wait_apiserver "$old" || true
fi
kubectl delete ns billing --ignore-not-found --wait=true
rm -f "$POLICY" "$LOGDIR"/audit*.log
rm -rf /opt/course/e16
mkdir -p "$BK"

# 1) 다른 문항이 이미 감사 로그를 켜 두었으면 건드리지 않고 멈춘다
if grep -q -- '--audit-policy-file' "$MANI"; then
  echo "kube-apiserver 에 이미 --audit-policy-file 이 있다. 해당 문항의 cleanup.sh 를 먼저 실행할 것." >&2
  exit 1
fi

# 2) 감사 정책: RequestReceived 생략, 헬스체크·watch 는 제외, 나머지 Metadata
mkdir -p /etc/kubernetes/audit "$LOGDIR"
cat > "$POLICY" <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  - level: None
    nonResourceURLs: ["/healthz*", "/livez*", "/readyz*", "/version"]
  - level: None
    verbs: ["watch"]
  - level: Metadata
EOF

# 3) 매니페스트 백업 + 플래그·볼륨 추가
cp "$MANI" "$BK/kube-apiserver.yaml"
old=$(apiserver_id)
sed -i 's|^    - kube-apiserver$|&\n    - --audit-policy-file=/etc/kubernetes/audit/e16-policy.yaml\n    - --audit-log-path=/var/log/kubernetes/audit/audit.log\n    - --audit-log-maxsize=50\n    - --audit-log-maxbackup=2|' "$MANI"
sed -i 's|^    volumeMounts:$|&\n    - mountPath: /etc/kubernetes/audit\n      name: e16-audit-policy\n      readOnly: true\n    - mountPath: /var/log/kubernetes/audit\n      name: e16-audit-log|' "$MANI"
sed -i 's|^  volumes:$|&\n  - hostPath:\n      path: /etc/kubernetes/audit\n      type: DirectoryOrCreate\n    name: e16-audit-policy\n  - hostPath:\n      path: /var/log/kubernetes/audit\n      type: DirectoryOrCreate\n    name: e16-audit-log|' "$MANI"
if [ "$(grep -c -e 'audit-policy-file=' -e 'name: e16-audit-policy' -e 'name: e16-audit-log' "$MANI")" -ne 5 ]; then
  echo "매니페스트 수정 실패 (kubeadm 형식이 아님?) — 원본 복구" >&2
  cp "$BK/kube-apiserver.yaml" "$MANI"
  exit 1
fi
echo "kube-apiserver 재시작 대기 ..."
wait_apiserver "$old"

# 4) 시나리오: billing 의 ConfigMap 과 이를 다룰 수 있는 SA 세 개
kubectl create ns billing
kubectl -n billing create configmap app-config --from-literal=rate=0.19
kubectl -n billing create configmap old-config --from-literal=rate=0.17
kubectl -n billing create configmap tax-table --from-literal=vat=10
for sa in reader-bot janitor cleanup-bot; do kubectl -n billing create serviceaccount "$sa"; done
kubectl -n billing create role cm-admin --verb=get,list,delete --resource=configmaps
kubectl -n billing create rolebinding cm-admin --role=cm-admin \
  --serviceaccount=billing:reader-bot --serviceaccount=billing:janitor --serviceaccount=billing:cleanup-bot

# 5) 각 SA 의 토큰으로 직접 API 호출 (감사 로그에 SA 이름으로 남는다)
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
call() {  # 사용: call <sa> <METHOD> <path>
  local t
  t=$(kubectl -n billing create token "$1" --duration=10m)
  curl -s --cacert /etc/kubernetes/pki/ca.crt -H "Authorization: Bearer $t" -X "$2" "$APISERVER$3" \
    -o /dev/null -w "$1 $2 $3 -> %{http_code}\n" || true
}
sleep 2
call reader-bot  GET    /api/v1/namespaces/billing/configmaps/app-config
call janitor     DELETE /api/v1/namespaces/billing/configmaps/old-config
call reader-bot  GET    /api/v1/namespaces/billing/configmaps
sleep 2
call cleanup-bot DELETE /api/v1/namespaces/billing/configmaps/app-config
call janitor     GET    /api/v1/namespaces/billing/secrets
call reader-bot  GET    /api/v1/namespaces/billing/configmaps/tax-table

# 6) 시작 상태 확인: app-config, old-config 없음, 감사 로그가 쌓이고 있음
sleep 2
kubectl -n billing get configmap
ls -l "$LOGDIR"
