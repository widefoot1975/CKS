# q17 — Find the container running as root with crictl · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Exactly one container in namespace `stack` runs as root. Find it from the container runtime
> on worker node `cks-c1-w1`.
>
> 1. On `cks-c1-w1`, use `crictl` to list the containers of namespace `stack` and determine
>    which one runs its main process as UID `0`.
> 2. Write the name of the Pod of that container to `/opt/course/e17/pod.txt` and the
>    container ID (as shown by `crictl ps`, 13 characters) to `/opt/course/e17/container.txt`,
>    both on `cks-c1`.
> 3. Scale the Deployment that owns this Pod to `0` replicas. Do not change the other
>    Deployments.

**해석**

namespace `stack` 에서 정확히 하나의 컨테이너가 root 로 돈다. 워커 노드 `cks-c1-w1` 의 컨테이너 런타임에서 찾는다.

1. `cks-c1-w1` 에서 `crictl` 로 `stack` namespace 의 컨테이너를 나열하고, 메인 프로세스를 UID `0` 으로 실행하는 것을 찾는다.
2. 그 컨테이너가 속한 Pod 이름을 `/opt/course/e17/pod.txt` 에, 컨테이너 ID(`crictl ps` 에 보이는 13자)를 `/opt/course/e17/container.txt` 에 쓴다. 둘 다 `cks-c1` 에 쓴다.
3. 이 Pod 를 소유한 Deployment 를 replicas `0` 으로 줄인다. 다른 Deployment 는 바꾸지 않는다.

## 모범 풀이

**1) crictl 로 namespace 의 컨테이너 나열**

```bash
ssh cks-c1-w1
sudo -i
crictl ps --label io.kubernetes.pod.namespace=stack
# CONTAINER      IMAGE          CREATED   STATE    NAME      ATTEMPT  POD ID         POD
# 3f1c2a9b8d7e6  4a2b…          5m        Running  reports   0        9e8d…          reports-6c7f9d…
# 8b7a6c5d4e3f2  …              5m        Running  cache     0        …              cache-5d8b7c…
# 1a2b3c4d5e6f7  …              5m        Running  web       0        …              web-7f6e5d…
```

kubelet 이 컨테이너마다 붙이는 라벨(`io.kubernetes.pod.namespace`, `io.kubernetes.pod.name`, `io.kubernetes.container.name`)로 거를 수 있습니다.
`crictl pods --namespace stack` 은 파드 샌드박스 목록입니다.

**2) 컨테이너마다 UID 확인 — 두 가지 방법**

```bash
# (a) 런타임 스펙에 기록된 실행 사용자
for c in $(crictl ps -q --label io.kubernetes.pod.namespace=stack); do
  echo "$c $(crictl inspect $c | jq -r '.status.labels["io.kubernetes.pod.name"] + " uid=" + (.info.runtimeSpec.process.user.uid|tostring)')"
done
# 3f1c2a9b8d7e6… reports-6c7f9d…-x2k4p uid=0
# 8b7a6c5d4e3f2… cache-5d8b7c…-q9w8e uid=1000
# 1a2b3c4d5e6f7… web-7f6e5d…-m3n4b uid=101

# (b) 실제 프로세스: 컨테이너 PID → /proc 의 Uid
for c in $(crictl ps -q --label io.kubernetes.pod.namespace=stack); do
  pid=$(crictl inspect $c | jq -r .info.pid)
  echo "$c $(grep '^Uid:' /proc/$pid/status)"
done
# 3f1c2a9b8d7e6… Uid:	0	0	0	0          ← 실제·유효·저장·파일시스템 UID 순서, 모두 0 = root
# 8b7a6c5d4e3f2… Uid:	1000	1000	1000	1000
```

`crictl exec <id> id -u` 도 되지만 이미지에 `id` 가 없을 수 있습니다(distroless). `/proc/<pid>/status` 나 `ps -o user,pid,cmd -p <pid>` 는
이미지와 상관없이 호스트에서 확인됩니다. 이미지에 `USER` 가 없고 `runAsUser` 도 없으면 root(0)로 돕니다.

```bash
# 결과를 cks-c1 으로 (워커에서 exit 한 뒤)
mkdir -p /opt/course/e17
CID=$(ssh cks-c1-w1 "sudo crictl ps -q --label io.kubernetes.pod.namespace=stack --label io.kubernetes.container.name=reports" | cut -c1-13)
echo $CID > /opt/course/e17/container.txt
kubectl -n stack get pod -l app=reports -o jsonpath='{.items[0].metadata.name}' > /opt/course/e17/pod.txt
cat /opt/course/e17/container.txt /opt/course/e17/pod.txt
```

**3) 소유 Deployment 축소**

```bash
kubectl -n stack get pod $(cat /opt/course/e17/pod.txt) -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}'
# ReplicaSet/reports-6c7f9d…  → Deployment reports
kubectl -n stack scale deploy reports --replicas=0
```

Pod → ReplicaSet → Deployment 순서로 소유합니다. Pod 만 지우면 ReplicaSet 이 같은 설정으로 즉시 다시 만들기 때문에 Deployment 를 줄여야 합니다.

| 확인 방법 | 위치 | 장점 |
|---|---|---|
| `crictl inspect` → `.info.runtimeSpec.process.user.uid` | 워커 | 런타임이 실제 적용한 사용자 |
| `/proc/<pid>/status` 의 `Uid:` | 워커 | 이미지에 도구가 없어도 됨 |
| `crictl exec <id> id` | 워커 | 간단하지만 이미지에 `id` 필요 |
| `kubectl get pod -o yaml` 의 `securityContext` | cks-c1 | 이미지 `USER` 는 안 보임 (불충분) |

## 검증

```bash
cat /opt/course/e17/pod.txt              # reports-…
cat /opt/course/e17/container.txt        # 13자 ID
kubectl -n stack get deploy              # reports 0/0, web 1/1, cache 1/1
ssh cks-c1-w1 'sudo crictl ps --label io.kubernetes.pod.namespace=stack'   # web, cache 만
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `crictl ps --label io.kubernetes.pod.namespace=<ns>` → `crictl inspect <id> | jq .info.runtimeSpec.process.user.uid` (또는 `.info.pid` → `/proc/<pid>/status`). Pod 이름은 `io.kubernetes.pod.name` 라벨.
- **헷갈리는 지점**: `web` 은 securityContext 가 없지만 이미지(`nginx-unprivileged`)의 `USER 101` 때문에 root 가 아닙니다 — 매니페스트만 봐서는 판단할 수 없습니다. 컨테이너 ID 는 64자 전체 중 앞부분이 `crictl ps` 에 13자로 보입니다. crictl 이 런타임을 못 찾으면 `--runtime-endpoint unix:///run/containerd/containerd.sock` 또는 `/etc/crictl.yaml` 을 씁니다.

## 참고 문서

- 검색어: `crictl`, `debugging kubernetes nodes with crictl`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md)
