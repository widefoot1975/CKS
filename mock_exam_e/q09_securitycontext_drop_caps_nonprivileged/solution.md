# q09 — Drop capabilities from a privileged container · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Container `netmon` of Deployment `netmon` in namespace `edge` only needs raw sockets.
>
> 1. Change the container so that it is not privileged and cannot gain more privileges than
>    its parent process (`allowPrivilegeEscalation`).
> 2. Drop all Linux capabilities from the container and add back only `NET_RAW`.
> 3. After the rollout, write the output of `grep CapEff /proc/1/status` from the new Pod to
>    `/opt/course/e09/capeff.txt`.

**해석**

namespace `edge` 의 Deployment `netmon` 의 컨테이너 `netmon` 은 raw 소켓만 있으면 된다.

1. 컨테이너가 privileged 가 아니게 하고, 부모 프로세스보다 많은 권한을 얻을 수 없게(`allowPrivilegeEscalation`) 한다.
2. 컨테이너의 모든 Linux capability 를 버리고 `NET_RAW` 하나만 다시 추가한다.
3. 롤아웃 후 새 Pod 에서 `grep CapEff /proc/1/status` 출력을 `/opt/course/e09/capeff.txt` 에 쓴다.

## 모범 풀이

**0) 현재 상태**

```bash
kubectl -n edge get deploy netmon -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}'
# {"capabilities":{"add":["NET_ADMIN","SYS_ADMIN"]},"privileged":true}
kubectl -n edge exec deploy/netmon -- grep CapEff /proc/1/status     # CapEff: 000001ffffffffff (전부)
```

**1) · 2) securityContext 교체**

```bash
kubectl -n edge edit deploy netmon
```

```yaml
      containers:
      - name: netmon
        image: busybox:1.36
        command: ["sleep", "1d"]
        securityContext:
          privileged: false                 # true → false (또는 필드 삭제)
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
            add: ["NET_RAW"]                # NET_ADMIN, SYS_ADMIN 제거
```

```bash
kubectl -n edge rollout status deploy netmon
```

`privileged: true` 는 capability 목록과 상관없이 **모든** capability 와 호스트 디바이스 접근을 주므로 먼저 꺼야 합니다. 그리고
`privileged: true` 와 `allowPrivilegeEscalation: false` 는 함께 쓸 수 없어 API 서버가 거부합니다(`cannot set allowPrivilegeEscalation to false and privileged to true`).
`drop: ["ALL"]` 을 먼저 적용한 뒤 `add` 가 적용되므로 결과는 `NET_RAW` 하나입니다. 이름에는 `CAP_` 접두어를 붙이지 않습니다.

**3) 확인 및 기록**

```bash
POD=$(kubectl -n edge get pod -l app=netmon --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
kubectl -n edge exec $POD -- grep CapEff /proc/1/status > /opt/course/e09/capeff.txt
cat /opt/course/e09/capeff.txt                  # CapEff:	0000000000002000
kubectl -n edge exec $POD -- ip link set lo mtu 65536
# ip: SIOCSIFMTU: Operation not permitted   ← NET_ADMIN 이 없다 (메시지는 버전마다 다를 수 있음)
```

`0x2000` = 비트 13 = `CAP_NET_RAW` 입니다(`capsh --decode=0000000000002000` → `cap_net_raw`). 컨테이너가 root(UID 0)이므로 추가한
capability 가 effective 집합에 그대로 들어갑니다.

| 설정 | CapEff 예 | 의미 |
|---|---|---|
| `privileged: true` | `000001ffffffffff` | 모든 capability |
| 기본값 (containerd) | `00000000a80425fb` | CHOWN, NET_BIND_SERVICE, SETUID, NET_RAW 등 기본 14개 |
| `drop: [ALL]`, `add: [NET_RAW]` | `0000000000002000` | NET_RAW 하나 |

## 검증

```bash
kubectl -n edge get deploy netmon -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}'
# {"allowPrivilegeEscalation":false,"capabilities":{"add":["NET_RAW"],"drop":["ALL"]},"privileged":false}
kubectl -n edge get pod -l app=netmon                  # 1/1 Running
cat /opt/course/e09/capeff.txt                         # CapEff:	0000000000002000
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `capabilities: {drop: [ALL], add: [<필요한 것>]}` + `allowPrivilegeEscalation: false` + `privileged: false`, 모두 **컨테이너** `securityContext`. 확인은 `/proc/1/status` 의 `CapEff`.
- **헷갈리는 지점**: `capabilities`·`privileged`·`allowPrivilegeEscalation` 은 Pod 수준 `securityContext` 에 없습니다. 비 root 사용자로 돌면 `add` 한 capability 가 effective 에 들어가지 않을 수 있어(ambient 미지원) 실제로 필요한 경우엔 root 이거나 파일 capability 가 있어야 합니다. Pod Security `restricted` 는 `add` 로 `NET_BIND_SERVICE` 만 허용하므로 `NET_RAW` 는 `baseline` 까지만 통과합니다.

## 참고 문서

- 검색어: `configure a security context capabilities`, `allowPrivilegeEscalation`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q10 →](../q10_encryption_config_identity_to_aescbc/question.md)
