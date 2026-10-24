# q17 — Trace a malicious process from the node to its Pod · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The node monitoring of worker node `cks-c1-w1` reports a process named `xmrig`.
>
> 1. On `cks-c1-w1`, find the process named `xmrig` and determine its PID on the host, the full ID
>    of the container it runs in, and the Pod (namespace and name) of that container. Write the
>    result to `/opt/course/b17/finding.txt` on `cks-c1` in exactly this format:
>    ```
>    pid: <host PID>
>    container_id: <full 64-character container ID>
>    pod: <namespace>/<pod name>
>    ```
> 2. Remove the workload that owns this Pod so that the Pod does not come back. Do not touch other
>    workloads.
> 3. Configure the namespace of that Pod to enforce the Pod Security Standard `restricted` with
>    version `v1.35`. Write the warnings that `kubectl` prints when you apply this to
>    `/opt/course/b17/psa-warnings.txt`.

**해석**

워커 `cks-c1-w1` 의 노드 모니터링이 `xmrig` 라는 프로세스를 보고했다.

1. `cks-c1-w1` 에서 `xmrig` 프로세스를 찾아 호스트 PID, 그 프로세스가 도는 컨테이너의 전체 ID, 그 컨테이너의 Pod(네임스페이스와 이름)를 알아내
   정해진 형식으로 `cks-c1` 의 `/opt/course/b17/finding.txt` 에 쓴다.
2. 이 Pod 를 소유한 워크로드를 지워 Pod 가 다시 생기지 않게 한다. 다른 워크로드는 건드리지 않는다.
3. 그 Pod 의 네임스페이스가 Pod Security Standard `restricted`(버전 `v1.35`)를 강제하게 하고, 적용할 때 `kubectl` 이 출력하는 경고를
   `/opt/course/b17/psa-warnings.txt` 에 쓴다.

## 모범 풀이

**1) 호스트에서 프로세스 찾기**

```bash
ssh cks-c1-w1
sudo -i
pgrep -a xmrig
# 48213 /bin/sh /tmp/xmrig --donate-level 1 -o stratum+tcp://pool.b17.invalid:3333
ps -o pid,ppid,user,comm,args -p $(pgrep -x xmrig)
```

`pgrep -x` 는 프로세스 이름(`comm`, 최대 15자)과 정확히 일치하는 것을 찾습니다. 스크립트를 실행하면 `comm` 은 스크립트 파일 이름(`xmrig`)이 되고,
`args` 에는 인터프리터(`/bin/sh /tmp/xmrig ...`)가 보입니다. 같은 이름의 프로세스가 여러 개면 부모·자식 관계를 `ps -ef --forest` 로 확인합니다.

**2) PID → 컨테이너 ID → Pod**

```bash
PID=$(pgrep -x xmrig)
cat /proc/$PID/cgroup
# 0::/kubepods.slice/kubepods-besteffort.slice/kubepods-besteffort-pod1b2c..._....slice/cri-containerd-9f3e1c...(64자리).scope
CID=$(sed -n 's/.*cri-containerd-\([0-9a-f]\{64\}\)\.scope.*/\1/p' /proc/$PID/cgroup)
echo $CID
crictl ps --id $CID
# CONTAINER      IMAGE    CREATED   STATE    NAME     ATTEMPT  POD ID   POD
# 9f3e1c...      ...      5m        Running  report   0        77aa...  report-gen-6d8f...-k2x9q
crictl inspect $CID | jq -r '.status.labels["io.kubernetes.pod.namespace"] + "/" + .status.labels["io.kubernetes.pod.name"]'
# batch/report-gen-6d8f...-k2x9q
crictl inspect -o go-template --template '{{.info.pid}}' $CID      # 컨테이너 init 프로세스의 호스트 PID (xmrig 가 exec 됐으므로 같은 값)
```

> 함정: `kubectl exec ... -- ps` 로 보는 PID(컨테이너 PID 네임스페이스 안의 번호, 대개 1)는 호스트 PID 와 다릅니다. 과제는 **호스트 PID** 를
> 묻습니다. 컨테이너 ID 도 `crictl ps` 의 13자리 축약이 아니라 cgroup 경로나 `crictl inspect` 의 `.status.id` 에 있는 64자리 전체 ID 를 씁니다.

cgroup 경로 형식은 cgroup 드라이버에 따라 다릅니다. systemd 드라이버(kubeadm 기본)는 위처럼 `cri-containerd-<id>.scope`, cgroupfs 드라이버는
`/kubepods/besteffort/pod<uid>/<id>` 입니다. 반대 방향(컨테이너 → PID)은 `crictl inspect` 의 `.info.pid` 입니다.

```bash
exit; exit
cat > /opt/course/b17/finding.txt <<EOF
pid: 48213
container_id: 9f3e1c...(64자리 전체)
pod: batch/report-gen-6d8f...-k2x9q
EOF
```

**3) 소유 워크로드 지우기**

```bash
kubectl -n batch get pod report-gen-6d8f...-k2x9q -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}'
# ReplicaSet/report-gen-6d8f...
kubectl -n batch get rs report-gen-6d8f... -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}'
# Deployment/report-gen
kubectl -n batch delete deploy report-gen
kubectl -n batch get pod                       # etl 만 남는다
```

Pod 만 지우면 ReplicaSet 이 같은 컨테이너를 새로 만들어 채굴기가 다시 뜹니다. 컨테이너 프로세스를 `kill` 해도 kubelet 이 재시작합니다.

**4) restricted 강제와 경고**

```bash
kubectl label ns batch \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.35 2> /opt/course/b17/psa-warnings.txt
cat /opt/course/b17/psa-warnings.txt
# Warning: existing pods in namespace "batch" violate the new PodSecurity enforce level "restricted:v1.35"
# Warning: etl-7c...: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
```

경고는 stderr 로 나오고 라벨은 적용됩니다(`namespace/batch labeled` 는 stdout). 이미 돌고 있는 Pod 는 **쫓겨나지 않고**, 이후 새로 만들어지는 Pod
부터 거부됩니다. 미리 영향만 보려면 `--dry-run=server` 로 같은 라벨을 붙여 봅니다. `enforce-version` 을 `latest` 대신 고정하면 클러스터를
업그레이드해도 기준이 갑자기 바뀌지 않습니다.

## 검증

```bash
cat /opt/course/b17/finding.txt
ssh cks-c1-w1 'pgrep -a xmrig || echo "no xmrig"'
kubectl -n batch get deploy                                    # report-gen 없음, etl 유지
kubectl -n frontend get deploy                                 # 그대로
kubectl get ns batch --show-labels | tr ',' '\n' | grep pod-security
kubectl -n batch run psa-test --image=busybox:1.36 -- sleep 1   # 거부됨 (restricted 위반)
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 호스트 PID → `/proc/<pid>/cgroup` 의 `cri-containerd-<64자리>` → `crictl inspect <id>` 라벨 `io.kubernetes.pod.namespace/name` → ownerReferences 를 따라 최상위 워크로드 삭제.
- **헷갈리는 지점**: `crictl ps` 의 `POD` 열은 Pod 이름, `POD ID` 는 샌드박스 ID 입니다. PSA 라벨의 경고는 적용을 막지 않습니다. Falco 를 쓴다면 같은 정보를 `container_id`, `k8s.pod.name` 필드로 바로 얻을 수 있지만, 이 문제처럼 노드에서 직접 추적하는 방법도 익혀 둡니다.

## 참고 문서

- 검색어: `crictl`, `pod security admission`, `enforce pod security standards with namespace labels`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md)
