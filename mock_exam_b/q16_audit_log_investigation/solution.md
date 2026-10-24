# q16 — Investigate the audit log and reduce its noise · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Audit logging is enabled on the kube-apiserver of `cks-c1`; the log is
> `/var/log/kubernetes/audit/audit.log` and the policy is `/etc/kubernetes/audit/policy.yaml`.
> Something happened in namespace `finance`.
>
> 1. Answer the following questions from the audit log and write the answers to
>    `/opt/course/b16/answers.txt` in exactly this format:
>    ```
>    configmap_deleted_by: <username>
>    secrets_listed_by: <username>
>    secrets_listed_from: <source IP>
>    ```
>    - Which user deleted the ConfigMap `app-config` in namespace `finance`?
>    - Which ServiceAccount listed the Secrets of namespace `finance` (a `list` request on the
>      Secrets of that namespace, not a `get` of a single Secret)? Give its full username.
>    - From which source IP did that ServiceAccount send the request?
> 2. The log is too noisy. Change the audit policy so that `watch` requests made by the users
>    `system:kube-proxy` and `system:serviceaccount:kube-system:cilium` are no longer logged, while
>    everything else is still logged as before. Make sure the running kube-apiserver uses the new
>    policy and is healthy.

**해석**

`cks-c1` 의 kube-apiserver 에 감사 로그가 켜져 있다(로그 `/var/log/kubernetes/audit/audit.log`, 정책 `/etc/kubernetes/audit/policy.yaml`).
`finance` 네임스페이스에서 무슨 일이 있었다.

1. 감사 로그로 다음에 답해 정해진 형식으로 `/opt/course/b16/answers.txt` 에 쓴다.
   - `finance` 의 ConfigMap `app-config` 를 지운 사용자는?
   - `finance` 의 Secret 목록을 조회(`list`, 단일 Secret 의 `get` 이 아님)한 ServiceAccount 는? 전체 사용자 이름으로.
   - 그 ServiceAccount 는 어느 출발지 IP 에서 요청했나?
2. 로그가 너무 시끄럽다. 사용자 `system:kube-proxy` 와 `system:serviceaccount:kube-system:cilium` 의 `watch` 요청은 기록하지 않고 나머지는 전처럼
   기록하도록 정책을 바꾼다. 실행 중인 apiserver 가 새 정책을 쓰고 정상이어야 한다.

## 모범 풀이

**1) 감사 이벤트 구조**

감사 로그는 한 줄에 JSON 이벤트 하나입니다. 자주 쓰는 필드:

| 필드 | 뜻 |
|---|---|
| `verb` | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` |
| `user.username`, `user.groups` | 인증된 주체 (가장(impersonation) 시 실제 요청자, 대상은 `impersonatedUser`) |
| `sourceIPs` | 요청이 들어온 IP 목록(프록시를 거치면 `X-Forwarded-For` 가 앞에) |
| `objectRef.{resource,namespace,name}` | 대상 객체 (list 에는 `name` 이 없음) |
| `stage` | `RequestReceived` / `ResponseStarted` / `ResponseComplete` / `Panic` |
| `responseStatus.code` | HTTP 상태 코드 |

```bash
sudo -i
L=/var/log/kubernetes/audit/audit.log
jq -c 'select(.objectRef.resource=="configmaps" and .objectRef.namespace=="finance" and .verb=="delete")
       | {user: .user.username, name: .objectRef.name, code: .responseStatus.code, ts: .requestReceivedTimestamp}' $L
# {"user":"bob","name":"old-config","code":200,"ts":"..."}
# {"user":"mallory","name":"app-config","code":200,"ts":"..."}
```

> 함정 1: `finance` 에서 ConfigMap 을 지운 사용자는 둘입니다. `objectRef.name=="app-config"` 까지 걸러야 합니다. 또 `bob` 은 `app-config`
> 를 `get` 만 했습니다. `grep app-config` 로 대충 보면 bob 을 답하기 쉽습니다.

```bash
jq -c 'select(.objectRef.resource=="secrets" and .objectRef.namespace=="finance")
       | {verb, user: .user.username, name: .objectRef.name, ip: .sourceIPs, code: .responseStatus.code}' $L
# {"verb":"create","user":"kubernetes-admin","name":"db-pass",...}        ← setup 이 만든 것
# {"verb":"list","user":"system:serviceaccount:finance:harvester","ip":["10.0.1.23"],"code":200}
# {"verb":"get","user":"system:serviceaccount:finance:auditor","name":"api-key","ip":[...],"code":200}
```

`list` 이벤트에는 `objectRef.name` 이 없습니다. `auditor` 는 Secret 하나를 `get` 했으므로 답이 아닙니다.

```bash
cat > /opt/course/b16/answers.txt <<'EOF'
configmap_deleted_by: mallory
secrets_listed_by: system:serviceaccount:finance:harvester
secrets_listed_from: 10.0.1.23
EOF
```

출발지 IP 는 로그에 찍힌 실제 값을 씁니다. Pod 에서 보낸 요청이므로 보통 그 Pod 의 IP 이고, CNI 가 노드 IP 로 SNAT 하는 구성이면 노드 IP 가
찍힙니다. (setup 이 Pod 를 지웠으므로 감사 로그가 유일한 증거입니다 — 그래서 감사 로그가 필요합니다.)

**2) 정책 수정 — 순서가 중요**

```bash
cp /etc/kubernetes/audit/policy.yaml /root/policy.yaml.bak
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
# 시끄러운 watch 는 기록하지 않음 — 반드시 catch-all 보다 위
- level: None
  users: ["system:kube-proxy", "system:serviceaccount:kube-system:cilium"]
  verbs: ["watch"]
# 나머지는 전처럼
- level: Metadata
EOF
```

> 함정 2: 규칙은 **위에서부터 처음 일치한 것** 하나만 적용됩니다. `level: None` 규칙을 맨 아래 catch-all(`- level: Metadata`) 뒤에 붙이면
> 절대 일치하지 않아 아무 효과가 없습니다.

> 함정 3: kube-apiserver 는 감사 정책 파일을 **시작할 때 한 번만** 읽습니다. 파일만 고치면 반영되지 않고, 매니페스트 내용이 그대로이므로
> kubelet 도 Pod 를 재시작하지 않습니다. apiserver 를 직접 재시작해야 합니다.

```bash
mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/
until ! crictl ps --name kube-apiserver -q | grep -q .; do sleep 2; done      # 컨테이너가 내려갈 때까지
mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo ok
# 안 뜨면: tail /var/log/pods/kube-system_kube-apiserver-cks-c1_*/kube-apiserver/*.log
#          (policy.yaml 문법 오류면 백업으로 되돌린 뒤 다시 재시작)
```

매니페스트를 옮겼다 돌려놓는 대신 `crictl stop $(crictl ps --name kube-apiserver -q)` 로 컨테이너만 멈춰도 kubelet 이 다시 띄우면서 새 정책을
읽습니다.

## 검증

```bash
L=/var/log/kubernetes/audit/audit.log
sleep 30
# 재시작 이후(마지막 2000줄)에 두 사용자의 watch 가 없어야 한다
tail -2000 $L | jq -r 'select(.verb=="watch") | .user.username' | sort | uniq -c | sort -rn | head
tail -2000 $L | jq -r 'select(.verb=="watch" and (.user.username=="system:kube-proxy" or .user.username=="system:serviceaccount:kube-system:cilium"))' | wc -l   # 0
kubectl -n finance get cm >/dev/null; tail -50 $L | jq -c 'select(.objectRef.namespace=="finance") | {verb, user: .user.username}'    # 여전히 기록됨
cat /opt/course/b16/answers.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `jq 'select(.verb=="delete" and .objectRef.resource=="configmaps" and .objectRef.name=="X") | .user.username'`. 정책은 first-match, 변경 후 apiserver 재시작.
- **헷갈리는 지점**: `watch` 는 오래 열려 있는 요청이라 `ResponseStarted` 와 `ResponseComplete` 두 단계가 기록됩니다(`omitStages` 로 줄일 수 있음). kube-proxy 를 쓰지 않는 Cilium(kube-proxy 대체) 클러스터에는 `system:kube-proxy` 이벤트가 원래 없을 수 있습니다. `users` 에는 사용자 이름을, `userGroups` 에는 그룹을 씁니다.

## 참고 문서

- 검색어: `auditing`, `audit policy`, `audit backends`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q17 →](../q17_crictl_find_malicious_process/question.md)
