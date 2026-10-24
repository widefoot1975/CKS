# q16 — Audit Secret access at Metadata level · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The cluster must record who accesses Secrets, without writing Secret contents into the log.
>
> 1. Create the audit policy file `/etc/kubernetes/audit/policy.yaml` on `cks-c1`. It must not
>    generate events for the `RequestReceived` stage, must log all requests on Secrets (core API
>    group) at level `Metadata`, and must not log anything else.
> 2. Configure kube-apiserver to use this policy, to write the audit log to
>    `/var/log/kubernetes/audit/audit.log` and to keep at most `2` rotated log files. Wait until the
>    API server is available again.
> 3. Run `kubectl -n f16 get secret api-key`, then write one audit event (one JSON line) of exactly
>    this request to `/opt/course/f16/event.json`.

**해석**

클러스터는 누가 Secret 에 접근하는지 기록해야 하지만, Secret 내용을 로그에 쓰면 안 된다.

1. `cks-c1` 에 감사 정책 파일 `/etc/kubernetes/audit/policy.yaml` 을 만든다. `RequestReceived` 단계 이벤트는 만들지 않고, Secret(core API 그룹)에
   대한 모든 요청은 `Metadata` 수준으로 기록하고, 그 밖의 것은 아무것도 기록하지 않는다.
2. kube-apiserver 가 이 정책을 쓰고, 감사 로그를 `/var/log/kubernetes/audit/audit.log` 에 쓰고, 순환된 로그 파일을 최대 `2` 개만 남기게 설정한다.
   API 서버가 다시 사용 가능해질 때까지 기다린다.
3. `kubectl -n f16 get secret api-key` 를 실행한 뒤, 바로 이 요청의 감사 이벤트 하나(JSON 한 줄)를 `/opt/course/f16/event.json` 에 쓴다.

## 모범 풀이

**1) 감사 정책**

```bash
sudo -i
mkdir -p /etc/kubernetes/audit
cat <<'EOF' > /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata
  resources:
  - group: ""              # core API 그룹
    resources: ["secrets"]
- level: None              # 나머지는 기록 안 함
EOF
```

규칙은 **위에서부터 처음 맞는 것 하나**만 적용됩니다. `level: None` 을 위에 두면 Secret 도 기록되지 않습니다.

| level | 기록 내용 |
|---|---|
| `None` | 기록 안 함 |
| `Metadata` | 사용자·동사·리소스·시각·응답 코드 (요청/응답 본문 없음) |
| `Request` | Metadata + 요청 본문 |
| `RequestResponse` | Metadata + 요청·응답 본문 — Secret 에 쓰면 값이 로그에 남는다 |

**2) kube-apiserver 설정 — 백업 먼저**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # 백업은 manifests 밖에
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxbackup=2
    # ... 기존 플래그 그대로
    volumeMounts:
    - name: audit-policy
      mountPath: /etc/kubernetes/audit/policy.yaml
      readOnly: true
    - name: audit-log
      mountPath: /var/log/kubernetes/audit/
    # ... 기존 volumeMounts
  volumes:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit/policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
  # ... 기존 volumes
```

kube-apiserver 는 컨테이너 안에서 돌기 때문에 플래그만 넣으면 정책 파일을 찾지 못하고 죽습니다. 정책 파일과 로그 디렉터리를 **hostPath 로
마운트**해야 합니다. 백업 파일을 `/etc/kubernetes/manifests/` 안에 두면 kubelet 이 그것도 static Pod 로 띄우려 하므로 밖에 둡니다.

```bash
# 재시작 확인: 저장하면 kubelet 이 Pod 를 다시 만든다
watch crictl ps --name kube-apiserver               # 새 컨테이너 ID, Running
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo ready

# 안 뜰 때
crictl ps -a --name kube-apiserver                  # Exited 반복
ls /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/
tail -20 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
journalctl -u kubelet --since '-5min' | grep -i apiserver | tail   # YAML 문법 오류는 여기
# 복구: cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

**3) 요청을 만들고 이벤트 찾기**

```bash
kubectl -n f16 get secret api-key
grep '"resource":"secrets"' /var/log/kubernetes/audit/audit.log \
  | grep '"namespace":"f16"' | grep '"name":"api-key"' | grep '"verb":"get"' \
  | grep 'kubernetes-admin' | tail -1 > /opt/course/f16/event.json
cat /opt/course/f16/event.json
# {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"...","stage":"ResponseComplete",
#  "requestURI":"/api/v1/namespaces/f16/secrets/api-key","verb":"get","user":{"username":"kubernetes-admin",...},
#  "objectRef":{"resource":"secrets","namespace":"f16","name":"api-key","apiVersion":"v1"},"responseStatus":{"code":200},...}
```

`RequestReceived` 를 뺐으므로 한 요청당 `ResponseComplete` 이벤트 하나가 남습니다. `level` 이 `Metadata` 라 `requestObject`/`responseObject` 가 없습니다.
kubeadm admin kubeconfig 의 사용자 이름은 버전에 따라 `kubernetes-admin` 또는 `kubernetes-super-admin` 일 수 있으니 `kubectl auth whoami` 로 확인합니다.

## 검증

```bash
grep -E 'audit-(policy-file|log-path|log-maxbackup)' /etc/kubernetes/manifests/kube-apiserver.yaml
python3 -c 'import json,sys; e=json.load(open("/opt/course/f16/event.json")); print(e["level"], e["stage"], e["verb"], e["objectRef"]["name"])'
# Metadata ResponseComplete get api-key
grep -c '"resource":"pods"' /var/log/kubernetes/audit/audit.log           # 0 (Secret 외에는 기록 안 됨)
grep -c 'RequestReceived' /var/log/kubernetes/audit/audit.log             # 0
grep -c 'requestObject\|responseObject' /var/log/kubernetes/audit/audit.log   # 0
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 플래그 3개(`--audit-policy-file`, `--audit-log-path`, `--audit-log-maxbackup`) + volume/volumeMount 2쌍(정책 파일, 로그 디렉터리). 규칙은 첫 매치, 마지막에 catch-all.
- **헷갈리는 지점**: Secret 을 `Request`/`RequestResponse` 로 기록하면 값이 감사 로그에 그대로 남아 오히려 유출 경로가 됩니다. `omitStages` 는 정책 최상위(모든 규칙)와 규칙별 둘 다 쓸 수 있습니다. 정책 파일만 고친 경우 kube-apiserver 는 재시작해야 새 정책을 읽습니다.

## 참고 문서

- 검색어: `auditing`, `audit policy`, `kube-apiserver audit-log-maxbackup`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q17 →](../q17_delete_privileged_writable_pods/question.md)
