# q16 — Audit impersonation and pods/exec · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Enable API auditing on the kube-apiserver of `cks-c1` and use it to investigate.
>
> 1. Create the audit policy `/etc/kubernetes/audit/policy.yaml` (`audit.k8s.io/v1`):
>    - never generate events for the stage `RequestReceived`
>    - log `pods/exec` and `pods/attach` requests in all namespaces at level `RequestResponse`
>    - log every request made by any ServiceAccount of namespace `c16` at level `RequestResponse`,
>      including requests in which such a ServiceAccount impersonates another user
>    - do not log requests to the non-resource URLs `/healthz*`, `/livez*` and `/readyz*`
>    - log everything else at level `Metadata`
> 2. Configure the kube-apiserver to use this policy and write the log to
>    `/var/log/kubernetes/audit/audit.log`, rotating at `50` MB and keeping `2` old files.
> 3. When the kube-apiserver is running again, run `kubectl -n c16 exec shell -- id` and wait until
>    CronJob `sync` has run at least once after auditing was enabled.
> 4. Find the audit event in which a request was made with impersonation. Write one line to
>    `/opt/course/c16/impersonation.txt`:
>    `user=<authenticated user> impersonated=<impersonated user> resource=<resource> namespace=<namespace>`
> 5. Write the `level` and the `requestURI` of the audit event of your `exec` request, one per line,
>    to `/opt/course/c16/exec.txt`.

**해석**

`cks-c1` 의 kube-apiserver 에 감사 로그를 켜고 조사에 쓴다.

1. 감사 정책 `/etc/kubernetes/audit/policy.yaml`(`audit.k8s.io/v1`)을 만든다.
   - `RequestReceived` 단계 이벤트는 만들지 않는다.
   - 모든 namespace 의 `pods/exec`, `pods/attach` 요청은 `RequestResponse`.
   - namespace `c16` 의 ServiceAccount 가 보낸 모든 요청은 `RequestResponse`. 그 SA 가 다른 사용자로 가장한 요청도 포함.
   - non-resource URL `/healthz*`, `/livez*`, `/readyz*` 요청은 기록하지 않는다.
   - 나머지는 `Metadata`.
2. kube-apiserver 가 이 정책을 쓰고 로그를 `/var/log/kubernetes/audit/audit.log` 에 쓰게 한다. 50 MB 에서 회전, 이전 파일 2개 보관.
3. API 서버가 다시 뜨면 `kubectl -n c16 exec shell -- id` 를 실행하고, 감사가 켜진 뒤 CronJob `sync` 가 한 번 이상 실행될 때까지 기다린다.
4. 가장(impersonation)으로 만들어진 요청의 감사 이벤트를 찾아 `user=<인증된 사용자> impersonated=<가장한 사용자> resource=<리소스> namespace=<ns>` 한 줄을 쓴다.
5. 내 `exec` 요청 이벤트의 `level` 과 `requestURI` 를 한 줄씩 `/opt/course/c16/exec.txt` 에 쓴다.

## 모범 풀이

**1) 정책 — 위에서부터 첫 번째로 맞는 규칙이 적용된다**

```bash
mkdir -p /etc/kubernetes/audit
vi /etc/kubernetes/audit/policy.yaml
```

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
# 1. 헬스 체크 소음 제거 (가장 먼저)
- level: None
  nonResourceURLs:
  - /healthz*
  - /livez*
  - /readyz*
# 2. exec / attach
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach"]
# 3. c16 의 ServiceAccount (가장 요청 포함)
- level: RequestResponse
  userGroups: ["system:serviceaccounts:c16"]
# 4. 나머지
- level: Metadata
```

| 함정 | 설명 |
|---|---|
| 규칙 순서 | 첫 매칭 규칙만 적용. `Metadata` catch-all 을 위에 두면 아래 규칙은 영원히 안 쓰임 |
| exec 의 동사 | kubectl 버전에 따라 exec 는 `create`(SPDY) 또는 웹소켓 업그레이드 `get` 으로 들어옴 → `verbs` 를 제한하지 않음 |
| 가장(impersonation) 요청 | 감사 정책은 **인증된 원래 사용자**(`system:serviceaccount:c16:robot`)로 매칭됨. `users: ["jane"]` 처럼 가장 대상 이름으로 규칙을 쓰면 안 맞음 |
| SA 를 이름 하나로 | `users: [system:serviceaccount:c16:robot]` 도 되지만 "모든 SA" 는 그룹 `system:serviceaccounts:c16` 이 정확 |

**2) kube-apiserver 수정**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.c16     # manifests 밖에 백업
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxsize=50
    - --audit-log-maxbackup=2
    volumeMounts:
    - mountPath: /etc/kubernetes/audit/policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit/
      name: audit-log
      readOnly: false
  volumes:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit/policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
```

```bash
watch -n2 'crictl ps --name kube-apiserver'
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo ready
# 안 뜨면: tail /var/log/pods/kube-system_kube-apiserver-cks-c1_*/kube-apiserver/*.log
#          정책 YAML 오류("failed to read audit policy")나 볼륨 누락이 대부분 → 백업으로 복구
ls -l /var/log/kubernetes/audit/
```

`--audit-log-maxsize` 는 MB 단위, `--audit-log-maxbackup` 은 보관할 이전 파일 수입니다. 로그 디렉터리 볼륨은 쓰기 가능해야 합니다.

**3) 이벤트 만들기**

```bash
kubectl -n c16 exec shell -- id
kubectl -n c16 get job --sort-by=.metadata.creationTimestamp | tail -2      # 감사 활성화 이후 시작된 Job 이 있는지
```

**4) 가장 이벤트 찾기**

```bash
LOG=/var/log/kubernetes/audit/audit.log
jq -c 'select(.impersonatedUser != null) | {user: .user.username, imp: .impersonatedUser.username, verb, res: .objectRef.resource, ns: .objectRef.namespace, level}' $LOG | tail -3
# {"user":"system:serviceaccount:c16:robot","imp":"jane","verb":"list","res":"configmaps","ns":"c16","level":"RequestResponse"}

jq -r 'select(.impersonatedUser != null) | "user=\(.user.username) impersonated=\(.impersonatedUser.username) resource=\(.objectRef.resource) namespace=\(.objectRef.namespace)"' $LOG \
  | tail -1 > /opt/course/c16/impersonation.txt
cat /opt/course/c16/impersonation.txt
# user=system:serviceaccount:c16:robot impersonated=jane resource=configmaps namespace=c16
```

`user` 는 실제로 인증한 주체, `impersonatedUser` 는 `Impersonate-User` 헤더(또는 `kubectl --as`)로 지정한 대상입니다. 권한 검사는
가장 대상(jane)으로 하지만, 감사 로그에는 둘 다 남아 누가 실제로 했는지 추적할 수 있습니다. 레벨이 `RequestResponse` 인 것도
규칙 3 이 원래 사용자로 매칭되었다는 증거입니다.

**5) exec 이벤트**

```bash
jq -c 'select(.objectRef.subresource=="exec" and .objectRef.name=="shell") | {level, verb, stage, requestURI}' $LOG
# {"level":"RequestResponse","verb":"create","stage":"ResponseStarted","requestURI":"/api/v1/namespaces/c16/pods/shell/exec?command=id&container=shell&stderr=true&stdout=true"}
# {"level":"RequestResponse", ... "stage":"ResponseComplete", ...}
jq -r 'select(.objectRef.subresource=="exec" and .objectRef.name=="shell") | .level, .requestURI' $LOG | head -2 > /opt/course/c16/exec.txt
```

실행한 명령은 `requestURI` 의 `command=` 쿼리에 보입니다. exec 는 스트림 연결이라 레벨이 `RequestResponse` 여도 입출력 내용(`id` 의 결과)은 기록되지 않습니다.

## 검증

```bash
grep -E 'audit-(policy-file|log-path|log-maxsize|log-maxbackup)' /etc/kubernetes/manifests/kube-apiserver.yaml
jq -r 'select(.stage=="RequestReceived")' /var/log/kubernetes/audit/audit.log | head -1     # 아무것도 없음
jq -r 'select(.requestURI|startswith("/readyz"))' /var/log/kubernetes/audit/audit.log | head -1   # 없음
cat /opt/course/c16/impersonation.txt /opt/course/c16/exec.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 정책은 first-match, `omitStages` 는 전역. 플래그 4개 + 정책 파일(ro)·로그 디렉터리(rw) hostPath 볼륨 2개.
- **헷갈리는 지점**: 가장 요청은 원래 사용자 기준으로 규칙이 매칭되고 이벤트에 `impersonatedUser` 필드가 붙습니다. 레벨: `None` < `Metadata` < `Request`(요청 본문) < `RequestResponse`(응답 본문까지). 로그 파일은 `/var/log/kubernetes/audit/` 아래이며 `kubectl logs` 로는 볼 수 없습니다.

## 참고 문서

- 검색어: `auditing`, `audit policy`, `user impersonation`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#user-impersonation

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q17 →](../q17_incident_privileged_hostpath_pod/question.md)
