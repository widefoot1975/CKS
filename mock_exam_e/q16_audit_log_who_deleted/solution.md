# q16 — Find who deleted a ConfigMap in the audit log · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> ConfigMap `app-config` in namespace `billing` has disappeared. Use the audit log
> `/var/log/kubernetes/audit/audit.log` on `cks-c1` to investigate.
>
> 1. Find the audit event of the request that deleted ConfigMap `app-config` in namespace
>    `billing`. Write the username that made the request to `/opt/course/e16/user.txt`.
> 2. Write the `requestReceivedTimestamp` of this event to `/opt/course/e16/time.txt`.
> 3. Write the total number of `delete` requests for ConfigMaps in namespace `billing` that
>    are recorded in the log to `/opt/course/e16/deletes.txt`.

**해석**

namespace `billing` 의 ConfigMap `app-config` 가 사라졌다. `cks-c1` 의 감사 로그 `/var/log/kubernetes/audit/audit.log` 로 조사한다.

1. `billing` 의 ConfigMap `app-config` 를 삭제한 요청의 감사 이벤트를 찾아, 요청한 사용자 이름을 `/opt/course/e16/user.txt` 에 쓴다.
2. 이 이벤트의 `requestReceivedTimestamp` 를 `/opt/course/e16/time.txt` 에 쓴다.
3. 로그에 기록된 `billing` namespace ConfigMap 에 대한 `delete` 요청의 총 개수를 `/opt/course/e16/deletes.txt` 에 쓴다.

## 모범 풀이

**0) 감사 로그 형식 — 한 줄에 JSON 이벤트 하나**

```bash
grep audit /etc/kubernetes/manifests/kube-apiserver.yaml     # --audit-log-path, --audit-policy-file 확인
tail -1 /var/log/kubernetes/audit/audit.log | jq .
```

```json
{
  "kind": "Event", "apiVersion": "audit.k8s.io/v1", "level": "Metadata",
  "auditID": "…", "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/billing/configmaps/app-config", "verb": "delete",
  "user": { "username": "system:serviceaccount:billing:…", "groups": ["system:serviceaccounts", …] },
  "sourceIPs": ["192.168.x.x"], "userAgent": "curl/…",
  "objectRef": { "resource": "configmaps", "namespace": "billing", "name": "app-config", "apiVersion": "v1" },
  "responseStatus": { "code": 200 },
  "requestReceivedTimestamp": "2026-…Z", "stageTimestamp": "2026-…Z"
}
```

**1) · 2) 삭제 이벤트 찾기**

```bash
L=/var/log/kubernetes/audit/audit.log
jq -c 'select(.verb=="delete" and .objectRef.resource=="configmaps"
              and .objectRef.namespace=="billing" and .objectRef.name=="app-config")
       | {user: .user.username, t: .requestReceivedTimestamp, code: .responseStatus.code, ip: .sourceIPs[0]}' $L
# {"user":"system:serviceaccount:billing:cleanup-bot","t":"2026-10-24T10:20:31.123456Z","code":200,"ip":"192.168.x.x"}

jq -r 'select(.verb=="delete" and .objectRef.resource=="configmaps" and .objectRef.namespace=="billing" and .objectRef.name=="app-config")
       | .user.username' $L > /opt/course/e16/user.txt
jq -r 'select(.verb=="delete" and .objectRef.resource=="configmaps" and .objectRef.namespace=="billing" and .objectRef.name=="app-config")
       | .requestReceivedTimestamp' $L > /opt/course/e16/time.txt
cat /opt/course/e16/user.txt /opt/course/e16/time.txt
```

`objectRef.name` 까지 걸러야 합니다. 같은 namespace 에서 다른 SA(`janitor`)가 `old-config` 를 지운 이벤트도 있어서, 리소스와 namespace 만으로
거르면 사용자가 둘 나옵니다. 정책이 `RequestReceived` 단계를 생략하므로 요청 하나에 이벤트가 하나(`ResponseComplete`)입니다. 생략하지 않았다면
같은 `auditID` 로 두 줄이 나오니 `select(.stage=="ResponseComplete")` 를 추가합니다.

**3) delete 횟수**

```bash
jq -c 'select(.verb=="delete" and .objectRef.resource=="configmaps" and .objectRef.namespace=="billing")' $L | wc -l > /opt/course/e16/deletes.txt
cat /opt/course/e16/deletes.txt        # 2
jq -r 'select(.verb=="delete" and .objectRef.namespace=="billing") | [.objectRef.name, .user.username] | @tsv' $L
# old-config  system:serviceaccount:billing:janitor
# app-config  system:serviceaccount:billing:cleanup-bot
```

| 필드 | 뜻 |
|---|---|
| `user.username` | 인증된 사용자 (SA 는 `system:serviceaccount:<ns>:<name>`) |
| `impersonatedUser` | `--as` 로 가장한 경우 실제로 행세한 사용자 |
| `sourceIPs` | 요청한 클라이언트 IP (프록시를 거치면 여러 개) |
| `responseStatus.code` | 200 성공, 403 RBAC 거부, 404 없음 |
| `stage` | `RequestReceived` / `ResponseStarted` / `ResponseComplete` / `Panic` |

## 검증

```bash
cat /opt/course/e16/user.txt        # system:serviceaccount:billing:cleanup-bot
cat /opt/course/e16/time.txt        # 2026-...Z (RFC3339, 마이크로초)
cat /opt/course/e16/deletes.txt     # 2
kubectl auth can-i delete configmaps -n billing --as system:serviceaccount:billing:cleanup-bot   # yes (권한이 있었음)
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `jq -c 'select(.verb=="delete" and .objectRef.resource=="configmaps" and .objectRef.namespace=="<ns>" and .objectRef.name=="<n>") | .user.username' audit.log`. 감사 로그 위치는 apiserver 의 `--audit-log-path`.
- **헷갈리는 지점**: 감사 정책 수준이 `None` 인 요청은 로그에 아예 없습니다. 로그가 회전(`--audit-log-maxbackup`)되었으면 `audit-*.log` 백업 파일도 함께 봐야 합니다. `kubectl delete` 로 지웠다면 `userAgent` 가 `kubectl/...`, 여기서는 curl 로 보낸 요청이라 `curl/...` 입니다. `jq` 가 없으면 `grep '"verb":"delete"' | grep app-config` 로도 찾을 수 있습니다.

## 참고 문서

- 검색어: `auditing`, `audit policy`, `audit event`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q17 →](../q17_crictl_find_root_container/question.md)
