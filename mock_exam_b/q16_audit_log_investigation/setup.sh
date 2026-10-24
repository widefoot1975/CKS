#!/usr/bin/env bash
# b16 — Investigate the audit log and reduce its noise · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}
W=${W:-$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')}

M=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/b16/backup
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

command -v openssl >/dev/null || { echo "openssl 이 필요하다"; exit 1; }
command -v jq >/dev/null || { apt-get update -y >/dev/null && apt-get install -y jq >/dev/null; }

# 0) 이전 실습 흔적 정리: 백업이 있으면 원래 매니페스트로 되돌린다
if [ -f $BK/kube-apiserver.yaml ]; then
  cp $BK/kube-apiserver.yaml $M
  sleep 25
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
fi
kubectl delete ns finance --ignore-not-found --wait=true
rm -rf /opt/course/b16 /etc/kubernetes/audit
rm -f /var/log/kubernetes/audit/audit*.log
mkdir -p $BK

if grep -q -- '--audit-policy-file' $M; then
  echo "kube-apiserver 에 이미 감사 로그 설정이 있다. 해당 문항의 cleanup.sh 를 먼저 실행할 것"; exit 1
fi

# 1) 감사 정책: 모든 요청 Metadata (RequestReceived 단계 생략)
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
EOF

# 2) 원본 백업 후 apiserver 에 감사 플래그와 볼륨 추가
cp $M $BK/kube-apiserver.yaml
sed -i 's|^\(\s*\)- kube-apiserver$|&\n\1- --audit-policy-file=/etc/kubernetes/audit/policy.yaml\n\1- --audit-log-path=/var/log/kubernetes/audit/audit.log\n\1- --audit-log-maxsize=50\n\1- --audit-log-maxbackup=2|' $M
cat > $T/vm.yaml <<'EOF'
    - mountPath: /etc/kubernetes/audit
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit
      name: audit-log
EOF
cat > $T/vol.yaml <<'EOF'
  - hostPath:
      path: /etc/kubernetes/audit
      type: DirectoryOrCreate
    name: audit-policy
  - hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
    name: audit-log
EOF
sed -i "/^    volumeMounts:$/r $T/vm.yaml" $M
sed -i "/^  volumes:$/r $T/vol.yaml" $M
echo "kube-apiserver 재기동 대기..."
sleep 30
for i in $(seq 1 60); do kubectl get --raw=/readyz >/dev/null 2>&1 && break; sleep 5; done
kubectl get --raw=/readyz >/dev/null 2>&1 || {
  echo "apiserver 가 뜨지 않아 원본으로 되돌린다"; cp $BK/kube-apiserver.yaml $M; exit 1; }
for i in $(seq 1 30); do [ -s /var/log/kubernetes/audit/audit.log ] && break; sleep 2; done

# 3) finance: ConfigMap·Secret, 사용자(인증서) 권한, ServiceAccount 권한
kubectl create ns finance
kubectl -n finance create configmap app-config --from-literal=mode=prod
kubectl -n finance create configmap feature-flags --from-literal=beta=false
kubectl -n finance create configmap old-config --from-literal=mode=legacy
kubectl -n finance create secret generic db-pass --from-literal=password=b16-not-real
kubectl -n finance create secret generic api-key --from-literal=key=b16-not-real
kubectl -n finance create role cm-editor --verb=get,list,delete --resource=configmaps
kubectl -n finance create rolebinding cm-editor --role=cm-editor --group=finance-devs
kubectl -n finance create sa harvester
kubectl -n finance create sa auditor
kubectl -n finance create role secret-lister --verb=list --resource=secrets
kubectl -n finance create rolebinding secret-lister --role=secret-lister --serviceaccount=finance:harvester
kubectl -n finance create role secret-getter --verb=get --resource=secrets
kubectl -n finance create rolebinding secret-getter --role=secret-getter --serviceaccount=finance:auditor

# 4) 사용자 mallory, bob: 클러스터 CA 로 서명한 클라이언트 인증서 (그룹 finance-devs)
S=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
for u in mallory bob; do
  openssl genrsa -out $T/$u.key 2048 2>/dev/null
  openssl req -new -key $T/$u.key -subj "/CN=$u/O=finance-devs" -out $T/$u.csr
  openssl x509 -req -in $T/$u.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key \
    -CAcreateserial -CAserial $T/ca.srl -out $T/$u.crt -days 1 2>/dev/null
done
api() { curl -s -o /dev/null --cacert /etc/kubernetes/pki/ca.crt --cert $T/$1.crt --key $T/$1.key -X "$2" "$S$3"; }
api bob GET /api/v1/namespaces/finance/configmaps
api bob GET /api/v1/namespaces/finance/configmaps/app-config
sleep 2
api bob DELETE /api/v1/namespaces/finance/configmaps/old-config
sleep 2
api mallory GET /api/v1/namespaces/finance/configmaps/feature-flags
api mallory DELETE /api/v1/namespaces/finance/configmaps/app-config

# 5) ServiceAccount 활동: harvester 는 워커의 Pod 에서 Secret 목록 조회, auditor 는 Secret 하나 get
cat <<'YAML' | sed "s/__W__/$W/" | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: harvest
  namespace: finance
spec:
  serviceAccountName: harvester
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: __W__
  containers:
  - name: c
    image: curlimages/curl:8.10.1
    command:
    - sh
    - -c
    - >-
      curl -s -o /dev/null --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
      https://kubernetes.default.svc/api/v1/namespaces/finance/secrets
---
apiVersion: v1
kind: Pod
metadata:
  name: checker
  namespace: finance
spec:
  serviceAccountName: auditor
  restartPolicy: Never
  containers:
  - name: c
    image: curlimages/curl:8.10.1
    command:
    - sh
    - -c
    - >-
      curl -s -o /dev/null --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
      https://kubernetes.default.svc/api/v1/namespaces/finance/secrets/api-key
YAML
kubectl -n finance wait pod/harvest pod/checker --for=jsonpath='{.status.phase}'=Succeeded --timeout=180s || true
kubectl -n finance delete pod harvest checker --ignore-not-found

# 6) 시작 상태 확인
mkdir -p /opt/course/b16
grep -- '--audit' $M
ls -l /var/log/kubernetes/audit/
kubectl -n finance get cm,secret,sa
