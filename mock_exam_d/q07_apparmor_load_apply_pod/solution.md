# q07 — Load an AppArmor profile and apply it to a Pod · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> An AppArmor profile file was placed on worker node `cks-c1-w1` at
> `/etc/apparmor.d/d07-deny-write`. It is not loaded yet.
>
> 1. On worker node `cks-c1-w1`, load the profile into the kernel in enforce mode and confirm
>    with `aa-status` that it is loaded.
> 2. Create a Pod `writer` in namespace `amber` with image `busybox:1.36` and command
>    `sleep 3600` that runs on node `cks-c1-w1`. Its container must use that AppArmor profile
>    through the `securityContext` field (not the deprecated annotation).
> 3. Run `kubectl -n amber exec writer -- touch /tmp/test` and write its complete output
>    (stdout and stderr) to `/opt/course/d07/touch.txt` on `cks-c1`.

**해석**

워커 노드 `cks-c1-w1` 의 `/etc/apparmor.d/d07-deny-write` 에 AppArmor 프로필 파일이 있다. 아직 로드되지 않았다.

1. 워커 노드 `cks-c1-w1` 에서 프로필을 enforce 모드로 커널에 로드하고, `aa-status` 로 로드됐는지 확인한다.
2. 이미지 `busybox:1.36`, 명령 `sleep 3600` 인 Pod `writer` 를 namespace `amber` 에 만들고 `cks-c1-w1` 에서 돌게 한다.
   컨테이너는 이 AppArmor 프로필을 (폐기 예정인 어노테이션이 아니라) `securityContext` 필드로 써야 한다.
3. `kubectl -n amber exec writer -- touch /tmp/test` 를 실행해 출력 전체(stdout, stderr)를 `cks-c1` 의 `/opt/course/d07/touch.txt` 에 쓴다.

## 모범 풀이

**1) 워커에서 프로필 로드**

```bash
ssh cks-c1-w1
sudo -i
cat /etc/apparmor.d/d07-deny-write
# profile d07-deny-write flags=(attach_disconnected) {
#   ...
#   deny /** w,
# }
apparmor_parser -q /etc/apparmor.d/d07-deny-write      # 로드 (이미 있으면 -r 로 교체)
aa-status | grep d07                                    # d07-deny-write  (enforce 목록 안에)
exit; exit                                              # cks-c1 으로 돌아온다
```

Pod 에 적는 이름은 **파일 이름이 아니라 파일 안의 `profile <이름>`** 입니다. 이 문제는 둘이 같지만 다르면 `profile` 뒤의
이름을 씁니다. 프로필은 Pod 가 **실제로 뜨는 노드**에 로드되어 있어야 하고, 컨트롤 플레인에 로드해도 소용없습니다.
`apparmor_parser` 는 기본이 enforce 모드이고, complain 모드는 `-C` 를 줄 때만 됩니다.

**2) Pod**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: writer
  namespace: amber
spec:
  nodeSelector:
    kubernetes.io/hostname: cks-c1-w1
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: d07-deny-write
```

```bash
alias k=kubectl
k apply -f writer.yaml
k -n amber get pod writer -o wide          # Running, NODE cks-c1-w1
```

`appArmorProfile` 은 v1.30 에 GA 된 필드로 Pod `securityContext`(모든 컨테이너 기본값)와 컨테이너 `securityContext` 양쪽에
둘 수 있습니다. 예전 어노테이션 `container.apparmor.security.beta.kubernetes.io/<컨테이너>` 는 폐기 예정입니다.
`type` 은 `RuntimeDefault`, `Localhost`, `Unconfined` 중 하나이고 `Localhost` 일 때만 `localhostProfile` 을 씁니다.
프로필이 그 노드에 없으면 Pod 는 `CreateContainerError`(apparmor profile not found)로 멈춥니다.

**3) 쓰기 차단 확인**

```bash
k -n amber exec writer -- touch /tmp/test > /opt/course/d07/touch.txt 2>&1
cat /opt/course/d07/touch.txt
# touch: /tmp/test: Permission denied
# command terminated with exit code 1
```

## 검증

```bash
k -n amber exec writer -- cat /proc/1/attr/current      # d07-deny-write (enforce)
k -n amber get pod writer -o jsonpath='{.spec.containers[0].securityContext.appArmorProfile}{"\n"}'
ssh cks-c1-w1 sudo aa-status | grep d07
cat /opt/course/d07/touch.txt                           # Permission denied
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 노드에서 `apparmor_parser -q <파일>` → `aa-status` 확인 → Pod 에 `securityContext.appArmorProfile: {type: Localhost, localhostProfile: <프로필 이름>}`.
- **헷갈리는 지점**: `apparmor_parser` 로 로드한 프로필은 재부팅하면 `/etc/apparmor.d/` 에 있는 것만 다시 로드됩니다. `localhostProfile` 에 경로(`/etc/apparmor.d/...`)를 쓰면 안 됩니다 — seccomp 의 `localhostProfile`(경로)와 헷갈리기 쉽습니다. 컨테이너가 이미 떠 있으면 프로필을 바꿔도 반영되지 않아 Pod 를 다시 만들어야 합니다.

## 참고 문서

- 검색어: `apparmor`, `appArmorProfile`
- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q08 →](../q08_disable_listening_service_worker/question.md)
