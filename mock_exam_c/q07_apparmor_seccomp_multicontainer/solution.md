# q07 — AppArmor and seccomp in a multi-container Pod · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Pod `dual` in namespace `guard` runs two containers, `app` and `sidecar`. Its manifest is
> `/opt/course/c07/dual.yaml`. Do not change the labels of namespace `guard`.
>
> 1. On worker node `cks-c1-w1`, load the AppArmor profile from file `/opt/course/c07/k8s-deny-write`
>    in enforce mode.
> 2. Edit `/opt/course/c07/dual.yaml` so that:
>    - the Pod runs on node `cks-c1-w1`
>    - the seccomp profile `RuntimeDefault` is set once at Pod level and applies to **both**
>      containers (no container may override it)
>    - container `app` is confined by the AppArmor profile you loaded, container `sidecar` uses the
>      container runtime's default AppArmor profile
>    - AppArmor is configured with `securityContext` fields only (no annotations)
> 3. Create the Pod from the edited file. Both containers must be running.
> 4. Write two lines to `/opt/course/c07/check.txt`: line 1 is the content of
>    `/proc/1/attr/current` inside container `app`, line 2 the same for container `sidecar`.

**해석**

namespace `guard` 의 Pod `dual` 은 컨테이너 `app` 과 `sidecar` 를 가진다. 매니페스트는 `/opt/course/c07/dual.yaml` 이다.
namespace `guard` 의 라벨은 바꾸지 않는다.

1. 워커 `cks-c1-w1` 에서 `/opt/course/c07/k8s-deny-write` 파일의 AppArmor 프로필을 enforce 모드로 로드한다.
2. `/opt/course/c07/dual.yaml` 을 고친다.
   - Pod 는 `cks-c1-w1` 에서 실행된다.
   - seccomp `RuntimeDefault` 는 Pod 수준에 한 번 두고 **두 컨테이너 모두** 에 적용된다(컨테이너가 덮어쓰면 안 됨).
   - `app` 은 로드한 AppArmor 프로필로, `sidecar` 는 런타임 기본 AppArmor 프로필로 제한한다.
   - AppArmor 는 `securityContext` 필드로만 설정한다(어노테이션 금지).
3. 고친 파일로 Pod 를 만든다. 두 컨테이너 모두 실행 중이어야 한다.
4. `/opt/course/c07/check.txt` 에 두 줄: 1행은 `app` 안의 `/proc/1/attr/current` 내용, 2행은 `sidecar` 의 같은 내용.

## 모범 풀이

**1) 왜 거부되는지 먼저 본다**

```bash
alias k=kubectl
k apply -f /opt/course/c07/dual.yaml
# Error from server (Forbidden): pods "dual" is forbidden: violates PodSecurity "baseline:latest":
#   seccompProfile (container "sidecar" must not set securityContext.seccompProfile.type to "Unconfined")
cat /opt/course/c07/dual.yaml
```

baseline 은 seccomp·AppArmor 를 **명시적으로 Unconfined 로 푸는 것**을 금지합니다. 설정이 없는 것은 허용합니다.

**2) 워커에서 프로필 로드**

```bash
ssh cks-c1-w1
sudo -i
head -5 /opt/course/c07/k8s-deny-write
# profile k8s-deny-write flags=(attach_disconnected) {     ← 파일 이름이 아니라 이 이름을 쓴다
apparmor_parser -q /opt/course/c07/k8s-deny-write      # 로드(기본 enforce). 이미 있으면 -r 로 교체
aa-status | grep k8s-deny-write                        # enforce 목록에 있어야 함
# (재부팅 후에도 유지하려면 /etc/apparmor.d/ 에 복사)
exit; exit
```

**3) 매니페스트 수정**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dual
  namespace: guard
  # annotations: container.apparmor.security.beta.kubernetes.io/app: localhost/k8s-deny-write  ← 삭제 (deprecated)
spec:
  nodeName: cks-c1-w1              # 또는 nodeSelector: kubernetes.io/hostname: cks-c1-w1
  securityContext:
    seccompProfile:
      type: RuntimeDefault         # Pod 수준 → 두 컨테이너에 상속
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-write   # 프로필 이름 (경로 아님)
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      appArmorProfile:
        type: RuntimeDefault
      # seccompProfile: {type: Unconfined}  ← 삭제: 컨테이너 값이 Pod 값을 덮어쓴다
```

```bash
k apply -f /opt/course/c07/dual.yaml
k -n guard get pod dual -o wide        # 2/2 Running, NODE cks-c1-w1
```

| 항목 | seccomp | AppArmor |
|---|---|---|
| 필드 | `securityContext.seccompProfile` | `securityContext.appArmorProfile` (v1.30 GA) |
| Pod 수준 / 컨테이너 수준 | 둘 다 가능, 컨테이너가 우선 | 둘 다 가능, 컨테이너가 우선 |
| `Localhost` 값 | `localhostProfile`: `/var/lib/kubelet/seccomp/` 기준 **상대 경로** | `localhostProfile`: 노드에 로드된 **프로필 이름** |
| 노드 준비 | JSON 파일을 kubelet seccomp 디렉터리에 | `apparmor_parser` 로 커널에 로드 |
| 준비 안 됐을 때 | 컨테이너 생성 실패 | 컨테이너 생성 실패(`CreateContainerError`) |

AppArmor 프로필은 **Pod 가 실행될 노드**에 로드되어 있어야 합니다. 그래서 `nodeName`(또는 nodeSelector)으로 워커에 고정했습니다.

**4) 확인과 기록**

```bash
k -n guard exec dual -c app -- cat /proc/1/attr/current        # k8s-deny-write (enforce)
k -n guard exec dual -c sidecar -- cat /proc/1/attr/current    # cri-containerd.apparmor.d (enforce)
{ k -n guard exec dual -c app -- cat /proc/1/attr/current; k -n guard exec dual -c sidecar -- cat /proc/1/attr/current; } > /opt/course/c07/check.txt
```

## 검증

```bash
k -n guard exec dual -c app -- touch /tmp/x          # touch: /tmp/x: Permission denied
k -n guard exec dual -c sidecar -- touch /tmp/x && echo ok    # ok
for c in app sidecar; do k -n guard exec dual -c $c -- grep Seccomp: /proc/1/status; done   # Seccomp: 2 (filter) 두 번
k -n guard get pod dual -o jsonpath='{.metadata.annotations}{"\n"}'     # AppArmor 어노테이션 없음
cat /opt/course/c07/check.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: AppArmor 는 `securityContext.appArmorProfile: {type: Localhost, localhostProfile: <프로필 이름>}`, 프로필은 파드가 뜨는 노드에 `apparmor_parser` 로 로드. seccomp 는 Pod 수준에 두면 모든 컨테이너가 상속하지만 컨테이너 설정이 이긴다.
- **헷갈리는 지점**: `localhostProfile` 에 파일 경로(`/opt/course/...`)를 쓰면 안 되고, 파일 안의 `profile <이름>` 을 씁니다. `/proc/1/attr/current` 가 비어 보이면 최신 커널의 `/proc/1/attr/apparmor/current` 를 봅니다. 어노테이션 방식은 v1.30 부터 deprecated 이고, 필드와 어노테이션 값이 다르면 거부됩니다.

## 참고 문서

- 검색어: `apparmor`, `seccomp`, `pod security standards baseline`
- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://kubernetes.io/docs/tutorials/security/seccomp/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q08 →](../q08_host_kernel_modules_blacklist/question.md)
