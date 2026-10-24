# q11 — Run an untrusted workload in a gVisor RuntimeClass · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Deployment `untrusted-render` in namespace `sandbox` processes untrusted input and must run
> in a gVisor sandbox. The container runtime on `cks-c1-w1` has a handler named `runsc`.
>
> 1. Create a RuntimeClass `gvisor` for this handler. Using the RuntimeClass itself (not the
>    Deployment), make sure Pods that use it are only scheduled to nodes labeled
>    `sandbox.cks.io/gvisor=true`.
> 2. Change Deployment `untrusted-render` to use RuntimeClass `gvisor`. Both replicas must be
>    `Running`.
> 3. Write the output of `dmesg` executed in one of its containers to
>    `/opt/course/a11/dmesg.txt`, and the name of the node that Pod runs on to
>    `/opt/course/a11/node.txt`.

**해석**

namespace `sandbox` 의 Deployment `untrusted-render` 는 신뢰할 수 없는 입력을 처리하므로 gVisor 샌드박스에서 돌아야 한다.
`cks-c1-w1` 의 컨테이너 런타임에는 `runsc` 라는 핸들러가 있다.

1. 이 핸들러용 RuntimeClass `gvisor` 를 만든다. Deployment 가 아니라 **RuntimeClass 자체**로, 이 클래스를 쓰는 Pod 가 라벨
   `sandbox.cks.io/gvisor=true` 가 있는 노드에만 스케줄되게 한다.
2. Deployment `untrusted-render` 가 RuntimeClass `gvisor` 를 쓰게 바꾼다. 두 레플리카 모두 `Running` 이어야 한다.
3. 그 컨테이너 하나에서 실행한 `dmesg` 출력을 `/opt/course/a11/dmesg.txt` 에, 그 Pod 가 도는 노드 이름을 `/opt/course/a11/node.txt` 에 쓴다.

## 모범 풀이

**0) 핸들러 이름 확인 (선택)**

```bash
ssh cks-c1-w1 sudo grep -A2 'runtimes.runsc' /etc/containerd/config.toml
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]     (containerd 2.x: io.containerd.cri.v1.runtime)
#   runtime_type = "io.containerd.runsc.v1"
kubectl get nodes -l sandbox.cks.io/gvisor=true          # cks-c1-w1
```

RuntimeClass 의 `handler` 는 containerd 설정의 `runtimes.<이름>` 과 **글자 그대로 같아야** 합니다. 다르면 Pod 가
`ContainerCreating` 에 멈추고 이벤트에 `no runtime for "gvisor" is configured` 같은 오류가 남습니다.

**1) RuntimeClass — scheduling.nodeSelector**

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor           # cluster-scoped (namespace 없음)
handler: runsc
scheduling:
  nodeSelector:
    sandbox.cks.io/gvisor: "true"
```

```bash
kubectl apply -f rc-gvisor.yaml
kubectl get runtimeclass
```

`scheduling.nodeSelector` 는 RuntimeClass admission 이 이 클래스를 쓰는 Pod 의 `nodeSelector` 에 **합쳐 넣습니다**. 그래서 Deployment
를 고치지 않아도 gVisor 가 설치된 노드로만 갑니다. 노드에 taint 를 걸었다면 `scheduling.tolerations` 로 함께 넣습니다. Pod 에 같은 키로
다른 값의 nodeSelector 가 있으면 admission 이 거부합니다. `handler` 는 만든 뒤 바꿀 수 없으므로(immutable) 틀리면 지우고 다시 만듭니다.

**2) Deployment**

```bash
kubectl -n sandbox patch deploy untrusted-render -p '{"spec":{"template":{"spec":{"runtimeClassName":"gvisor"}}}}'
kubectl -n sandbox rollout status deploy untrusted-render
kubectl -n sandbox get pod -o wide                  # NODE cks-c1-w1, 2/2 Running
kubectl -n sandbox get pod -o jsonpath='{range .items[*]}{.metadata.name} {.spec.runtimeClassName} {.spec.nodeSelector}{"\n"}{end}'
# untrusted-render-… gvisor {"sandbox.cks.io/gvisor":"true"}
```

`runtimeClassName` 은 Pod 템플릿 spec 에 들어갑니다. 존재하지 않는 RuntimeClass 이름을 쓰면 Pod 생성이 거부되어 ReplicaSet 이 `FailedCreate` 를 남깁니다.

**3) gVisor 안에서 돌고 있는지 증명**

```bash
P=$(kubectl -n sandbox get pod -l app=untrusted-render -o jsonpath='{.items[0].metadata.name}')
kubectl -n sandbox exec $P -- dmesg > /opt/course/a11/dmesg.txt
kubectl -n sandbox get pod $P -o jsonpath='{.spec.nodeName}' > /opt/course/a11/node.txt
cat /opt/course/a11/dmesg.txt
# [   0.000000] Starting gVisor...
# [   0.xxxxx] ...                    (gVisor 가 출력하는 장난스러운 가짜 부팅 메시지 몇 줄)
# [   x.xxxxx] Ready!
kubectl -n sandbox exec $P -- uname -r          # gVisor 가 흉내 내는 커널 버전 (호스트와 다름)
```

| 확인 | runc (일반) | runsc (gVisor) |
|---|---|---|
| `dmesg` | `Operation not permitted` 또는 호스트 커널 로그 | `Starting gVisor...` |
| `uname -r` | 호스트 커널 버전 | gVisor 가 보고하는 버전 |
| 워커 `ps` | 컨테이너 프로세스가 그대로 보임 | `runsc-gofer`, `runsc-sandbox` 등 샌드박스 프로세스 |

gVisor 는 사용자 공간 커널(Sentry)이 시스템 콜을 가로채 처리하므로 컨테이너가 호스트 커널을 직접 건드리지 못합니다.
대신 일부 시스템 콜·기능이 지원되지 않고 I/O 성능이 떨어질 수 있습니다.

## 검증

```bash
kubectl get runtimeclass gvisor -o jsonpath='{.handler} {.scheduling.nodeSelector}{"\n"}'   # runsc {"sandbox.cks.io/gvisor":"true"}
kubectl -n sandbox get deploy untrusted-render                                               # 2/2
grep -c gVisor /opt/course/a11/dmesg.txt                                                     # 1 이상
cat /opt/course/a11/node.txt                                                                 # cks-c1-w1
ssh cks-c1-w1 sudo ps -ef | grep -c '[r]unsc'                                                # 0 보다 큼
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: RuntimeClass(`node.k8s.io/v1`, cluster-scoped) = `handler`(containerd 런타임 이름) + 선택 `scheduling.nodeSelector`/`tolerations` + 선택 `overhead`. Pod 는 `spec.runtimeClassName`.
- **헷갈리는 지점**: `metadata.name`(Pod 가 참조하는 이름)과 `handler`(노드 런타임 이름)는 다른 필드입니다. RuntimeClass 를 만든다고 기존 Pod 가 바뀌지 않으므로 롤아웃이 필요합니다. 런타임이 없는 노드에 스케줄되면 Pod 가 생성되지 못하므로 `scheduling` 으로 노드를 묶습니다.

## 참고 문서

gVisor 문서는 시험 중 열 수 없으므로 `runsc --help` 를 씁니다.

- 검색어: `runtime class`, `runtimeClassName`, `RuntimeClass scheduling`
- https://kubernetes.io/docs/concepts/containers/runtime-class/
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q12 →](../q12_dockerfile_minimize_kubesec/question.md)
