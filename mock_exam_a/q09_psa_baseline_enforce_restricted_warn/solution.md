# q09 — Enforce Pod Security baseline while warning on restricted · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `atlas` must be protected by Pod Security Admission.
>
> 1. Before changing anything, find out which running Pods would violate the Pod Security
>    Standards `baseline` and `restricted`, using a server-side dry run of the namespace
>    label. Write the complete warning output of the `baseline` check to
>    `/opt/course/a09/baseline.txt` and of the `restricted` check to
>    `/opt/course/a09/restricted.txt`.
> 2. Fix Deployment `atlas-agent` so that its Pods satisfy `baseline`: it must not run
>    privileged, and its volume `host-log` must become an `emptyDir` volume (same name, same
>    mount path). Change nothing else.
> 3. Label namespace `atlas` so that `baseline` is enforced, and `restricted` produces
>    warnings and audit annotations. Pin all three modes to version `v1.35`.
> 4. All three Deployments must have their Pods `Running` under the new labels.
> 5. Write the names of the Deployments whose Pods still violate `restricted`, one per line
>    and sorted alphabetically, to `/opt/course/a09/restricted-violators.txt`.

**해석**

namespace `atlas` 를 Pod Security Admission 으로 보호한다.

1. 아무것도 바꾸기 전에, namespace 라벨을 서버 측 dry run 으로 붙여 보아 실행 중인 Pod 중 어떤 것이 `baseline` 과 `restricted` 를 위반하는지 찾는다.
   `baseline` 점검의 경고 출력 전체를 `/opt/course/a09/baseline.txt`, `restricted` 점검은 `/opt/course/a09/restricted.txt` 에 쓴다.
2. Deployment `atlas-agent` 의 Pod 가 `baseline` 을 만족하게 고친다. privileged 로 돌면 안 되고, 볼륨 `host-log` 는 같은 이름·같은 마운트 경로의
   `emptyDir` 볼륨이 되어야 한다. 그 밖에는 바꾸지 않는다.
3. `baseline` 은 강제(enforce)하고 `restricted` 는 경고(warn)와 감사(audit) 어노테이션을 남기도록 namespace 에 라벨을 붙인다. 세 모드 모두 버전 `v1.35` 로 고정한다.
4. 새 라벨 아래에서 세 Deployment 의 Pod 가 모두 `Running` 이어야 한다.
5. 여전히 `restricted` 를 위반하는 Pod 의 Deployment 이름을 알파벳 순으로 한 줄씩 `/opt/course/a09/restricted-violators.txt` 에 쓴다.

## 모범 풀이

**1) dry run 으로 위반 Pod 미리 보기 — 경고는 stderr**

```bash
kubectl label --dry-run=server --overwrite ns atlas pod-security.kubernetes.io/enforce=baseline > /opt/course/a09/baseline.txt 2>&1
kubectl label --dry-run=server --overwrite ns atlas pod-security.kubernetes.io/enforce=restricted > /opt/course/a09/restricted.txt 2>&1
cat /opt/course/a09/baseline.txt
# Warning: existing pods in namespace "atlas" violate the new PodSecurity enforce level "baseline:latest"
# Warning: atlas-agent-7c9d…: privileged, hostPath volumes
# namespace/atlas labeled (server dry run)
cat /opt/course/a09/restricted.txt
# Warning: atlas-agent-7c9d…: privileged, allowPrivilegeEscalation != false, unrestricted capabilities, restricted volume types, runAsNonRoot != true, seccompProfile
# Warning: atlas-cache-5f…: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
```

PSA 는 namespace 라벨이 바뀔 때 **기존 Pod 를 평가해 경고만** 하고 아무것도 지우지 않습니다. `--dry-run=server` 를 주면 라벨은 실제로
붙지 않고 경고만 받을 수 있습니다. 경고는 표준에러로 나오므로 `2>&1` 없이 리다이렉트하면 파일이 `namespace/atlas labeled` 한 줄뿐입니다.

**2) atlas-agent 를 baseline 에 맞추기**

```bash
kubectl -n atlas edit deploy atlas-agent
```

```yaml
    spec:
      containers:
      - name: agent
        image: busybox:1.36
        command: ["sh", "-c", "while true; do ls /host/log > /dev/null; sleep 30; done"]
        securityContext:
          privileged: false            # true → false (또는 줄 삭제)
        volumeMounts:
        - name: host-log
          mountPath: /host/log
          readOnly: true
      volumes:
      - name: host-log
        emptyDir: {}                   # hostPath: {path: /var/log} → emptyDir
```

```bash
kubectl -n atlas rollout status deploy atlas-agent
```

baseline 은 **알려진 권한 상승**(privileged, hostPath, hostNetwork/PID/IPC, hostPort, 위험한 capabilities 추가, `Unconfined` seccomp·AppArmor,
`/proc` 마운트 변경, 위험 sysctl)을 막습니다. hostPath 는 `readOnly: true` 여도 baseline 위반입니다. restricted 는 거기에 더해 비 root,
`allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, seccomp `RuntimeDefault`/`Localhost`, 허용된 볼륨 종류만 요구합니다.

**3) 라벨 — 모드 세 개 + 버전 세 개**

```bash
kubectl label --overwrite ns atlas \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=v1.35 \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=v1.35 \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=v1.35
```

| 모드 | 위반 시 | 확인 위치 |
|---|---|---|
| `enforce` | Pod 생성 거부 (Deployment 는 생성되고 ReplicaSet 이 `FailedCreate`) | `kubectl describe rs`, events |
| `warn` | 허용 + kubectl 에 `Warning:` 출력 (워크로드 리소스에도 적용) | 사용자 터미널 |
| `audit` | 허용 + 감사 이벤트에 `pod-security.kubernetes.io/audit-violations` 어노테이션 | apiserver 감사 로그 |

버전을 고정하지 않으면 `latest` 가 되어 클러스터를 올릴 때 기준이 바뀔 수 있습니다. 순서를 바꿔 라벨을 **먼저** 붙이면 이미 떠 있는
`atlas-agent` Pod 는 그대로 돌지만, 그 뒤에 Pod 가 재생성되는 순간(노드 장애, 롤아웃) 거부되어 사라집니다. "지금 Running" 은 준수의 증거가 아닙니다.

**4) · 5) 확인과 기록**

```bash
kubectl -n atlas rollout restart deploy atlas-web atlas-cache atlas-agent     # warn 경고가 출력됨 (거부는 아님)
kubectl -n atlas get pod
kubectl label --dry-run=server --overwrite ns atlas pod-security.kubernetes.io/enforce=restricted 2>&1 | grep -o 'atlas-[a-z]*' | sort -u
printf 'atlas-agent\natlas-cache\n' > /opt/course/a09/restricted-violators.txt
```

## 검증

```bash
kubectl get ns atlas --show-labels | tr ',' '\n' | grep pod-security       # 6개 라벨
kubectl label --dry-run=server --overwrite ns atlas pod-security.kubernetes.io/enforce=baseline 2>&1   # 경고 없음
kubectl -n atlas get deploy                                                  # 셋 다 1/1
kubectl -n atlas run psa-test --image=busybox:1.36 --overrides='{"spec":{"containers":[{"name":"t","image":"busybox:1.36","securityContext":{"privileged":true}}]}}'
# Error from server (Forbidden): ... violates PodSecurity "baseline:v1.35": privileged
cat /opt/course/a09/restricted-violators.txt                                 # atlas-agent / atlas-cache
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `kubectl label --dry-run=server --overwrite ns <ns> pod-security.kubernetes.io/enforce=<level> 2>&1` 로 먼저 영향 범위를 본다. 라벨은 `enforce`/`warn`/`audit` + 각 `-version`.
- **헷갈리는 지점**: enforce 는 기존 Pod 를 쫓아내지 않으므로 고친 뒤 롤아웃으로 새 Pod 를 만들어 확인합니다. Deployment 객체 자체는 enforce 로 거부되지 않고 그 Pod 만 거부됩니다. hostPath 는 읽기 전용이어도 baseline 위반입니다.

## 참고 문서

- 검색어: `pod security admission`, `pod security standards`, `enforce pod security standards with namespace labels`
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q10 →](../q10_etcd_encryption_at_rest_rewrite/question.md)
