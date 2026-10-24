# q07 — Run a Deployment with the RuntimeDefault seccomp profile · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> All containers of Deployment `ledger` in namespace `fin` must run with the container
> runtime's default seccomp profile.
>
> 1. Set the seccomp profile type `RuntimeDefault` once, at Pod level, in the Pod template of
>    Deployment `ledger`. No container may override it with a different profile.
> 2. After the rollout, run `grep Seccomp: /proc/1/status` in container `app` and then in
>    container `helper` of the new Pod, and write both output lines, in this order, to
>    `/opt/course/e07/seccomp.txt`.

**해석**

namespace `fin` 의 Deployment `ledger` 의 모든 컨테이너가 컨테이너 런타임의 기본 seccomp 프로필로 실행되어야 한다.

1. Deployment `ledger` 의 Pod 템플릿에 Pod 수준으로 한 번만 seccomp 프로필 타입 `RuntimeDefault` 를 설정한다. 어떤 컨테이너도
   다른 프로필로 덮어쓰면 안 된다.
2. 롤아웃 후 새 Pod 의 컨테이너 `app`, 이어서 `helper` 에서 `grep Seccomp: /proc/1/status` 를 실행하고 두 줄을 이 순서로
   `/opt/course/e07/seccomp.txt` 에 쓴다.

## 모범 풀이

**0) 현재 상태**

```bash
kubectl -n fin get deploy ledger -o jsonpath='{.spec.template.spec.securityContext}{"\n"}{range .spec.template.spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'
# {}
# app:
# helper: {"seccompProfile":{"type":"Unconfined"}}
POD=$(kubectl -n fin get pod -l app=ledger -o jsonpath='{.items[0].metadata.name}')
kubectl -n fin exec $POD -c app -- grep Seccomp: /proc/1/status      # Seccomp: 0  (필터 없음)
```

kubelet 의 `seccompDefault` 가 꺼져 있으면(기본값 false) 프로필을 지정하지 않은 컨테이너는 **Unconfined** 로 돕니다.

**1) Pod 수준 RuntimeDefault + 컨테이너 덮어쓰기 제거**

```bash
kubectl -n fin edit deploy ledger
```

```yaml
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault        # 모든 컨테이너(init 포함)에 적용
      containers:
      - name: app
        image: nginx:1.27-alpine
      - name: helper
        image: busybox:1.36
        command: ["sleep", "1d"]
        # securityContext.seccompProfile.type: Unconfined  ← 삭제 (컨테이너 값이 Pod 값보다 우선)
```

같은 작업을 patch 로 하면 다음과 같습니다(JSON patch 의 `remove` 는 경로가 없으면 실패하니 현재 구조를 확인한 뒤 실행).

```bash
kubectl -n fin patch deploy ledger --type=json -p='[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"}}},
  {"op":"remove","path":"/spec/template/spec/containers/1/securityContext"}]'
kubectl -n fin rollout status deploy ledger
```

**2) 확인 및 기록**

```bash
POD=$(kubectl -n fin get pod -l app=ledger --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')   # 가장 새 Pod
{
  kubectl -n fin exec $POD -c app    -- grep Seccomp: /proc/1/status
  kubectl -n fin exec $POD -c helper -- grep Seccomp: /proc/1/status
} > /opt/course/e07/seccomp.txt
cat /opt/course/e07/seccomp.txt
# Seccomp:	2
# Seccomp:	2
```

| `/proc/<pid>/status` 의 `Seccomp:` | 의미 |
|---|---|
| `0` | seccomp 없음 (Unconfined) |
| `1` | strict 모드 (read/write/exit 만) |
| `2` | filter 모드 — `RuntimeDefault`·`Localhost` 프로필이 적용됨 |

## 검증

```bash
kubectl -n fin get deploy ledger -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}{"\n"}'   # RuntimeDefault
kubectl -n fin get deploy ledger -o jsonpath='{.spec.template.spec.containers[*].securityContext}{"\n"}'          # 비어 있음
kubectl -n fin get pod -l app=ledger                                                                              # 2/2 Running (종료 중인 옛 Pod 가 잠시 보일 수 있음)
cat /opt/course/e07/seccomp.txt                                                                                   # 2, 2
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `spec.securityContext.seccompProfile.type: RuntimeDefault` (Pod 수준) — 컨테이너 수준 `seccompProfile` 이 있으면 **그 컨테이너는 컨테이너 값이 우선**한다. 확인은 `grep Seccomp /proc/1/status` → `2`.
- **헷갈리는 지점**: 예전 어노테이션 `seccomp.security.alpha.kubernetes.io/pod` 는 v1.19 부터 deprecated 이고 지금은 효과가 없으니 필드만 씁니다. `Localhost` 는 `localhostProfile` 에 `/var/lib/kubelet/seccomp/` 기준 **상대 경로**를 줍니다. kubelet 설정 `seccompDefault: true` 를 켜면 지정이 없는 컨테이너도 RuntimeDefault 가 됩니다(노드별 설정).

## 참고 문서

- 검색어: `seccomp`, `seccompProfile RuntimeDefault`
- https://kubernetes.io/docs/tutorials/security/seccomp/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q08 →](../q08_remove_package_and_user_host/question.md)
