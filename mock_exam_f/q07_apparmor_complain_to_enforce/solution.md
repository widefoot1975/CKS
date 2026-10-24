# q07 — Switch an AppArmor profile from complain to enforce · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The AppArmor profile `k8s-f07-readonly` on worker node `cks-c1-w1` is supposed to prevent
> containers from writing to their filesystem, but it does not block anything yet.
>
> 1. On `cks-c1-w1`, find the mode in which profile `k8s-f07-readonly` is loaded and write the mode
>    (one word) to `/opt/course/f07/mode-before.txt` on `cks-c1`.
> 2. Put the profile into enforce mode on `cks-c1-w1`. It must still be in enforce mode when the
>    profile is loaded again from `/etc/apparmor.d/` (for example after a reboot).
> 3. Create a Pod `ro-pod` in namespace `f07` with image `busybox:1.36` and command
>    `sleep 86400` that runs on node `cks-c1-w1` and uses the AppArmor profile `k8s-f07-readonly`
>    for its container. Use the `securityContext` field, not an annotation.
> 4. In Pod `ro-pod`, run `touch /tmp/test` and write the error message to
>    `/opt/course/f07/touch.txt`.

**해석**

워커 노드 `cks-c1-w1` 의 AppArmor 프로필 `k8s-f07-readonly` 는 컨테이너가 파일시스템에 쓰지 못하게 하려는 것인데, 아직 아무것도 막지 않는다.

1. `cks-c1-w1` 에서 프로필 `k8s-f07-readonly` 가 어떤 모드로 로드되어 있는지 찾아, 모드(한 단어)를 `cks-c1` 의 `/opt/course/f07/mode-before.txt` 에 쓴다.
2. `cks-c1-w1` 에서 프로필을 enforce 모드로 바꾼다. `/etc/apparmor.d/` 에서 프로필을 다시 로드해도(예: 재부팅 후) enforce 모드여야 한다.
3. namespace `f07` 에 이미지 `busybox:1.36`, 명령 `sleep 86400` 인 Pod `ro-pod` 를 노드 `cks-c1-w1` 에서 돌리고, 컨테이너에 AppArmor 프로필
   `k8s-f07-readonly` 를 적용한다. 어노테이션이 아니라 `securityContext` 필드를 쓴다.
4. Pod `ro-pod` 에서 `touch /tmp/test` 를 실행하고 오류 메시지를 `/opt/course/f07/touch.txt` 에 쓴다.

## 모범 풀이

**1) 현재 모드 확인**

```bash
ssh cks-c1-w1
sudo -i
aa-status | grep -A20 'complain mode' | grep k8s-f07
#    k8s-f07-readonly
grep k8s-f07 /sys/kernel/security/apparmor/profiles
# k8s-f07-readonly (complain)
cat /etc/apparmor.d/k8s-f07-readonly        # 쓰기(w) 권한이 없는 허용 목록형 프로필, flags 에 complain 없음
```

`cks-c1` 로 돌아와 기록합니다.

```bash
echo complain > /opt/course/f07/mode-before.txt
```

complain 모드는 규칙에 어긋나는 접근을 **막지 않고 로그만** 남깁니다(프로필을 만들 때 학습용). 그래서 프로필이 로드되어 있어도
지금은 쓰기가 됩니다.

**2) enforce 로 바꾸기 (워커에서)**

```bash
# 방법 A: 파일을 다시 로드 — -C(complain) 없이 로드하면 파일에 적힌 모드(enforce)로 들어간다
apparmor_parser -r /etc/apparmor.d/k8s-f07-readonly
# 방법 B: apparmor-utils 가 있으면
aa-enforce /etc/apparmor.d/k8s-f07-readonly

grep k8s-f07 /sys/kernel/security/apparmor/profiles
# k8s-f07-readonly (enforce)
```

setup 은 `apparmor_parser -C -r` 로 **로드할 때만** complain 을 강제했고 파일에는 `flags=(complain)` 이 없습니다. 그래서 재부팅 시
`apparmor.service` 가 `/etc/apparmor.d/` 를 읽으면 enforce 로 들어갑니다. 파일에 `flags=(complain)` 이 적혀 있다면 그것을 지워야
영구적으로 enforce 가 됩니다(`aa-enforce` 는 파일의 flag 를 고치고 다시 로드까지 합니다).

| 확인·변경 | 명령 |
|---|---|
| 로드된 프로필과 모드 | `aa-status`, `cat /sys/kernel/security/apparmor/profiles` |
| enforce 로 로드 | `apparmor_parser -r <파일>` / `aa-enforce <파일>` |
| complain 으로 로드 | `apparmor_parser -C -r <파일>` / `aa-complain <파일>` |
| 언로드 | `apparmor_parser -R <파일>` |

**3) Pod 에 적용**

```yaml
# /opt/course/f07/ro-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ro-pod
  namespace: f07
spec:
  nodeName: cks-c1-w1                    # 프로필이 로드된 노드
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "86400"]
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-f07-readonly   # 파일 이름이 아니라 프로필 이름
```

```bash
kubectl apply -f /opt/course/f07/ro-pod.yaml
kubectl -n f07 get pod ro-pod -o wide        # Running, NODE cks-c1-w1
```

`securityContext.appArmorProfile` 은 v1.30 부터 GA 이고 `container.apparmor.security.beta.kubernetes.io/<컨테이너>` 어노테이션은 deprecated 입니다.
Pod 수준 `spec.securityContext.appArmorProfile` 에 두면 모든 컨테이너의 기본값이 됩니다.

**4) 쓰기 차단 확인**

```bash
kubectl -n f07 exec ro-pod -- touch /tmp/test 2>&1 | tee /opt/course/f07/touch.txt
# touch: /tmp/test: Permission denied
kubectl -n f07 exec ro-pod -- cat /proc/1/attr/current
# k8s-f07-readonly (enforce)
```

## 검증

```bash
ssh cks-c1-w1 sudo grep k8s-f07 /sys/kernel/security/apparmor/profiles    # k8s-f07-readonly (enforce)
kubectl -n f07 get pod ro-pod -o jsonpath='{.spec.containers[0].securityContext.appArmorProfile}{"\n"}'
# {"localhostProfile":"k8s-f07-readonly","type":"Localhost"}
cat /opt/course/f07/mode-before.txt /opt/course/f07/touch.txt               # complain / Permission denied
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: complain = 로그만, enforce = 차단. `apparmor_parser -r` 은 파일의 모드대로, `-C` 를 붙이면 complain 으로 로드한다. Pod 는 `securityContext.appArmorProfile: {type: Localhost, localhostProfile: <프로필 이름>}`.
- **헷갈리는 지점**: 프로필이 Pod 가 뜨는 노드에 로드되어 있지 않으면 컨테이너가 `CreateContainerError` 로 멈춥니다. 그래서 노드를 고정합니다. 명시적 `deny` 규칙은 complain 모드에서도 적용되므로, 이 문제의 프로필은 `deny` 대신 "쓰기 권한을 주지 않는" 허용 목록 방식으로 만들어져 있습니다. 이미 실행 중인 Pod 도 프로필을 다시 로드하면 새 모드를 따르지만, 확실히 하려면 Pod 를 다시 만듭니다.

## 참고 문서

시험 중에는 AppArmor 문서를 열 수 없으므로 `apparmor_parser --help`, `man aa-status` 로 확인합니다.

- 검색어: `apparmor`, `restrict a container's access to resources with apparmor`
- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q08 →](../q08_host_setuid_nologin_shell/question.md)
