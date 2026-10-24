# q17 — Investigate a privileged hostPath Pod · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A monitoring alert reports a Pod in namespace `marketing` that runs privileged with access to the
> host. API auditing is enabled; the log is `/var/log/kubernetes/audit/audit.log` on `cks-c1`.
>
> 1. **Identify.** Write the following lines (`key=value`, in this order) to `/opt/course/c17/report.txt`:
>    - `pod=<name of the Pod>`
>    - `node=<node the Pod runs on>`
>    - `creator=<username that created the Pod, as recorded in the audit log>`
>    - `created=<requestReceivedTimestamp of the audit event that created the Pod>`
>    - `sourceip=<first source IP of that request>`
>    - `hostfile=<absolute path on the node of the file the Pod wrote to the host filesystem>`
> 2. **Contain.** Delete the Pod and the workload object that created it. Remove the creator's
>    permission to create Pods in `marketing` by deleting the RoleBinding that grants it. Keep the
>    ServiceAccount itself.
> 3. **Eradicate.** Delete the file the Pod wrote on the node.
> 4. **Prevent.** Label namespace `marketing` so that Pod Security Admission enforces the `baseline`
>    standard (version `latest`) and warns on `restricted`. Deployment `campaign-web` must keep
>    running. Prove that the malicious Pod would now be rejected with a server-side dry run of its
>    manifest, and save the output to `/opt/course/c17/dry-run.txt`.

**해석**

모니터링 알림이 namespace `marketing` 에서 호스트에 접근하는 privileged Pod 를 보고했다. 감사 로그가 켜져 있고 로그는 `cks-c1` 의
`/var/log/kubernetes/audit/audit.log` 다.

1. **식별**: `/opt/course/c17/report.txt` 에 순서대로 `pod=`(Pod 이름), `node=`(실행 노드), `creator=`(감사 로그에 기록된, Pod 를 만든
   사용자 이름), `created=`(그 생성 이벤트의 `requestReceivedTimestamp`), `sourceip=`(그 요청의 첫 번째 출발지 IP), `hostfile=`(Pod 가 노드
   파일시스템에 쓴 파일의 노드 기준 절대 경로)를 쓴다.
2. **차단**: Pod 와 그 Pod 를 만든 워크로드 객체를 지운다. 생성자가 `marketing` 에서 Pod 를 만들 수 있게 해 주는 RoleBinding 을
   지워 권한을 없앤다. ServiceAccount 자체는 남긴다.
3. **제거**: Pod 가 노드에 쓴 파일을 지운다.
4. **예방**: namespace `marketing` 에 PSA 가 `baseline`(버전 `latest`)을 강제하고 `restricted` 위반은 경고하도록 라벨을 붙인다.
   Deployment `campaign-web` 은 계속 실행되어야 한다. 그 악성 Pod 매니페스트를 서버 측 dry run 해서 이제 거부됨을 보이고 출력을
   `/opt/course/c17/dry-run.txt` 에 저장한다.

## 모범 풀이

**1) 수상한 Pod 찾기**

```bash
alias k=kubectl
k -n marketing get pod -o wide
k -n marketing get pod -o json | jq -r '.items[] |
  select(.spec.hostPID or .spec.hostNetwork or any(.spec.containers[]; .securityContext.privileged == true) or any(.spec.volumes[]?; .hostPath)) |
  "\(.metadata.name) \(.spec.nodeName) ownerRefs=\(.metadata.ownerReferences // [] | length)"'
# analytics-agent cks-c1-w1 ownerRefs=0        ← 컨트롤러 없이 직접 만든 Pod
k -n marketing get pod analytics-agent -o yaml | grep -A12 'containers:'
#   command: sh -c 'echo c17-marker > /host/tmp/.analytics-cache; sleep 1d'
#   securityContext: privileged: true
#   volumeMounts: /host  ← hostPath: /   → 컨테이너의 /host/tmp/x = 노드의 /tmp/x
```

**2) 감사 로그로 생성자 추적**

```bash
LOG=/var/log/kubernetes/audit/audit.log
jq -c 'select(.verb=="create" and .objectRef.resource=="pods" and .objectRef.namespace=="marketing"
              and .objectRef.subresource==null and .responseStatus.code==201)
       | {name: (.objectRef.name // .responseObject.metadata.name), user: .user.username, ts: .requestReceivedTimestamp, ip: .sourceIPs[0], ua: .userAgent}' $LOG
# {"name":"analytics-agent","user":"system:serviceaccount:marketing:campaign-bot","ts":"2026-...Z","ip":"10.0.1.23","ua":"curl/8.10.1"}
# {"name":"campaign-web-...","user":"system:serviceaccount:kube-system:replicaset-controller",...}   ← 정상 Pod
```

`user.username` 이 ReplicaSet 컨트롤러가 아니라 ServiceAccount 이고 `userAgent` 가 `curl` 이면 누군가 토큰으로 API 를 직접 호출한
것입니다. `sourceIPs` 는 그 요청을 보낸 Pod 의 IP 입니다. 그 IP·SA 로 출처 워크로드를 찾습니다.

```bash
k -n marketing get pod -o wide | grep <sourceip>                                    # 이미 끝난 Job Pod
k -n marketing get job -o custom-columns=NAME:.metadata.name,SA:.spec.template.spec.serviceAccountName
# campaign-sync  campaign-bot
k -n marketing get rolebinding -o wide | grep campaign-bot                         # campaign-bot-pods → Role pod-creator

cat > /opt/course/c17/report.txt <<'EOF'
pod=analytics-agent
node=cks-c1-w1
creator=system:serviceaccount:marketing:campaign-bot
created=<위 jq 의 ts 값>
sourceip=<위 jq 의 ip 값>
hostfile=/tmp/.analytics-cache
EOF
```

**3) 차단 — 증거를 먼저 남기고 삭제**

```bash
# 증거 보존 + 5) 의 dry run 용: 상태·식별 필드를 걷어낸 매니페스트
# (resourceVersion 이 남아 있으면 admission 전에 "should not be set on objects to be created" 로 실패한다)
k -n marketing get pod analytics-agent -o json \
  | jq 'del(.status, .metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.managedFields)' \
  > /opt/course/c17/analytics-agent.json
k -n marketing delete pod analytics-agent --grace-period=0 --force
k -n marketing delete job campaign-sync
k -n marketing delete rolebinding campaign-bot-pods
k auth can-i create pods -n marketing --as=system:serviceaccount:marketing:campaign-bot     # no
```

Job 을 지우지 않으면(또는 CronJob 이었다면) 같은 Pod 가 다시 만들어질 수 있습니다. SA 는 남기라고 했으므로 권한만 뺏습니다.
실제 사고라면 SA 토큰이 유출되었을 수 있으니 SA 를 새로 만들거나 토큰을 무효화(바인딩된 토큰은 Pod 삭제로 무효화)합니다.

**4) 제거 — 노드의 파일**

```bash
ssh cks-c1-w1 'sudo ls -l /tmp/.analytics-cache && sudo rm -f /tmp/.analytics-cache'
```

**5) 예방 — PSA 라벨과 dry run**

```bash
k label ns marketing \
  pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted  pod-security.kubernetes.io/warn-version=latest
# Warning: existing pods in namespace "marketing" violate the new PodSecurity enforce level ...  ← 있다면 확인 대상

k create --dry-run=server -f /opt/course/c17/analytics-agent.json 2>&1 | tee /opt/course/c17/dry-run.txt
# Error from server (Forbidden): ... violates PodSecurity "baseline:latest": host namespaces (hostPID=true),
#   privileged (container "agent" must not set securityContext.privileged=true),
#   hostPath volumes (volume "host")
k -n marketing get deploy campaign-web          # 계속 READY
```

PSA 라벨은 **새로 만들거나 고치는** Pod 만 검사하고 실행 중인 Pod 는 쫓아내지 않습니다. 그래서 먼저 지우고(차단) 라벨을
붙였습니다(예방). `campaign-web`(nginx)은 baseline 을 만족하므로 계속 돌고, `warn=restricted` 경고만 받습니다.

| 단계 | 한 일 | 근거 |
|---|---|---|
| 식별 | Pod·노드·hostPath 쓰기 경로 | Pod spec |
| 추적 | 생성자 SA, 시각, 출발지 IP | 감사 로그 `user`, `requestReceivedTimestamp`, `sourceIPs` |
| 차단 | Pod·Job 삭제, RoleBinding 삭제 | 재생성·재발 방지 |
| 제거 | 노드의 파일 삭제 | 호스트 영향 원복 |
| 예방 | PSA baseline enforce | privileged·hostPID·hostPath 거부 |

## 검증

```bash
cat /opt/course/c17/report.txt
k -n marketing get pod,job                                   # campaign-web 만
k -n marketing get rolebinding | grep campaign-bot || echo none
k -n marketing get sa campaign-bot                           # 남아 있음
k get ns marketing --show-labels | tr ',' '\n' | grep pod-security
ssh cks-c1-w1 'ls /tmp/.analytics-cache 2>&1'                # No such file
grep -i forbidden /opt/course/c17/dry-run.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 사고 대응 순서 = 식별 → 증거 보존 → 차단(워크로드·권한) → 제거(호스트 흔적) → 예방(PSA/정책). 생성자는 Pod 가 아니라 **감사 로그**에서 찾는다.
- **헷갈리는 지점**: 컨트롤러가 만든 Pod 의 생성자는 `replicaset-controller` 같은 시스템 SA 이므로, 실제 책임자는 Deployment/Job 을 만든 이벤트를 따로 찾아야 합니다. PSA 라벨은 기존 Pod 를 지우지 않습니다. `kubectl create --dry-run=server` 는 admission 까지 거치므로 PSA 거부를 확인할 수 있고, `--dry-run=client` 는 확인하지 못합니다.

## 참고 문서

- 검색어: `auditing`, `pod security admission`, `enforce pod security standards with namespace labels`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md)
