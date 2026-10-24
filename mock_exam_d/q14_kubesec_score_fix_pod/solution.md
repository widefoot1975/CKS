# q14 — Raise a Pod's kubesec score · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The manifest `/opt/course/d14/pod.yaml` must pass a static security review with `kubesec`
> before it may be deployed.
>
> 1. Scan the manifest with `kubesec scan` and write only the numeric score to
>    `/opt/course/d14/before.txt`.
> 2. Edit `/opt/course/d14/pod.yaml` in place: remove the privileged mode and, in the
>    container's `securityContext`, set `readOnlyRootFilesystem: true`, `runAsNonRoot: true`,
>    `runAsUser: 10001`, `allowPrivilegeEscalation: false` and drop all capabilities. Add
>    resource requests `cpu: 50m`, `memory: 32Mi` and limits `cpu: 100m`, `memory: 64Mi`.
> 3. Scan again and write only the score to `/opt/course/d14/after.txt`. The score must be at
>    least `6` with no critical findings. Then create the Pod from the file; it must be
>    `Running` in namespace `beryl`.

**해석**

매니페스트 `/opt/course/d14/pod.yaml` 은 배포 전에 `kubesec` 정적 보안 검토를 통과해야 한다.

1. `kubesec scan` 으로 매니페스트를 스캔해 점수 숫자만 `/opt/course/d14/before.txt` 에 쓴다.
2. `/opt/course/d14/pod.yaml` 을 그 자리에서 고친다. privileged 모드를 없애고, 컨테이너 `securityContext` 에
   `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `runAsUser: 10001`, `allowPrivilegeEscalation: false` 를 넣고 모든
   capability 를 버린다. 리소스 requests `cpu: 50m`, `memory: 32Mi`, limits `cpu: 100m`, `memory: 64Mi` 를 넣는다.
3. 다시 스캔해 점수만 `/opt/course/d14/after.txt` 에 쓴다. 점수는 `6` 이상이고 critical 항목이 없어야 한다. 그 다음 파일로 Pod 를
   만든다. namespace `beryl` 에서 `Running` 이어야 한다.

## 모범 풀이

**1) 첫 스캔**

```bash
cat /opt/course/d14/pod.yaml
kubesec scan /opt/course/d14/pod.yaml
# [ { "object": "Pod/agent.beryl", "valid": true, "message": "Failed with a score of -30 points",
#     "score": -30,
#     "scoring": { "critical": [ { "id": "Privileged", "selector": "containers[] .securityContext .privileged == true", "points": -30 } ],
#                  "advise": [ ... ] } } ]
kubesec scan /opt/course/d14/pod.yaml | grep '"score"' | grep -oE -- '-?[0-9]+' > /opt/course/d14/before.txt
cat /opt/course/d14/before.txt       # -30
```

kubesec 은 **critical** 항목(privileged, hostPID, hostNetwork, `CAP_SYS_ADMIN` 등)이 하나라도 있으면 큰 음수 점수를 주고
"Failed" 로 표시합니다. `advise` 목록은 점수를 올릴 수 있는 항목과 각 점수입니다. `jq` 가 있으면 `kubesec scan pod.yaml | jq '.[0].score'`.

**2) 매니페스트 수정**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: agent
  namespace: beryl
spec:
  containers:
  - name: agent
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 10001
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    resources:
      requests:
        cpu: 50m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 64Mi
```

`privileged: false` 로 바꾸든 줄을 지우든 critical 은 사라집니다(기본값이 false). 각 항목은 대략 +1 점입니다.

| 항목 | kubesec id | 점수 |
|---|---|---|
| `privileged: true` | Privileged | -30 (critical) |
| `readOnlyRootFilesystem: true` | ReadOnlyRootFilesystem | +1 |
| `runAsNonRoot: true` | RunAsNonRoot | +1 |
| `runAsUser` > 10000 | RunAsUser | +1 |
| `capabilities.drop` (ALL 포함) | CapDropAny, CapDropAll | +1, +1 |
| requests/limits cpu·memory | RequestsCPU, RequestsMemory, LimitsCPU, LimitsMemory | 각 +1 |

`runAsUser: 1000` 처럼 10000 이하면 RunAsUser 점수를 받지 못합니다(호스트 사용자와 UID 가 겹칠 위험이 낮은 큰 값을 권장).

**3) 다시 스캔하고 배포**

```bash
kubesec scan /opt/course/d14/pod.yaml | grep -E '"(score|message)"'
# "message": "Passed with a score of 9 points",
# "score": 9,
kubesec scan /opt/course/d14/pod.yaml | grep '"score"' | grep -oE -- '-?[0-9]+' > /opt/course/d14/after.txt
kubectl apply -f /opt/course/d14/pod.yaml
kubectl -n beryl wait --for=condition=Ready pod/agent --timeout=60s
```

busybox `sleep` 은 파일을 쓰지 않으므로 읽기 전용 루트와 UID 10001 로도 그대로 뜹니다. 실제 앱이라면 쓰기가 필요한 경로에
`emptyDir` 를 붙여야 합니다.

## 검증

```bash
cat /opt/course/d14/before.txt /opt/course/d14/after.txt       # -30 / 9 (6 이상)
kubesec scan /opt/course/d14/pod.yaml | grep -A2 '"critical"'  # "critical": [] 또는 항목 없음
kubectl -n beryl get pod agent                                 # 1/1 Running
kubectl -n beryl exec agent -- id                              # uid=10001
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `kubesec scan <파일>` → `score`, `scoring.critical`, `scoring.advise`. critical 을 먼저 없애고 advise 로 점수를 올린다.
- **헷갈리는 지점**: kubesec 은 파일만 읽는 정적 검사라 클러스터에 아무것도 만들지 않습니다(`kubectl get -o yaml` 로 뽑은 것도 스캔 가능). 점수 계산은 kubesec 버전마다 조금씩 다르므로 정확한 점수보다 critical 0 개와 기준 이상을 맞춥니다.

## 참고 문서

시험 중에는 kubesec 문서를 열 수 없으므로 `kubesec scan --help` 로 확인합니다.

- 검색어: `configure a security context`, `resource management for pods and containers`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q15 →](../q15_falco_shell_alert_delete_pod/question.md)
