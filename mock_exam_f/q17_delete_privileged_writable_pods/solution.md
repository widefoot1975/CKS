# q17 — Delete privileged and writable Pods · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Only immutable containers may run in namespace `f17`: a container must not be privileged and its
> root filesystem must be read-only.
>
> 1. Find every Pod in namespace `f17` that has at least one container that is privileged or does
>    not have `readOnlyRootFilesystem: true`. Write their names, one per line and sorted
>    alphabetically, to `/opt/course/f17/pods.txt`.
> 2. Delete exactly these Pods.
> 3. Write the output of `kubectl -n f17 get pods` to `/opt/course/f17/remaining.txt`. The remaining
>    Pods must still be `Running`.

**해석**

namespace `f17` 에서는 불변(immutable) 컨테이너만 돌 수 있다. 컨테이너는 privileged 가 아니어야 하고 루트 파일시스템이 읽기 전용이어야 한다.

1. namespace `f17` 에서 privileged 이거나 `readOnlyRootFilesystem: true` 가 없는 컨테이너를 하나라도 가진 Pod 를 모두 찾는다. 이름을 한 줄에 하나씩
   알파벳 순으로 `/opt/course/f17/pods.txt` 에 쓴다.
2. 정확히 그 Pod 들만 지운다.
3. `kubectl -n f17 get pods` 의 출력을 `/opt/course/f17/remaining.txt` 에 쓴다. 남은 Pod 는 계속 `Running` 이어야 한다.

## 모범 풀이

**1) 컨테이너별 설정을 한눈에 보기**

```bash
alias k=kubectl
k -n f17 get pod -o custom-columns='NAME:.metadata.name,CONTAINERS:.spec.containers[*].name,PRIV:.spec.containers[*].securityContext.privileged,RO:.spec.containers[*].securityContext.readOnlyRootFilesystem'
# NAME      CONTAINERS     PRIV     RO
# alpha     app            <none>   true
# beta      app            true     true
# delta     app,sidecar    <none>   true,true
# epsilon   app,helper     <none>   true        ← 컨테이너 2개인데 값은 1개 → helper 에는 없음
# gamma     app            <none>   <none>
```

`custom-columns` 는 없는 값을 건너뛰므로 컨테이너 수와 값 수가 다르면 어느 컨테이너에 빠졌는지 따로 봐야 합니다. 컨테이너별로 정확히 보려면
jsonpath 의 `range` 를 씁니다.

```bash
k -n f17 get pod -o jsonpath='{range .items[*]}{range .spec.containers[*]}{"\t"}{.name}{" priv="}{.securityContext.privileged}{" ro="}{.securityContext.readOnlyRootFilesystem}{"\n"}{end}{end}'
```

jq 가 있으면 조건을 그대로 식으로 쓸 수 있습니다.

```bash
k -n f17 get pod -o json | jq -r '.items[]
  | select(any(.spec.containers[]; .securityContext.privileged == true or .securityContext.readOnlyRootFilesystem != true))
  | .metadata.name' | sort | tee /opt/course/f17/pods.txt
# beta
# epsilon
# gamma
```

| Pod | privileged | 루트 FS | 판정 |
|---|---|---|---|
| `alpha` | 아님 | 읽기 전용 | 유지 |
| `beta` | **예** | 읽기 전용 | 삭제 (읽기 전용이어도 privileged 는 노드 장치·커널에 접근 가능) |
| `delta` | 아님 | 두 컨테이너 모두 읽기 전용 | 유지 |
| `epsilon` | 아님 | **`helper` 가 쓰기 가능** | 삭제 |
| `gamma` | 아님 | **쓰기 가능** (설정 없음 = 기본값 false) | 삭제 |

`readOnlyRootFilesystem` 은 **컨테이너 수준에만 있는 필드**라 Pod 수준 `securityContext` 를 볼 필요는 없지만, 컨테이너마다 따로 확인해야 합니다.

**2) 삭제**

```bash
k -n f17 delete pod $(cat /opt/course/f17/pods.txt)
```

단독 Pod 라서 다시 생기지 않습니다. 컨트롤러가 있는 Pod 라면 Deployment 등을 고치거나 줄여야 합니다.

**3) 남은 Pod 기록**

```bash
k -n f17 get pods | tee /opt/course/f17/remaining.txt
# NAME    READY   STATUS    RESTARTS   AGE
# alpha   1/1     Running   0          5m
# delta   2/2     Running   0          5m
```

## 검증

```bash
cat /opt/course/f17/pods.txt                                     # beta epsilon gamma
k -n f17 get pod --no-headers | awk '{print $1, $3}'             # alpha Running / delta Running
k -n f17 exec alpha -- touch /x 2>&1 | tail -1                   # Read-only file system
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 불변 컨테이너 = `privileged` 아님 + `readOnlyRootFilesystem: true` (+ 쓰기가 필요한 경로는 `emptyDir`). 모든 컨테이너(init 포함)를 하나씩 확인한다.
- **헷갈리는 지점**: 필드가 없으면 기본값은 "쓰기 가능" 입니다. `custom-columns` 의 `<none>`/값 개수만 보고 판단하면 다중 컨테이너 Pod 를 놓치기 쉽습니다. 실제 운영에서는 이런 Pod 를 사후에 지우기보다 Pod Security(restricted 는 privileged 금지)나 ValidatingAdmissionPolicy 로 생성 단계에서 막습니다.

## 참고 문서

- 검색어: `configure a security context`, `readOnlyRootFilesystem`, `jsonpath`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/reference/kubectl/jsonpath/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md)
