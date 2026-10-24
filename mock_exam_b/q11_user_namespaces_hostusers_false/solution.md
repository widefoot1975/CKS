# q11 — Run a Deployment in a user namespace · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Deployment `sandbox` in namespace `tenant` runs its container as root. Root inside the container
> must not be root on the node.
>
> 1. Change Deployment `sandbox` so that its Pod runs in its own user namespace instead of the host
>    user namespace. Make any other change that is required for the Pod to be accepted, but keep the
>    image, the command and the node placement. The Pod must be `Running`.
> 2. Write the content of `/proc/self/uid_map` as seen inside the container to
>    `/opt/course/b11/uid_map.txt`.
> 3. On `cks-c1-w1`, find the UID with which the container's `sleep` process runs on the host and
>    write only that number to `/opt/course/b11/host-uid.txt` on `cks-c1`.

**해석**

`tenant` 의 Deployment `sandbox` 는 컨테이너를 root 로 실행한다. 컨테이너 안의 root 가 노드의 root 가 되면 안 된다.

1. `sandbox` 의 Pod 가 호스트 user namespace 대신 자기 user namespace 에서 돌게 바꾼다. Pod 가 받아들여지는 데 필요한 다른 변경은 해도 되지만
   이미지·명령·노드 배치는 유지한다. Pod 는 `Running` 이어야 한다.
2. 컨테이너 안에서 본 `/proc/self/uid_map` 내용을 `/opt/course/b11/uid_map.txt` 에 쓴다.
3. `cks-c1-w1` 에서 컨테이너의 `sleep` 프로세스가 호스트에서 어떤 UID 로 도는지 찾아 숫자만 `cks-c1` 의 `/opt/course/b11/host-uid.txt` 에 쓴다.

## 모범 풀이

**1) `hostUsers: false` — 그리고 호스트 네임스페이스 제거**

```bash
alias k=kubectl
k -n tenant get deploy sandbox -o yaml | grep -nE 'hostNetwork|hostUsers|nodeSelector' 
k -n tenant edit deploy sandbox
```

```yaml
    spec:
      hostUsers: false            # Pod spec 바로 아래 (securityContext 안이 아님)
      # hostNetwork: true         # 삭제 — user namespace 와 함께 쓸 수 없다
      nodeSelector:
        kubernetes.io/hostname: cks-c1-w1
      containers:
      - name: sandbox
        image: busybox:1.36
        command: ["sleep", "1d"]
```

> 함정: `hostUsers: false` 이면 `hostNetwork`, `hostPID`, `hostIPC` 를 `true` 로 둘 수 없습니다. `hostNetwork: true` 를 그대로 두고
> `hostUsers: false` 만 추가하면 API 검증에서 `Forbidden` 으로 거부됩니다(편집 저장 시 오류, 또는 ReplicaSet 의 `FailedCreate` 이벤트).
> 호스트 네트워크·PID·IPC 네임스페이스를 공유하면서 사용자만 분리하는 것은 의미가 없기 때문입니다.

`hostUsers` 는 `securityContext` 가 아니라 **Pod spec 필드**입니다. v1.33 부터 기본 활성화(UserNamespacesSupport)되어 v1.35 시험 환경에서는
노드 조건(커널 6.3+, idmap mount 를 지원하는 파일시스템, containerd 2.0+/CRI-O 1.25+, runc 1.2+)만 맞으면 바로 쓸 수 있습니다.

```bash
k -n tenant rollout status deploy sandbox
k -n tenant get pod -o wide                  # Running, NODE cks-c1-w1, IP 가 이제 Pod CIDR
```

**2) 컨테이너 안에서 본 uid_map**

```bash
k -n tenant exec deploy/sandbox -- cat /proc/self/uid_map | tee /opt/course/b11/uid_map.txt
#          0    1769472      65536
k -n tenant exec deploy/sandbox -- id      # uid=0(root) gid=0(root) — 안에서는 여전히 root
```

세 열은 `<컨테이너 안 시작 UID> <호스트 시작 UID> <개수>` 입니다. 컨테이너 UID 0~65535 가 호스트 UID 1769472~1835007 로 매핑됩니다
(kubelet 이 Pod 마다 65536 배수의 겹치지 않는 범위를 할당). user namespace 를 안 쓰는 Pod 는 `0 0 4294967295`(전체 항등 매핑)입니다.

**3) 호스트에서 본 UID**

```bash
ssh cks-c1-w1
sudo -i
CID=$(crictl ps --name sandbox -q)
PID=$(crictl inspect -o go-template --template '{{.info.pid}}' $CID)
ps -o uid,user,pid,cmd -p $PID
#     UID USER      PID CMD
# 1769472 1769472  48211 sleep 1d
grep -E 'Uid' /proc/$PID/status              # Uid: 1769472 1769472 1769472 1769472
exit; exit
echo 1769472 > /opt/course/b11/host-uid.txt  # cks-c1 에서, 실제 값으로
```

| | 컨테이너 안 | 호스트 |
|---|---|---|
| user namespace 없음 (`hostUsers` 기본 true) | uid 0 | uid 0 (진짜 root) |
| `hostUsers: false` | uid 0 (capabilities 도 namespace 안에서만 유효) | uid 1769472 같은 비특권 UID |

컨테이너 탈출에 성공해도 호스트에서는 아무 권한 없는 UID 이고, 호스트 파일은 매핑되지 않은 소유자로 보여(`nobody`/65534) 쓸 수 없습니다.

## 검증

```bash
k -n tenant get deploy sandbox -o jsonpath='{.spec.template.spec.hostUsers}{" "}{.spec.template.spec.hostNetwork}{"\n"}'   # false (hostNetwork 비어 있음)
k -n tenant get pod -l app=sandbox -o wide
k -n tenant exec deploy/sandbox -- cat /proc/self/uid_map
cat /opt/course/b11/uid_map.txt /opt/course/b11/host-uid.txt
ssh cks-c1-w1 "ps -eo uid,cmd | grep '[s]leep 1d'"
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `spec.hostUsers: false`(Pod 수준). `hostNetwork`/`hostPID`/`hostIPC` 와 함께 쓸 수 없다. 확인은 `/proc/self/uid_map` 이 `0 0 4294967295` 가 아닌지.
- **헷갈리는 지점**: `runAsNonRoot`/`runAsUser` 는 "컨테이너 안에서 어떤 UID 로 도는가", `hostUsers: false` 는 "그 UID 가 호스트의 어떤 UID 로 매핑되는가" 로 서로 보완 관계입니다. 노드의 커널·런타임이 조건에 안 맞으면 Pod 가 `ContainerCreating` 에서 멈추고 이벤트에 user namespace 관련 오류가 나옵니다. 이 기능은 v1.36 에서 GA 됩니다.

## 참고 문서

- 검색어: `user namespaces`, `hostUsers`
- https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/
- https://kubernetes.io/docs/tasks/configure-pod-container/user-namespaces/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q12 →](../q12_sbom_bom_trivy_sbom/question.md)
