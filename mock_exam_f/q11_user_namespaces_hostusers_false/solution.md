# q11 — Run a Deployment in a user namespace · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The process in Deployment `isolated` runs as root. If it escapes the container it must not be root
> on the node.
>
> 1. Change Deployment `isolated` in namespace `f11` so that its Pods run in their own user namespace
>    instead of the host user namespace. Do not change the image, the command or the user inside the
>    container.
> 2. When the new Pod is `Running`, write the content of `/proc/self/uid_map` as seen inside the
>    container to `/opt/course/f11/uid_map.txt`.
> 3. On the node where the Pod runs, find the host UID of the container's `sleep` process and write
>    only the number to `/opt/course/f11/host_uid.txt` on `cks-c1`.

**해석**

Deployment `isolated` 의 프로세스는 root 로 돈다. 컨테이너를 탈출하더라도 노드에서는 root 가 아니어야 한다.

1. namespace `f11` 의 Deployment `isolated` 를 고쳐, Pod 가 호스트의 user namespace 대신 자기 user namespace 에서 돌게 한다.
   이미지, 명령, 컨테이너 안의 사용자는 바꾸지 않는다.
2. 새 Pod 가 `Running` 이 되면 컨테이너 안에서 본 `/proc/self/uid_map` 내용을 `/opt/course/f11/uid_map.txt` 에 쓴다.
3. Pod 가 도는 노드에서 컨테이너의 `sleep` 프로세스의 호스트 UID 를 찾아 숫자만 `cks-c1` 의 `/opt/course/f11/host_uid.txt` 에 쓴다.

## 모범 풀이

**1) `hostUsers: false`**

```bash
alias k=kubectl
k -n f11 exec deploy/isolated -- cat /proc/self/uid_map
#          0          0 4294967295        ← 지금은 호스트와 같은 UID 공간 (컨테이너 root = 노드 root)
k -n f11 patch deploy isolated -p '{"spec":{"template":{"spec":{"hostUsers":false}}}}'
k -n f11 rollout status deploy isolated
```

`hostUsers` 는 **Pod spec** 필드(컨테이너 `securityContext` 아님)입니다. 기본값 `true` 는 호스트 user namespace 를 그대로 쓴다는 뜻이고,
`false` 로 두면 kubelet 이 Pod 마다 겹치지 않는 65536 개 UID/GID 범위를 골라 컨테이너의 0~65535 에 매핑합니다.

**2) 컨테이너 안에서 본 매핑**

```bash
k -n f11 exec deploy/isolated -- cat /proc/self/uid_map | tee /opt/course/f11/uid_map.txt
#          0 1879048192      65536
k -n f11 exec deploy/isolated -- id
# uid=0(root) gid=0(root) ...        ← 안에서는 여전히 root
```

세 숫자는 "컨테이너 안 시작 UID / 호스트 시작 UID / 개수" 입니다. 컨테이너의 UID 0 은 호스트의 `1879048192`(예시) 입니다.

**3) 노드에서 호스트 UID 확인**

```bash
k -n f11 get pod -l app=isolated -o wide          # NODE cks-c1-w1
ssh cks-c1-w1
sudo -i
CID=$(crictl ps --name sleeper -q)
PID=$(crictl inspect -o go-template --template '{{.info.pid}}' $CID)
ps -o uid=,pid=,cmd= -p $PID
# 1879048192  41234 sleep 86400
exit; exit
```

`cks-c1` 에서 기록합니다.

```bash
ssh cks-c1-w1 sudo ps -o uid= -C sleep    # 여러 줄이면 위에서 찾은 PID 의 값
echo 1879048192 > /opt/course/f11/host_uid.txt
```

uid_map 의 두 번째 숫자와 같아야 합니다. 이 UID 는 노드에서 아무 권한도 없는 일반 번호라, 컨테이너에서 탈출하거나 hostPath 로
노드 파일에 접근해도 root 권한이 없습니다. 컨테이너 안의 capability(예: `CAP_SYS_ADMIN`)도 그 user namespace 안에서만 의미가 있습니다.

| | `hostUsers: true` (기본) | `hostUsers: false` |
|---|---|---|
| 컨테이너 UID 0 | 노드 UID 0 | 노드의 큰 번호 (예: 1879048192) |
| `/proc/self/uid_map` | `0 0 4294967295` | `0 <호스트 시작> 65536` |
| 함께 못 쓰는 것 | — | `hostNetwork`, `hostPID`, `hostIPC` |

## 검증

```bash
k -n f11 get deploy isolated -o jsonpath='{.spec.template.spec.hostUsers}{"\n"}'     # false
k -n f11 get pod -l app=isolated                                                     # 1/1 Running (새 Pod)
cat /opt/course/f11/uid_map.txt                                                      # 0 <큰 수> 65536
awk '{print $2}' /opt/course/f11/uid_map.txt; cat /opt/course/f11/host_uid.txt       # 두 값이 같다
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `spec.hostUsers: false` (Pod 수준). 확인은 `cat /proc/self/uid_map` — `0 0 4294967295` 가 아니면 user namespace 가 적용된 것이다.
- **헷갈리는 지점**: `runAsUser` 를 바꾸는 것과 다릅니다. 컨테이너 안에서는 여전히 root 이고 노드에서만 비특권 UID 입니다. Pod 가 `ContainerCreating` 에서 멈추면 노드의 커널(6.3+)·containerd/runc 버전이 idmap 마운트를 지원하는지 확인합니다. `hostNetwork`/`hostPID`/`hostIPC: true` 와 함께 쓰면 API 검증에서 거부됩니다.

## 참고 문서

- 검색어: `user namespaces`, `hostUsers`
- https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/
- https://kubernetes.io/docs/tasks/configure-pod-container/user-namespaces/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q12 →](../q12_image_digest_pinning/question.md)
