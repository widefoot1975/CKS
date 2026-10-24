# q09 — Find Pod Security baseline violators with a dry run · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `legacy` will start enforcing the Pod Security Standard `baseline`. Before that,
> existing Pods that would violate it must be found and removed.
>
> 1. Without changing the namespace yet, use a server-side dry run to find out which existing Pods in
>    namespace `legacy` violate the `baseline` level. Write their names, one per line and sorted
>    alphabetically, to `/opt/course/f09/violators.txt`.
> 2. Delete exactly these Pods.
> 3. Label namespace `legacy` so that it enforces `baseline`, pinned to version `v1.35`.
> 4. Try to create a Pod `priv-test` in namespace `legacy` with image `busybox:1.36` and
>    `securityContext.privileged: true`, and write the rejection message to
>    `/opt/course/f09/rejected.txt`.

**해석**

namespace `legacy` 는 곧 Pod Security Standard `baseline` 을 강제한다. 그 전에 위반하는 기존 Pod 를 찾아 없애야 한다.

1. 아직 namespace 는 바꾸지 않은 채, 서버 측 dry run 으로 `legacy` 의 기존 Pod 중 `baseline` 을 위반하는 것을 찾는다. 이름을 한 줄에 하나씩
   알파벳 순으로 `/opt/course/f09/violators.txt` 에 쓴다.
2. 정확히 그 Pod 들만 지운다.
3. namespace `legacy` 에 `baseline` 을 강제하는 라벨을 버전 `v1.35` 로 고정해 붙인다.
4. namespace `legacy` 에 이미지 `busybox:1.36`, `securityContext.privileged: true` 인 Pod `priv-test` 를 만들어 보고, 거부 메시지를
   `/opt/course/f09/rejected.txt` 에 쓴다.

## 모범 풀이

**1) 라벨을 dry run 으로 붙여 본다**

```bash
alias k=kubectl
k label --dry-run=server --overwrite ns legacy \
  pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=v1.35
# Warning: existing pods in namespace "legacy" violate the new PodSecurity enforce level "baseline:v1.35"
# Warning: cap-add: non-default capabilities
# Warning: debug-priv: privileged
# Warning: host-net: host namespaces
# Warning: log-reader: hostPath volumes
# namespace/legacy labeled (server dry run)
```

`--dry-run=server` 는 요청을 API 서버의 admission 까지 보내되 저장하지 않습니다. PodSecurity admission 은 namespace 의 enforce 라벨이
바뀌는 요청을 받으면 **기존 Pod 를 새 기준으로 평가해 경고**로 돌려줍니다(기존 Pod 를 지우지는 않음). `--dry-run=client` 는 서버에
가지 않으므로 경고가 나오지 않습니다.

```bash
k label --dry-run=server --overwrite ns legacy \
  pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=v1.35 2>&1 \
  | grep '^Warning:' | grep -v 'existing pods' | cut -d: -f2 | tr -d ' ' | sort > /opt/course/f09/violators.txt
cat /opt/course/f09/violators.txt
# cap-add
# debug-priv
# host-net
# log-reader
```

| Pod | baseline 위반 항목 |
|---|---|
| `debug-priv` | `privileged: true` |
| `host-net` | `hostNetwork: true` (host namespaces) |
| `log-reader` | `hostPath` 볼륨 |
| `cap-add` | `capabilities.add: [NET_ADMIN]` (기본 목록 밖) |
| `web` | 위반 없음 — root 로 돌아도 baseline 은 허용 (restricted 에서만 위반) |

**2) 위반 Pod 삭제**

```bash
k -n legacy delete pod $(cat /opt/course/f09/violators.txt)
k -n legacy get pod          # web 만 남음
```

단독 Pod 라서 지우면 다시 생기지 않습니다. Deployment 등이 관리하는 Pod 였다면 컨트롤러의 템플릿을 고쳐야 합니다.

**3) enforce 라벨 적용**

```bash
k label --overwrite ns legacy \
  pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=v1.35
k get ns legacy --show-labels
```

버전을 `latest` 가 아니라 `v1.35` 로 고정하면 클러스터를 올려도 검사 기준이 바뀌지 않습니다.

**4) 거부 확인**

```bash
cat <<'EOF' | k apply -f - 2>&1 | tee /opt/course/f09/rejected.txt
apiVersion: v1
kind: Pod
metadata:
  name: priv-test
  namespace: legacy
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
EOF
# Error from server (Forbidden): error when creating "STDIN": pods "priv-test" is forbidden:
#   violates PodSecurity "baseline:v1.35": privileged (container "app" must not set securityContext.privileged=true)
```

## 검증

```bash
k label --dry-run=server --overwrite ns legacy pod-security.kubernetes.io/enforce=baseline   # 경고 없음
k -n legacy get pod                                                                          # web 1개
k get ns legacy -o jsonpath='{.metadata.labels}{"\n"}'
# {"kubernetes.io/metadata.name":"legacy","pod-security.kubernetes.io/enforce":"baseline","pod-security.kubernetes.io/enforce-version":"v1.35"}
cat /opt/course/f09/violators.txt /opt/course/f09/rejected.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 기존 Pod 점검 = `kubectl label --dry-run=server --overwrite ns <ns> pod-security.kubernetes.io/enforce=<level>`. 경고 한 줄 = `Pod이름: 위반 항목`.
- **헷갈리는 지점**: 같은 위반을 가진 Pod 가 여러 개면 `web-1 (and 2 other pods): ...` 처럼 묶여 나오므로 이름을 직접 확인합니다. `enforce` 라벨은 새로 만드는 Pod 만 막고, 기존 Pod 는 그대로 둡니다. Deployment 는 `warn`/`audit` 에서만 경고되고, `enforce` 위반은 Pod 를 만드는 시점(ReplicaSet 이벤트)에서 드러납니다.

## 참고 문서

- 검색어: `pod security admission`, `pod security standards`, `enforce pod security standards with namespace labels`
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q10 →](../q10_etcdctl_read_secret_plaintext/question.md)
