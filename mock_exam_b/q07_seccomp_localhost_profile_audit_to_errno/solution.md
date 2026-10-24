# q07 — Turn a logging seccomp profile into a blocking one · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The security team drafted the seccomp profile `/opt/course/b07/no-chmod.json` on `cks-c1`. It
> currently only logs the syscalls it lists.
>
> 1. Change the profile so that the syscalls `chmod`, `fchmod`, `fchmodat` and `fchmodat2` fail
>    with an error, while every other syscall stays allowed. Install the profile on worker node
>    `cks-c1-w1` as `/var/lib/kubelet/seccomp/profiles/no-chmod.json`.
> 2. Edit `/opt/course/b07/pod.yaml`: the Pod must use the seccomp profile `RuntimeDefault` for all
>    containers by default, and container `app` must use the profile from step 1 instead. Create the
>    Pod in namespace `forge`.
> 3. In both containers run `touch /tmp/f && chmod 600 /tmp/f`. Write the complete output
>    (stdout and stderr) of the command in container `app` to `/opt/course/b07/app-chmod.txt`. The
>    command must fail in `app` and succeed in `helper`.

**해석**

보안팀이 `cks-c1` 에 seccomp 프로필 `/opt/course/b07/no-chmod.json` 초안을 만들었는데, 지금은 나열한 syscall 을 기록만 한다.

1. `chmod`, `fchmod`, `fchmodat`, `fchmodat2` 는 오류로 실패하고 나머지 syscall 은 모두 허용되도록 고친다. 워커 `cks-c1-w1` 의
   `/var/lib/kubelet/seccomp/profiles/no-chmod.json` 에 설치한다.
2. `/opt/course/b07/pod.yaml` 을 고쳐, Pod 의 모든 컨테이너 기본 seccomp 은 `RuntimeDefault`, 컨테이너 `app` 만 1번 프로필을 쓰게 한다.
   namespace `forge` 에 Pod 를 만든다.
3. 두 컨테이너에서 `touch /tmp/f && chmod 600 /tmp/f` 를 실행한다. `app` 에서의 전체 출력(stdout+stderr)을 `/opt/course/b07/app-chmod.txt` 에 쓴다.
   `app` 에서는 실패, `helper` 에서는 성공해야 한다.

## 모범 풀이

**1) 프로필 고치기**

```bash
cat /opt/course/b07/no-chmod.json
```

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": ["chmod", "fchmod", "fchmodat", "fchmodat2"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

`"action": "SCMP_ACT_LOG"` 를 `"SCMP_ACT_ERRNO"` 로 바꾸기만 하면 됩니다(`sed -i 's/SCMP_ACT_LOG/SCMP_ACT_ERRNO/'`). `errnoRet` 를
생략하면 `EPERM`(Operation not permitted) 이 반환됩니다.

| action | 효과 |
|---|---|
| `SCMP_ACT_ALLOW` | 허용 |
| `SCMP_ACT_LOG` | 허용 + 커널 감사 로그(`journalctl -k`, `type=SECCOMP`)에 기록 — 프로필 만들 때 "감사 모드" |
| `SCMP_ACT_ERRNO` | syscall 을 실행하지 않고 오류 반환 |
| `SCMP_ACT_KILL_PROCESS` | 프로세스 종료 |

> 함정 1: `defaultAction` 은 반드시 `SCMP_ACT_ALLOW` 로 둡니다. 기본값을 `SCMP_ACT_ERRNO` 로 하면 런타임이 컨테이너를 시작하는 데 필요한
> syscall 까지 막혀 Pod 가 `CreateContainerError`/`RunContainerError` 에 빠집니다.

```bash
scp /opt/course/b07/no-chmod.json cks-c1-w1:/tmp/
ssh cks-c1-w1
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
cp /tmp/no-chmod.json /var/lib/kubelet/seccomp/profiles/no-chmod.json
python3 -m json.tool /var/lib/kubelet/seccomp/profiles/no-chmod.json >/dev/null && echo valid-json
exit; exit
```

**2) Pod 매니페스트**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: chmod-test
  namespace: forge
spec:
  nodeSelector:
    kubernetes.io/hostname: cks-c1-w1
  securityContext:
    seccompProfile:
      type: RuntimeDefault                       # Pod 기본값: 모든 컨테이너
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "1d"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/no-chmod.json  # /var/lib/kubelet/seccomp/ 기준 상대 경로
  - name: helper
    image: busybox:1.36
    command: ["sleep", "1d"]
```

```bash
kubectl apply -f /opt/course/b07/pod.yaml
kubectl -n forge get pod chmod-test -w          # 2/2 Running
```

> 함정 2: `localhostProfile` 은 kubelet 의 seccomp 루트(`/var/lib/kubelet/seccomp`) 기준 **상대 경로**입니다.
> `/var/lib/kubelet/seccomp/profiles/no-chmod.json` 처럼 절대 경로를 쓰면 경로가 이중으로 붙어 프로필을 찾지 못합니다.
>
> 함정 3: 프로필 파일은 **Pod 가 스케줄되는 노드**에 있어야 합니다. 컨트롤 플레인에만 두면 `CreateContainerError: ... cannot load seccomp profile`.
> 이미 떠 있는 컨테이너에는 프로필 변경이 반영되지 않으므로, 프로필을 고쳤다면 Pod 를 지우고 다시 만듭니다.

컨테이너 수준 `seccompProfile` 이 Pod 수준 값을 덮어쓰므로 `app` 은 Localhost, `helper` 는 Pod 기본값 RuntimeDefault 를 씁니다.

**3) 동작 확인과 기록**

```bash
kubectl -n forge exec chmod-test -c app -- sh -c 'touch /tmp/f && chmod 600 /tmp/f' > /opt/course/b07/app-chmod.txt 2>&1
cat /opt/course/b07/app-chmod.txt
# chmod: /tmp/f: Operation not permitted
# command terminated with exit code 1
kubectl -n forge exec chmod-test -c helper -- sh -c 'touch /tmp/f && chmod 600 /tmp/f && ls -l /tmp/f'
# -rw-------    1 root     root    0 ... /tmp/f
```

## 검증

```bash
kubectl -n forge get pod chmod-test -o jsonpath='{.spec.securityContext}{"\n"}{.spec.containers[0].securityContext}{"\n"}'
kubectl -n forge exec chmod-test -c app -- grep Seccomp /proc/1/status       # Seccomp: 2 (filter 모드)
kubectl -n forge exec chmod-test -c helper -- grep Seccomp /proc/1/status    # Seccomp: 2
ssh cks-c1-w1 sudo grep -c ERRNO /var/lib/kubelet/seccomp/profiles/no-chmod.json
cat /opt/course/b07/app-chmod.txt
```

`Seccomp: 0` 이면 seccomp 이 꺼진 상태(Unconfined)입니다. `SCMP_ACT_LOG` 상태로 시험해 보면 chmod 는 성공하고 워커의 `journalctl -k | grep -i seccomp`
에 `syscall=90`(chmod) 같은 기록이 남습니다.

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `seccompProfile: {type: Localhost, localhostProfile: profiles/<file>.json}` — 파일은 Pod 가 뜨는 노드의 `/var/lib/kubelet/seccomp/profiles/`. 기본 허용 + 특정 syscall `SCMP_ACT_ERRNO`.
- **헷갈리는 지점**: Pod 수준과 컨테이너 수준 모두 `seccompProfile` 을 가질 수 있고 컨테이너 쪽이 우선합니다. 옛 어노테이션 `seccomp.security.alpha.kubernetes.io/pod` 는 v1.19 부터 deprecated 이고 지금은 `securityContext.seccompProfile` 필드를 씁니다. busybox `chmod` 가 실제로 어떤 syscall(`chmod` 또는 `fchmodat`)을 쓰는지는 libc 에 따라 달라서 계열 전체를 막습니다.

## 참고 문서

- 검색어: `seccomp`, `restrict a container's syscalls with seccomp`, `security context seccompProfile`
- https://kubernetes.io/docs/tutorials/security/seccomp/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q08 →](../q08_host_users_groups_sshd/question.md)
