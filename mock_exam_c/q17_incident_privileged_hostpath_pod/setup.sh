#!/usr/bin/env bash
# c17 — Investigate a privileged hostPath Pod · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
# 하는 일: kube-apiserver 감사 로그 켜기 → namespace marketing 에서 사고 상황 재현 (워커 /tmp 에 표식 파일 하나를 쓴다)
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

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
BK=/opt/course/c17/backup/kube-apiserver.yaml
wait_apiserver() { until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; }

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본 매니페스트로 되돌린다
if [ -f "$BK" ]; then
  cp "$BK" "$MAN"
  sleep 20   # kubelet 이 매니페스트 변경을 감지해 재시작할 시간
  wait_apiserver
fi
if grep -q -- '--audit-policy-file' "$MAN"; then
  echo "kube-apiserver 에 이미 감사 로그가 설정되어 있다. 다른 문제의 cleanup.sh 를 먼저 실행하라."
  exit 1
fi
kubectl delete ns marketing --ignore-not-found --wait=true
node_exec "rm -f /tmp/.analytics-cache; echo cleaned"
rm -rf /opt/course/c17 /etc/kubernetes/audit /var/log/kubernetes/audit

# 1) 원본 매니페스트 백업
mkdir -p /opt/course/c17/backup
cp "$MAN" "$BK"

# 2) 감사 정책: marketing 의 pods 는 RequestResponse, 나머지는 Metadata
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat <<'EOF' > /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: None
  nonResourceURLs: ["/healthz*", "/livez*", "/readyz*"]
- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]
- level: RequestResponse
  namespaces: ["marketing"]
  resources:
  - group: ""
    resources: ["pods"]
- level: Metadata
EOF

# 3) kube-apiserver 에 감사 플래그와 볼륨 추가 (sed 의 r 명령으로 조각 파일을 끼워 넣는다)
TMP=$(mktemp -d)
cat <<'EOF' > "$TMP/flags"
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxsize=50
    - --audit-log-maxbackup=2
EOF
cat <<'EOF' > "$TMP/mounts"
    - mountPath: /etc/kubernetes/audit/policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit/
      name: audit-log
EOF
cat <<'EOF' > "$TMP/volumes"
  - hostPath:
      path: /etc/kubernetes/audit/policy.yaml
      type: File
    name: audit-policy
  - hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
    name: audit-log
EOF
cp "$MAN" "$TMP/kube-apiserver.yaml"
sed -i -e "/^    - kube-apiserver$/r $TMP/flags" \
       -e "/^    volumeMounts:$/r $TMP/mounts" \
       -e "/^  volumes:$/r $TMP/volumes" "$TMP/kube-apiserver.yaml"
grep -q -- '--audit-policy-file' "$TMP/kube-apiserver.yaml" || { echo "매니페스트 수정 실패"; rm -rf "$TMP"; exit 1; }
cp "$TMP/kube-apiserver.yaml" "$MAN"
rm -rf "$TMP"
echo "kube-apiserver 재시작 대기 중..."
sleep 20
wait_apiserver
until [ -s /var/log/kubernetes/audit/audit.log ]; do sleep 3; done

# 4) 사고 재현: 정상 Deployment + Pod 생성 권한이 있는 SA + 그 SA 토큰으로 API 를 직접 호출해 Pod 를 만드는 Job
kubectl create ns marketing
kubectl -n marketing create sa campaign-bot
kubectl -n marketing create role pod-creator --verb=create,get,list,delete --resource=pods
kubectl -n marketing create rolebinding campaign-bot-pods --role=pod-creator --serviceaccount=marketing:campaign-bot
kubectl -n marketing create deployment campaign-web --image=nginx:1.27-alpine --replicas=1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: sync-payload
  namespace: marketing
data:
  pod.json: |
    {
      "apiVersion": "v1",
      "kind": "Pod",
      "metadata": {"name": "analytics-agent", "namespace": "marketing", "labels": {"app": "analytics-agent"}},
      "spec": {
        "nodeName": "$W",
        "hostPID": true,
        "containers": [{
          "name": "agent",
          "image": "busybox:1.36",
          "command": ["sh", "-c", "echo c17-marker > /host/tmp/.analytics-cache; sleep 1d"],
          "securityContext": {"privileged": true},
          "volumeMounts": [{"name": "host", "mountPath": "/host"}]
        }],
        "volumes": [{"name": "host", "hostPath": {"path": "/"}}]
      }
    }
---
apiVersion: batch/v1
kind: Job
metadata:
  name: campaign-sync
  namespace: marketing
spec:
  backoffLimit: 0
  template:
    spec:
      serviceAccountName: campaign-bot
      restartPolicy: Never
      containers:
      - name: curl
        image: curlimages/curl:8.10.1
        command:
        - sh
        - -c
        - >-
          curl -sk -X POST -o /dev/null -w '%{http_code}\n'
          -H "Authorization: Bearer \$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
          -H 'Content-Type: application/json'
          --data @/payload/pod.json
          https://kubernetes.default.svc/api/v1/namespaces/marketing/pods
        volumeMounts:
        - name: payload
          mountPath: /payload
      volumes:
      - name: payload
        configMap:
          name: sync-payload
EOF

kubectl -n marketing wait job/campaign-sync --for=condition=Complete --timeout=180s
kubectl -n marketing wait pod/analytics-agent --for=condition=Ready --timeout=180s
kubectl -n marketing rollout status deploy/campaign-web --timeout=180s
# 단서가 너무 쉽게 남지 않도록 payload ConfigMap 은 지운다 (Job 은 남긴다)
kubectl -n marketing delete configmap sync-payload
mkdir -p /opt/course/c17

# 5) 시작 상태 확인
kubectl -n marketing get pod,job -o wide
