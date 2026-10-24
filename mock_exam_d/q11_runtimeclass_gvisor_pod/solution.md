# q11 — Run a Pod in gVisor with a RuntimeClass · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Worker node `cks-c1-w1` has the gVisor runtime installed; containerd exposes it as the runtime
> handler `runsc`. The control-plane node does not have it.
>
> 1. Create a RuntimeClass `gvisor` that uses the handler `runsc`.
> 2. Create a Pod `sandboxed` in namespace `onyx` with image `nginx:1.27-alpine` that runs with
>    RuntimeClass `gvisor` on node `cks-c1-w1`.
> 3. Write the output of `dmesg` run inside Pod `sandboxed` to `/opt/course/d11/dmesg.txt`.

**해석**

워커 노드 `cks-c1-w1` 에 gVisor 런타임이 설치되어 있고, containerd 는 이를 런타임 핸들러 `runsc` 로 제공한다. 컨트롤 플레인 노드에는 없다.

1. 핸들러 `runsc` 를 쓰는 RuntimeClass `gvisor` 를 만든다.
2. 이미지 `nginx:1.27-alpine` 의 Pod `sandboxed` 를 namespace `onyx` 에 만들고, RuntimeClass `gvisor` 로 `cks-c1-w1` 에서 돌게 한다.
3. Pod `sandboxed` 안에서 실행한 `dmesg` 출력을 `/opt/course/d11/dmesg.txt` 에 쓴다.

## 모범 풀이

**1) RuntimeClass**

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor          # Pod 의 runtimeClassName 에 쓰는 이름
handler: runsc          # containerd 설정의 runtimes.<이름> 과 같아야 한다
```

`handler` 는 containerd 설정 `/etc/containerd/config.toml` 의 `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]`
(containerd 2.x 는 `[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]`)에서 `runtimes.` 뒤의 이름입니다.
확인하려면 `ssh cks-c1-w1 sudo grep -A2 'runtimes.runsc' /etc/containerd/config.toml`. RuntimeClass 는 namespace 가 없는 클러스터 리소스입니다.

**2) Pod**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed
  namespace: onyx
spec:
  runtimeClassName: gvisor
  nodeSelector:
    kubernetes.io/hostname: cks-c1-w1
  containers:
  - name: nginx
    image: nginx:1.27-alpine
```

```bash
alias k=kubectl
k apply -f runtimeclass.yaml -f sandboxed.yaml
k -n onyx get pod sandboxed -o wide        # Running, NODE cks-c1-w1
```

핸들러가 없는 노드에 뜨면 Pod 는 `ContainerCreating` 에서 멈추고 이벤트에 `no runtime for "runsc" is configured` 같은 메시지가
남습니다. 이 클러스터는 컨트롤 플레인에 taint 가 있어 보통 워커로 가지만, 문제에서 노드를 지정했으니 `nodeSelector` 를 둡니다.
RuntimeClass 의 `scheduling.nodeSelector` 에 노드 라벨을 넣으면 이 RuntimeClass 를 쓰는 모든 Pod 에 자동으로 붙일 수도 있습니다.

**3) gVisor 안인지 확인**

```bash
k -n onyx exec sandboxed -- dmesg > /opt/course/d11/dmesg.txt
cat /opt/course/d11/dmesg.txt
# [    0.000000] Starting gVisor...
# [    0.xxxxx] ...                       ← gVisor 가 만든 가짜 커널 메시지들
# [    x.xxxxx] Ready!
```

gVisor 는 사용자 공간 커널(Sentry)이 시스템 콜을 가로채므로, 컨테이너 안의 `dmesg` 는 호스트 커널 로그가 아니라 gVisor 의
메시지를 보여 줍니다. 일반 runc 컨테이너에서는 `dmesg` 가 `Operation not permitted` 이거나 호스트 커널 로그가 나옵니다.

## 검증

```bash
k get runtimeclass gvisor -o jsonpath='{.handler}{"\n"}'                  # runsc
k -n onyx get pod sandboxed -o jsonpath='{.spec.runtimeClassName} {.spec.nodeName}{"\n"}'   # gvisor cks-c1-w1
k -n onyx exec sandboxed -- uname -r                                      # gVisor 가 흉내 내는 커널 버전 (호스트와 다름)
grep -c gVisor /opt/course/d11/dmesg.txt                                  # 1 이상
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: RuntimeClass `handler` = containerd 의 `runtimes.<handler>` 이름. Pod 는 `spec.runtimeClassName`.
- **헷갈리는 지점**: `runtimeClassName` 은 만든 뒤 바꿀 수 없어 Pod 를 다시 만듭니다(Deployment 면 템플릿 수정으로 새 Pod). 그리고 gVisor 는 일부 시스템 콜·`hostNetwork`·특정 볼륨을 지원하지 않아 모든 워크로드가 그대로 돌지는 않습니다.

## 참고 문서

시험 중에는 gVisor 문서를 열 수 없으므로 `runsc --help` 로 확인합니다.

- 검색어: `runtime class`, `RuntimeClass handler`
- https://kubernetes.io/docs/concepts/containers/runtime-class/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q12 →](../q12_dockerfile_nonroot_pinned_tag/question.md)
