# q16 — Audit policy with ordered rules and log rotation · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Enable API audit logging on cluster `cks-c1`.
>
> 1. Create the audit policy `/etc/kubernetes/audit/policy.yaml` with these requirements:
>    - do not create events for the stage `RequestReceived`
>    - `get`, `list` and `watch` requests on `nodes` are not logged at all
>    - `secrets` and `configmaps` are logged at level `Metadata` in every namespace,
>      including `prod`
>    - `pods` in namespace `prod` are logged at level `RequestResponse`
>    - every other request in namespace `prod` is logged at level `Request`
>    - everything else is logged at level `Metadata`
> 2. Configure the kube-apiserver to use this policy and to write the log to
>    `/var/log/kubernetes/audit/audit.log`, keeping at most `2` old log files and deleting them
>    after `7` days. The kube-apiserver must be running and healthy afterwards.
> 3. Run `kubectl -n prod get secret prod-db` and write the audit event of this request (one
>    JSON line) to `/opt/course/a16/secret-event.json`.
> 4. Run `kubectl -n prod label pod prod-web audited=yes` and write the audit event of this
>    request (one JSON line) to `/opt/course/a16/pod-event.json`.

**해석**

클러스터 `cks-c1` 에 API 감사 로그를 켠다.

1. 감사 정책 `/etc/kubernetes/audit/policy.yaml` 을 다음 조건으로 만든다.
   - `RequestReceived` 단계의 이벤트는 만들지 않는다
   - `nodes` 에 대한 `get`·`list`·`watch` 는 전혀 기록하지 않는다
   - `secrets`·`configmaps` 는 `prod` 를 포함한 모든 namespace 에서 `Metadata` 수준
   - namespace `prod` 의 `pods` 는 `RequestResponse` 수준
   - `prod` 의 그 밖의 모든 요청은 `Request` 수준
   - 나머지 전부는 `Metadata` 수준
2. kube-apiserver 가 이 정책을 쓰고 로그를 `/var/log/kubernetes/audit/audit.log` 에 쓰게 한다. 오래된 로그 파일은 최대 2개만 남기고
   7일이 지나면 지운다. 끝난 뒤 apiserver 는 정상이어야 한다.
3. `kubectl -n prod get secret prod-db` 를 실행하고 이 요청의 감사 이벤트(JSON 한 줄)를 `/opt/course/a16/secret-event.json` 에 쓴다.
4. `kubectl -n prod label pod prod-web audited=yes` 를 실행하고 이 요청의 감사 이벤트(JSON 한 줄)를 `/opt/course/a16/pod-event.json` 에 쓴다.

## 모범 풀이

**1) 정책 — 위에서부터 처음 맞는 규칙 하나만 적용**

```yaml
# /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  # 1. nodes 조회는 기록 안 함
  - level: None
    verbs: ["get", "list", "watch"]
    resources:
    - group: ""
      resources: ["nodes"]
  # 2. secrets / configmaps 는 어디서든 Metadata (prod 규칙보다 먼저!)
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets", "configmaps"]
  # 3. prod 의 pods 는 RequestResponse
  - level: RequestResponse
    namespaces: ["prod"]
    resources:
    - group: ""
      resources: ["pods"]
  # 4. prod 의 나머지는 Request
  - level: Request
    namespaces: ["prod"]
  # 5. 그 밖의 전부
  - level: Metadata
```

```bash
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
vim /etc/kubernetes/audit/policy.yaml
```

감사 정책은 **첫 번째로 일치하는 규칙**만 적용합니다. 규칙 2 를 규칙 4 아래에 두면 `prod` 의 Secret 이 `Request` 수준으로 기록되어
`kubectl apply`·`create` 때 Secret 값이 요청 본문째 로그에 남습니다(get 은 요청 본문이 없지만 생성·수정은 있음). 그래서 "어디서든"
조건은 namespace 규칙보다 **위**에 둡니다. `resources: ["pods"]` 는 서브리소스(`pods/log`, `pods/exec`)와 일치하지 않으므로, 그것들은
규칙 4 로 내려갑니다(필요하면 `"pods/*"` 를 추가).

| 수준 | 기록 내용 |
|---|---|
| `None` | 기록 안 함 |
| `Metadata` | 사용자, 시각, 리소스, verb, 응답 코드 (본문 없음) |
| `Request` | Metadata + 요청 본문 |
| `RequestResponse` | Metadata + 요청 본문 + 응답 본문 |

**2) apiserver — 플래그 4개 + 볼륨 2개**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
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
    - --audit-log-maxage=7
    # ... 기존 플래그 ...
    volumeMounts:
    - name: audit-policy
      mountPath: /etc/kubernetes/audit/policy.yaml
      readOnly: true
    - name: audit-log
      mountPath: /var/log/kubernetes/audit/
      readOnly: false
    # ... 기존 마운트 ...
  volumes:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit/policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
  # ... 기존 볼륨 ...
```

```bash
watch crictl ps --name kube-apiserver            # 새 컨테이너 Running
kubectl get --raw=/readyz; echo                   # ok
ls -l /var/log/kubernetes/audit/                  # audit.log 가 생기고 커진다
# 안 뜨면
tail -n 5 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
#   ... open /etc/kubernetes/audit/policy.yaml: no such file or directory   ← 볼륨 누락
#   ... strict decoding error: unknown field ...                             ← 정책 YAML 오류
# 복구: cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

로그 디렉터리 마운트는 **쓰기 가능**해야 합니다(`readOnly: false`). `--audit-log-maxbackup` 은 남길 옛 파일 수, `--audit-log-maxage` 는
옛 파일을 지우는 일수, `--audit-log-maxsize` 는 회전 기준 크기(MB)입니다. `--audit-log-path=-` 는 표준출력입니다.

**3) · 4) 이벤트 찾기**

```bash
kubectl -n prod get secret prod-db
jq -c 'select(.objectRef.resource=="secrets" and .objectRef.namespace=="prod" and .objectRef.name=="prod-db" and .verb=="get")' \
  /var/log/kubernetes/audit/audit.log | tail -1 > /opt/course/a16/secret-event.json
jq '{level, stage, verb, user: .user.username, has_body: (has("requestObject") or has("responseObject"))}' /opt/course/a16/secret-event.json
# { "level": "Metadata", "stage": "ResponseComplete", "verb": "get", "user": "kubernetes-admin", "has_body": false }

kubectl -n prod label pod prod-web audited=yes
jq -c 'select(.objectRef.resource=="pods" and .objectRef.namespace=="prod" and .objectRef.name=="prod-web" and .verb=="patch")' \
  /var/log/kubernetes/audit/audit.log | tail -1 > /opt/course/a16/pod-event.json
jq '{level, verb, req: .requestObject, resp_kind: .responseObject.kind}' /opt/course/a16/pod-event.json
# { "level": "RequestResponse", "verb": "patch", "req": {"metadata":{"labels":{"audited":"yes"}}}, "resp_kind": "Pod" }
```

`kubectl label` 은 `patch` 요청입니다. 이벤트는 `ResponseStarted`(watch 같은 긴 요청만)와 `ResponseComplete` 단계로 기록되고,
`RequestReceived` 는 정책에서 뺐으므로 나오지 않습니다.

## 검증

```bash
jq -r '.level' /opt/course/a16/secret-event.json /opt/course/a16/pod-event.json     # Metadata / RequestResponse
jq -r 'select(.stage=="RequestReceived")' /var/log/kubernetes/audit/audit.log | head -1   # 아무것도 없음
jq -r 'select(.objectRef.resource=="nodes" and .verb=="list") | .verb' /var/log/kubernetes/audit/audit.log | head -1   # 없음
kubectl -n prod get cm prod-cfg >/dev/null; sleep 2
jq -r 'select(.objectRef.resource=="configmaps" and .objectRef.namespace=="prod") | .level' /var/log/kubernetes/audit/audit.log | tail -1   # Metadata
pgrep -af kube-apiserver | tr ' ' '\n' | grep audit-
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 정책은 **첫 일치 규칙** — 좁고 민감한 규칙(None, Secret Metadata)이 위, namespace 전체·catch-all 이 아래. apiserver 는 `--audit-policy-file`, `--audit-log-path`, `--audit-log-maxage/maxbackup/maxsize` + 정책 파일(ro)·로그 디렉터리(rw) hostPath.
- **헷갈리는 지점**: Secret 을 `Request`/`RequestResponse` 로 두면 값이 로그에 남습니다. `resources` 의 `group: ""` 는 core 그룹입니다. 서브리소스는 `"pods/log"`, `"pods/*"` 처럼 따로 적습니다. 마지막 catch-all 이 없으면 나머지 요청은 기록되지 않습니다.

## 참고 문서

- 검색어: `auditing`, `audit policy`, `kube-apiserver audit-log-maxage`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q17 →](../q17_immutable_readonly_rootfs_emptydir/question.md)
