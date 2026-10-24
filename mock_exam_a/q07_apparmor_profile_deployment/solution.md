# q07 — Confine a Deployment with a Localhost AppArmor profile · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Deployment `tide-writer` in namespace `tide` must not be able to write anywhere in its
> filesystem.
>
> 1. On worker node `cks-c1-w1`, load the AppArmor profile defined in
>    `/etc/apparmor.d/cks-a07-deny-write` in enforce mode and confirm it is loaded.
> 2. Change Deployment `tide-writer` so that its Pods always run on node `cks-c1-w1`, and its
>    container `writer` runs with that profile. Use the `securityContext` field, not the
>    deprecated annotation, and remove the deprecated AppArmor annotation from the Pod template.
> 3. Write the output of `cat /proc/1/attr/current` executed in the container to
>    `/opt/course/a07/attr.txt`.
> 4. Write the output (stdout and stderr) of `touch /tmp/a07` executed in the container to
>    `/opt/course/a07/write-test.txt`. It must fail.

**해석**

namespace `tide` 의 Deployment `tide-writer` 는 파일시스템 어디에도 쓰지 못해야 한다.

1. 워커 `cks-c1-w1` 에서 `/etc/apparmor.d/cks-a07-deny-write` 에 정의된 AppArmor 프로필을 enforce 모드로 로드하고 로드됐는지 확인한다.
2. Deployment `tide-writer` 의 Pod 가 항상 `cks-c1-w1` 에서 돌게 하고, 컨테이너 `writer` 가 그 프로필로 돌게 한다. 옛 어노테이션이 아니라
   `securityContext` 필드를 쓰고, Pod 템플릿에서 옛 AppArmor 어노테이션을 지운다.
3. 컨테이너에서 실행한 `cat /proc/1/attr/current` 출력을 `/opt/course/a07/attr.txt` 에 쓴다.
4. 컨테이너에서 실행한 `touch /tmp/a07` 의 출력(표준출력·표준에러)을 `/opt/course/a07/write-test.txt` 에 쓴다. 실패해야 한다.

## 모범 풀이

**1) 워커에서 프로필 로드**

```bash
ssh cks-c1-w1
sudo -i
cat /etc/apparmor.d/cks-a07-deny-write
#   profile cks-a07-deny-write flags=(attach_disconnected) { ... deny /** w, }
aa-status | grep cks-a07 || echo "not loaded"
apparmor_parser -q /etc/apparmor.d/cks-a07-deny-write       # 이미 있으면 -r 로 교체
aa-status | grep -A20 'in enforce mode' | grep cks-a07       # cks-a07-deny-write
exit; exit
```

Pod 에서 쓰는 이름은 **파일 이름이 아니라 파일 안의 `profile <이름>`** 입니다(여기서는 같게 만들었습니다). `/etc/apparmor.d/` 에 둔 파일은
재부팅 때 `apparmor.service` 가 다시 로드합니다. 프로필은 Pod 가 **실제로 뜨는 노드**에 로드되어 있어야 하므로 nodeSelector 로 고정합니다.
`apparmor_parser -C`(complain 모드)로 로드하면 위반을 기록만 하고 막지 않습니다.

**2) Deployment 수정 — 어노테이션 제거 + 필드**

```bash
kubectl -n tide get deploy tide-writer -o jsonpath='{.spec.template.metadata.annotations}{"\n"}'
# {"container.apparmor.security.beta.kubernetes.io/writer":"unconfined"}
kubectl -n tide edit deploy tide-writer
```

```yaml
  template:
    metadata:
      labels:
        app: tide-writer
      # annotations: container.apparmor.security.beta.kubernetes.io/writer: unconfined  ← 삭제
    spec:
      nodeSelector:
        kubernetes.io/hostname: cks-c1-w1
      containers:
      - name: writer
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date >> /tmp/heartbeat; sleep 5; done"]
        securityContext:
          appArmorProfile:
            type: Localhost
            localhostProfile: cks-a07-deny-write
```

```bash
kubectl -n tide rollout status deploy tide-writer
kubectl -n tide get pod -o wide                    # NODE cks-c1-w1
```

어노테이션(`unconfined`)을 남긴 채 필드(`Localhost`)를 넣으면 둘이 서로 달라 API 서버가 Pod(또는 템플릿) 검증에서 거부합니다.
v1.30 에서 GA 된 `appArmorProfile` 필드가 정식 방법이고 어노테이션은 deprecated 입니다.

| 방법 | 위치 | 값 |
|---|---|---|
| 필드 (v1.30+) | `securityContext.appArmorProfile` (Pod 또는 컨테이너) | `type: RuntimeDefault` / `Unconfined` / `Localhost` + `localhostProfile` |
| 옛 어노테이션 | `container.apparmor.security.beta.kubernetes.io/<컨테이너>` | `runtime/default` / `unconfined` / `localhost/<프로필>` |

Pod 수준 `spec.securityContext.appArmorProfile` 은 모든 컨테이너의 기본값이 되고, 컨테이너 수준 값이 있으면 그것이 우선합니다.

**3) · 4) 결과 기록**

```bash
kubectl -n tide exec deploy/tide-writer -- cat /proc/1/attr/current > /opt/course/a07/attr.txt
cat /opt/course/a07/attr.txt              # cks-a07-deny-write (enforce)
kubectl -n tide exec deploy/tide-writer -- touch /tmp/a07 > /opt/course/a07/write-test.txt 2>&1 || true
cat /opt/course/a07/write-test.txt        # touch: /tmp/a07: Permission denied ... command terminated with exit code 1
```

커널에 따라 `/proc/1/attr/current` 가 비어 있으면 `/proc/1/attr/apparmor/current` 를 봅니다. 워커에서
`journalctl -k | grep apparmor="DENIED"` 로 거부 기록도 확인할 수 있습니다.

## 검증

```bash
cat /opt/course/a07/attr.txt /opt/course/a07/write-test.txt
kubectl -n tide get deploy tide-writer -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}{.spec.template.metadata.annotations}{"\n"}'
# {"appArmorProfile":{"localhostProfile":"cks-a07-deny-write","type":"Localhost"}}
# (빈 줄 — 어노테이션 없음)
kubectl -n tide logs deploy/tide-writer --tail=2      # can't create /tmp/heartbeat: Permission denied
ssh cks-c1-w1 sudo aa-status | grep cks-a07
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 노드에서 `apparmor_parser -q <파일>` → `aa-status` 확인 → Pod 는 그 노드에 고정 → `securityContext.appArmorProfile: {type: Localhost, localhostProfile: <profile 이름>}`.
- **헷갈리는 지점**: `localhostProfile` 은 파일 경로가 아니라 프로필 이름입니다(seccomp 의 `localhostProfile` 은 반대로 상대 **경로**). 어노테이션과 필드가 다르면 거부되므로 옛 어노테이션은 지웁니다. 프로필이 로드되지 않은 노드에 뜬 Pod 는 컨테이너를 만들지 못합니다.

## 참고 문서

`apparmor_parser --help`, `aa-status --help` 로 옵션을 확인합니다.

- 검색어: `apparmor`, `restrict a container's access to resources with apparmor`
- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q08 →](../q08_host_listening_service_disable/question.md)
