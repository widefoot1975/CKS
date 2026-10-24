# q09 — Enforce Pod Security restricted and fix a Pod · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `coral` must enforce the Pod Security Standard `restricted`. Pod `api` in this
> namespace was created from `/opt/course/d09/api.yaml`.
>
> 1. Label namespace `coral` so that Pod Security Admission enforces level `restricted`, pinned
>    to version `v1.35`. Write the complete output of your `kubectl label` command (stdout and
>    stderr) to `/opt/course/d09/label.txt`.
> 2. Edit `/opt/course/d09/api.yaml` so that Pod `api` complies with `restricted`: run as
>    non-root with UID `101`, use the seccomp profile `RuntimeDefault` (set both in the Pod's
>    `securityContext`), disallow privilege escalation and drop all capabilities.
> 3. Recreate Pod `api` from the edited file. It must be `Running` and Ready in namespace `coral`.

**해석**

namespace `coral` 은 Pod Security Standard `restricted` 를 강제해야 한다. 이 namespace 의 Pod `api` 는 `/opt/course/d09/api.yaml` 로 만들었다.

1. Pod Security Admission 이 `restricted` 를 강제하도록, 버전은 `v1.35` 로 고정해 namespace `coral` 에 라벨을 붙인다.
   `kubectl label` 명령의 출력 전체(stdout, stderr)를 `/opt/course/d09/label.txt` 에 쓴다.
2. Pod `api` 가 `restricted` 를 만족하도록 `/opt/course/d09/api.yaml` 을 고친다. UID `101` 의 non-root 로 실행하고,
   seccomp 프로필 `RuntimeDefault` 를 쓰며(둘 다 Pod 의 `securityContext` 에), 권한 상승을 막고, 모든 capability 를 버린다.
3. 고친 파일로 Pod `api` 를 다시 만든다. namespace `coral` 에서 `Running` · Ready 여야 한다.

## 모범 풀이

**1) namespace 라벨**

```bash
alias k=kubectl
k label ns coral \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.35 > /opt/course/d09/label.txt 2>&1
cat /opt/course/d09/label.txt
# Warning: existing pods in namespace "coral" violate the new PodSecurity enforce level "restricted:v1.35"
# Warning: api: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
# namespace/coral labeled
k -n coral get pod api                     # 여전히 Running
```

PSA 는 **Pod 를 만들거나 바꿀 때만** 검사합니다. 라벨을 붙여도 이미 떠 있는 Pod 는 쫓겨나지 않고, 대신 kubectl 이 경고로
위반 Pod 를 알려 줍니다. 그래서 라벨만 붙이고 끝내면 위반 Pod 가 계속 돕니다. 라벨을 붙이기 전에 영향을 미리 보려면
`k label --dry-run=server --overwrite ns coral pod-security.kubernetes.io/enforce=restricted` 를 씁니다.

| 라벨 | 위반 시 |
|---|---|
| `pod-security.kubernetes.io/enforce` | Pod 생성 거부 |
| `pod-security.kubernetes.io/audit` | 감사 로그에 annotation 으로 기록 |
| `pod-security.kubernetes.io/warn` | 사용자에게 경고만 |
| `...-version` | 정책 버전 고정 (`latest` 또는 `v1.35` 같은 마이너 버전) |

**2) 매니페스트 수정**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api
  namespace: coral
  labels:
    app: api
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: api
    image: nginxinc/nginx-unprivileged:1.27-alpine
    ports:
    - containerPort: 8080
    securityContext:
      allowPrivilegeEscalation: false   # 컨테이너 수준에만 있는 필드
      capabilities:
        drop: ["ALL"]                   # 컨테이너 수준에만 있는 필드
```

**3) 다시 만들기**

```bash
k replace --force -f /opt/course/d09/api.yaml      # delete + create
k -n coral wait --for=condition=Ready pod/api --timeout=60s
```

Pod 의 `securityContext` 는 대부분 만든 뒤 바꿀 수 없어 `k apply` 로는 거부됩니다. `replace --force` 또는 `delete` 후 `apply` 합니다.
`nginx-unprivileged` 는 UID 101 로 8080 에서 대기하도록 만든 이미지라 capability 없이도 뜹니다. 일반 `nginx` 이미지는 root 로
80 포트를 열어야 해서 restricted 에서는 쓸 수 없습니다.

## 검증

```bash
k get ns coral --show-labels | tr ',' '\n' | grep pod-security
# pod-security.kubernetes.io/enforce=restricted
# pod-security.kubernetes.io/enforce-version=v1.35
k -n coral get pod api                                                     # 1/1 Running
k label --dry-run=server --overwrite ns coral pod-security.kubernetes.io/enforce=restricted   # 경고 없음
k -n coral run bad --image=nginx:1.27-alpine                               # Error from server (Forbidden): ... violates PodSecurity "restricted:v1.35"
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `k label ns <ns> pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35`. restricted 4종 = runAsNonRoot, seccompProfile, allowPrivilegeEscalation=false, drop ALL.
- **헷갈리는 지점**: 라벨은 기존 Pod 를 지우지 않습니다. 버전 라벨 값은 `v1.35` 처럼 `v` 를 붙입니다. Deployment 는 생성되고 그 ReplicaSet 의 Pod 만 거부되므로 `describe rs` 이벤트에서 메시지를 찾습니다.

## 참고 문서

- 검색어: `pod security admission`, `pod security standards`, `enforce pod security standards with namespace labels`
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q10 →](../q10_secret_volume_readonly/question.md)
