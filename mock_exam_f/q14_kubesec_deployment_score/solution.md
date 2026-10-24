# q14 — Raise the kubesec score of a Deployment · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The manifest of Deployment `billing` must reach a kubesec score of at least `7` before it may be
> deployed.
>
> 1. Run `kubesec scan` on `/opt/course/f14/deploy.yaml` and write only the score (a number) to
>    `/opt/course/f14/before.txt`.
> 2. Edit `/opt/course/f14/deploy.yaml` in place so that kubesec reports no critical findings and a
>    score of at least `7`. Keep the Deployment name, namespace, image and container port. The
>    container needs a writable `/tmp`.
> 3. Write the new score to `/opt/course/f14/after.txt`, then apply the manifest. The Pod of
>    `billing` must be `Running` and Ready.

**해석**

Deployment `billing` 의 매니페스트는 배포 전에 kubesec 점수 `7` 이상이어야 한다.

1. `/opt/course/f14/deploy.yaml` 에 `kubesec scan` 을 돌리고 점수(숫자)만 `/opt/course/f14/before.txt` 에 쓴다.
2. `/opt/course/f14/deploy.yaml` 을 제자리에서 고쳐 kubesec 이 critical 항목 없이 `7` 점 이상을 주게 한다. Deployment 이름, namespace, 이미지,
   컨테이너 포트는 유지한다. 컨테이너는 쓰기 가능한 `/tmp` 가 필요하다.
3. 새 점수를 `/opt/course/f14/after.txt` 에 쓰고 매니페스트를 적용한다. `billing` 의 Pod 는 `Running`·Ready 여야 한다.

## 모범 풀이

**1) 처음 점수**

```bash
kubesec scan /opt/course/f14/deploy.yaml
# [
#   {
#     "object": "Deployment/billing.f14",
#     "valid": true,
#     "message": "Failed with a score of -30 points",
#     "score": -30,
#     "scoring": {
#       "critical": [ { "id": "Privileged", "selector": "containers[] .securityContext .privileged == true", "points": -30, ... } ],
#       "advise": [ { "id": "ApparmorAny", "points": 3 }, { "id": "ServiceAccountName", "points": 3 },
#                   { "id": "SeccompAny", "points": 1 }, { "id": "LimitsCPU", "points": 1 }, ... ]
#     }
#   }
# ]
kubesec scan /opt/course/f14/deploy.yaml | grep -m1 '"score"' | tr -dc '0-9\n-' > /opt/course/f14/before.txt
cat /opt/course/f14/before.txt          # -30
```

jq 가 있으면 `kubesec scan deploy.yaml | jq '.[0].score'` 가 더 깔끔합니다. `advise` 목록이 점수를 올리는 방법과 배점을 그대로 알려 줍니다.

**2) 매니페스트 고치기**

```yaml
# /opt/course/f14/deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing
  namespace: f14
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing
  template:
    metadata:
      labels:
        app: billing
    spec:
      containers:
      - name: billing
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:                 # privileged: true 삭제 (critical -30)
          runAsNonRoot: true             # +1 RunAsNonRoot
          runAsUser: 10101               # +1 RunAsUser (> 10000)
          readOnlyRootFilesystem: true   # +1 ReadOnlyRootFilesystem
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]                # +1 CapDropAny, +1 CapDropAll
        resources:
          requests:                      # +1 RequestsCPU, +1 RequestsMemory
            cpu: 50m
            memory: 64Mi
          limits:                        # +1 LimitsCPU, +1 LimitsMemory
            cpu: 200m
            memory: 128Mi
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

```bash
kubesec scan /opt/course/f14/deploy.yaml | grep -E '"(score|message)"'
#     "message": "Passed with a score of 9 points",
#     "score": 9,
```

| kubesec 항목 | 점수 | 필드 |
|---|---|---|
| Privileged | **-30 (critical)** | `securityContext.privileged: true` |
| HostNetwork / HostPID / HostIPC | -9 (critical) | `hostNetwork`, `hostPID`, `hostIPC` |
| CapSysAdmin | -30 (critical) | `capabilities.add: [SYS_ADMIN]` |
| ReadOnlyRootFilesystem, RunAsNonRoot, RunAsUser(>10000) | +1 씩 | 컨테이너 `securityContext` |
| CapDropAny, CapDropAll | +1 씩 | `capabilities.drop` |
| Requests/Limits CPU·Memory | +1 씩 | `resources` |
| ServiceAccountName, ApparmorAny | +3 씩 | `serviceAccountName`, AppArmor |

kubesec 규칙은 대부분 **컨테이너의** `securityContext` 를 봅니다(`containers[] .securityContext .runAsNonRoot` 같은 selector). Pod 수준에만 넣으면
점수가 오르지 않을 수 있으므로 컨테이너 수준에 둡니다. UID 10101 로 돌아도 nginx-unprivileged 는 `/tmp` 만 쓰고 8080 포트를 쓰므로 동작합니다.

**3) 기록하고 적용**

```bash
kubesec scan /opt/course/f14/deploy.yaml | grep -m1 '"score"' | tr -dc '0-9\n-' > /opt/course/f14/after.txt
cat /opt/course/f14/after.txt           # 9
kubectl apply -f /opt/course/f14/deploy.yaml
kubectl -n f14 rollout status deploy billing
```

## 검증

```bash
kubesec scan /opt/course/f14/deploy.yaml | grep -A1 '"critical"'      # "critical": [] 또는 항목 없음
kubectl -n f14 get pod -l app=billing                                # 1/1 Running
kubectl -n f14 exec deploy/billing -- id                             # uid=10101
cat /opt/course/f14/before.txt /opt/course/f14/after.txt             # -30 / 9
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: critical 하나만 있어도 점수가 음수가 된다. 먼저 `privileged`/`host*`/`SYS_ADMIN` 을 없애고, `advise` 의 +1 항목(읽기 전용 루트, 비 root, 높은 UID, drop, requests/limits)을 채운다.
- **헷갈리는 지점**: kubesec 점수는 보안 수준의 "합격선" 이 아니라 휴리스틱입니다. `ServiceAccountName` +3 같은 항목은 이름만 넣어도 오르므로, 실제 권한(RBAC)까지 맞는지는 따로 봐야 합니다. 시험 중에는 kubesec 문서를 열 수 없으므로 `kubesec scan --help` 와 출력의 `advise` 를 활용합니다.

## 참고 문서

시험 중에는 kubesec 문서를 열 수 없으므로 `kubesec --help`, `kubesec scan --help` 로 확인합니다.

- 검색어: `security context`, `resource management for pods and containers`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q15 →](../q15_falco_detect_write_below_etc/question.md)
